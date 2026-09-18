import { AppointmentRepository } from './appointment.repository';
import { emitToUser } from '@shared/socket';
import { BadRequestError, ConflictError, NotFoundError, ForbiddenError } from '@shared/utils/errors';
import prisma from '@shared/database/prisma';
import { NotificationService } from '@modules/notifications/notification.service';

const APPOINTMENT_STATUS = ['pending', 'approved', 'confirmed', 'rescheduled', 'cancelled', 'completed', 'no_show'] as const;
type AppointmentStatus = typeof APPOINTMENT_STATUS[number];

export class AppointmentService {
  private repository = new AppointmentRepository();
  private notifications = new NotificationService();

  private async assertDoctorSlot(doctorId: string, date: Date, startTime: string, endTime: string) {
    const doctor = await prisma.doctor.findUnique({ where: { id: doctorId } });
    if (!doctor) throw new NotFoundError('Doctor not found');
    if (!doctor.isAvailable) throw new BadRequestError('Doctor is currently unavailable');

    const dayOfWeek = date.getDay();
    const availabilities = await this.repository.getDoctorAvailability(doctorId);
    const daySlot = availabilities.find(a => a.dayOfWeek === dayOfWeek && a.isAvailable);
    if (!daySlot) {
      throw new BadRequestError('Doctor is not available on this day');
    }
    if (startTime < daySlot.startTime || endTime > daySlot.endTime) {
      throw new BadRequestError(`Doctor is available between ${daySlot.startTime} and ${daySlot.endTime} on this day`);
    }

    const workingHours = await this.repository.getDoctorWorkingHours(doctorId, date);
    const override = workingHours.find(w => w.isAvailable);
    if (override) {
      if (startTime < override.startTime || endTime > override.endTime) {
        throw new BadRequestError(`Doctor's working hours on this date are ${override.startTime} - ${override.endTime}`);
      }
    } else if (workingHours.some(w => !w.isAvailable)) {
      throw new BadRequestError('Doctor is unavailable on this date');
    }
  }

  async book(data: {
    patientId: string;
    doctorId: string;
    appointmentDate: Date;
    startTime: string;
    endTime: string;
    type: string;
    reason?: string;
    institutionId?: string;
  }) {
    const doctor = await prisma.doctor.findUnique({ 
      where: { id: data.doctorId },
      include: {
        institutions: {
          where: { isPrimary: true },
          take: 1
        }
      }
    });
    if (!doctor) throw new NotFoundError('Doctor not found');
    if (!doctor.isAvailable) throw new BadRequestError('Doctor is currently unavailable');

    // Auto-assign institutionId from doctor's primary institution if not provided
    let institutionId = data.institutionId;
    if (!institutionId && doctor.institutions && doctor.institutions.length > 0) {
      institutionId = doctor.institutions[0].institutionId;
    }

    await this.assertDoctorSlot(data.doctorId, data.appointmentDate, data.startTime, data.endTime);

    const hasConflict = await this.repository.checkConflict(
      data.doctorId, data.appointmentDate, data.startTime, data.endTime,
    );
    if (hasConflict) throw new ConflictError('Time slot is already booked');

    const appointment = await this.repository.create({
      ...data,
      institutionId, // Use the determined institutionId
      durationMinutes: 30,
      amount: doctor.consultationFee,
    });

    const full = await this.repository.findById(appointment.id);
    if (!full) throw new NotFoundError('Appointment not found');
    emitToUser(doctor.userId, 'appointment:new', full);
    const patientName = `${full.patient.firstName ?? ''} ${full.patient.lastName ?? ''}`.trim();
    await this.notifications.sendNotification({
      userId: doctor.userId,
      title: 'Nouvelle demande de rendez-vous',
      body: `${patientName || 'Un patient'} a réservé un rendez-vous pour ${data.startTime} (${data.type}).`,
      type: 'appointment',
      data: { appointmentId: appointment.id, patientId: full.patient.id, status: 'pending' },
      actionUrl: '/appointments',
    }).catch(() => undefined);
    return full;
  }

  async approve(userId: string, role: string, appointmentId: string) {
    const appointment = await this.repository.findById(appointmentId);
    if (!appointment) throw new NotFoundError('Appointment not found');
    if (role === 'doctor' && appointment.doctor.userId !== userId) throw new ForbiddenError('Not your appointment');
    if (role !== 'doctor' && role !== 'admin') throw new ForbiddenError('Only doctors can approve');
    if (appointment.status !== 'pending') throw new BadRequestError('Appointment is not in pending status');

    const updated = await this.repository.update(appointmentId, { status: 'approved' });
    if (appointment.patient.user) {
      emitToUser(appointment.patient.user.id, 'appointment:updated', updated);
      await this.notifications.sendNotification({
        userId: appointment.patient.user.id,
        title: 'Rendez-vous approuvé',
        body: `Votre rendez-vous du ${updated.startTime} a été approuvé par le Dr ${appointment.doctor.firstName} ${appointment.doctor.lastName}.`,
        type: 'appointment',
        data: { appointmentId, status: 'approved' },
        actionUrl: '/appointments',
      }).catch(() => undefined);
    }
    return updated;
  }

  async confirm(userId: string, role: string, appointmentId: string) {
    const appointment = await this.repository.findById(appointmentId);
    if (!appointment) throw new NotFoundError('Appointment not found');
    if (role === 'patient' && appointment.patient.userId !== userId) throw new ForbiddenError('Not your appointment');
    if (role !== 'patient' && role !== 'admin') throw new ForbiddenError('Only patients can confirm');
    if (appointment.status !== 'approved') throw new BadRequestError('Appointment must be approved first');

    const updated = await this.repository.update(appointmentId, { status: 'confirmed' });
    if (appointment.patient.user) {
      emitToUser(appointment.patient.user.id, 'appointment:updated', updated);
    }
    emitToUser(appointment.doctor.user.id, 'appointment:updated', updated);
    await this.notifications.sendNotification({
      userId: appointment.doctor.user.id,
      title: 'Rendez-vous confirmé',
      body: `Le patient ${appointment.patient.firstName ?? ''} ${appointment.patient.lastName ?? ''} a confirmé le rendez-vous de ${updated.startTime}.`,
      type: 'appointment',
      data: { appointmentId, status: 'confirmed' },
      actionUrl: '/appointments',
    }).catch(() => undefined);
    return updated;
  }

  async cancel(userId: string, role: string, appointmentId: string, reason?: string) {
    const appointment = await this.repository.findById(appointmentId);
    if (!appointment) throw new NotFoundError('Appointment not found');
    if (appointment.patient.userId !== userId && appointment.doctor.userId !== userId && role !== 'admin') {
      throw new ForbiddenError('Not your appointment');
    }
    if (appointment.status === 'cancelled') throw new BadRequestError('Appointment is already cancelled');
    if (appointment.status === 'completed' || appointment.status === 'no_show') {
      throw new BadRequestError('A completed appointment cannot be cancelled');
    }

    const updated = await this.repository.update(appointmentId, {
      status: 'cancelled',
      cancellationReason: reason,
    });

    const notifyUser = role === 'doctor' && appointment.patient.user
      ? appointment.patient.user.id
      : appointment.doctor.user.id;
    emitToUser(notifyUser, 'appointment:cancelled', updated);
    await this.notifications.sendNotification({
      userId: notifyUser,
      title: 'Rendez-vous annulé',
      body: `Un rendez-vous a été annulé${reason ? ` : ${reason}` : '.'}`,
      type: 'appointment',
      data: { appointmentId, status: 'cancelled', reason },
      actionUrl: '/appointments',
    }).catch(() => undefined);
    return updated;
  }

  async reschedule(userId: string, role: string, appointmentId: string, data: {
    appointmentDate: Date;
    startTime: string;
    endTime: string;
    reason?: string;
  }) {
    const appointment = await this.repository.findById(appointmentId);
    if (!appointment) throw new NotFoundError('Appointment not found');
    if (appointment.patient.userId !== userId && appointment.doctor.userId !== userId && role !== 'admin') {
      throw new ForbiddenError('Not your appointment');
    }
    if (appointment.status === 'cancelled') throw new BadRequestError('A cancelled appointment cannot be rescheduled');
    if (appointment.status === 'completed' || appointment.status === 'no_show') {
      throw new BadRequestError('A completed appointment cannot be rescheduled');
    }

    await this.assertDoctorSlot(appointment.doctorId, data.appointmentDate, data.startTime, data.endTime);

    const hasConflict = await this.repository.checkConflict(
      appointment.doctorId, data.appointmentDate, data.startTime, data.endTime, appointmentId,
    );
    if (hasConflict) throw new ConflictError('Time slot is already booked');

    const updated = await this.repository.update(appointmentId, {
      ...data,
      status: 'rescheduled',
      rescheduleCount: appointment.rescheduleCount + 1,
    });

    if (appointment.patient.user) {
      emitToUser(appointment.patient.user.id, 'appointment:rescheduled', updated);
      await this.notifications.sendNotification({
        userId: appointment.patient.user.id,
        title: 'Rendez-vous reprogrammé',
        body: `Votre rendez-vous a été déplacé au ${data.startTime}.`,
        type: 'appointment',
        data: { appointmentId, status: 'rescheduled' },
        actionUrl: '/appointments',
      }).catch(() => undefined);
    }
    emitToUser(appointment.doctor.user.id, 'appointment:rescheduled', updated);
    await this.notifications.sendNotification({
      userId: appointment.doctor.user.id,
      title: 'Rendez-vous reprogrammé',
      body: `Le rendez-vous de ${appointment.patient.firstName ?? ''} ${appointment.patient.lastName ?? ''} a été déplacé au ${data.startTime}.`,
      type: 'appointment',
      data: { appointmentId, status: 'rescheduled' },
      actionUrl: '/appointments',
    }).catch(() => undefined);
    return updated;
  }

  async complete(userId: string, role: string, appointmentId: string) {
    const appointment = await this.repository.findById(appointmentId);
    if (!appointment) throw new NotFoundError('Appointment not found');
    if (role === 'doctor' && appointment.doctor.userId !== userId) throw new ForbiddenError('Not your appointment');
    if (role !== 'doctor' && role !== 'admin') throw new ForbiddenError('Only doctors can complete');
    if (appointment.status !== 'approved' && appointment.status !== 'confirmed' && appointment.status !== 'rescheduled') {
      throw new BadRequestError('Only approved or confirmed appointments can be completed');
    }

    const updated = await this.repository.update(appointmentId, { status: 'completed' });
    if (appointment.patient.user) {
      emitToUser(appointment.patient.user.id, 'appointment:completed', updated);
      await this.notifications.sendNotification({
        userId: appointment.patient.user.id,
        title: 'Consultation terminée',
        body: `Votre rendez-vous avec le Dr ${appointment.doctor.firstName} ${appointment.doctor.lastName} est terminé.`,
        type: 'appointment',
        data: { appointmentId, status: 'completed' },
        actionUrl: '/medical-booklet',
      }).catch(() => undefined);
    }
    return updated;
  }

  async markNoShow(userId: string, role: string, appointmentId: string) {
    const appointment = await this.repository.findById(appointmentId);
    if (!appointment) throw new NotFoundError('Appointment not found');
    if (role === 'doctor' && appointment.doctor.userId !== userId) throw new ForbiddenError('Not your appointment');
    if (role !== 'doctor' && role !== 'admin') throw new ForbiddenError('Only doctors can mark no-show');
    if (appointment.status !== 'approved' && appointment.status !== 'confirmed' && appointment.status !== 'rescheduled') {
      throw new BadRequestError('Only approved or confirmed appointments can be marked as no-show');
    }
    const updated = await this.repository.update(appointmentId, { status: 'no_show' });
    if (appointment.patient.user) {
      emitToUser(appointment.patient.user.id, 'appointment:updated', updated);
    }
    return updated;
  }

  private toMinutes(t: string) {
    const [h, m] = t.split(':').map(Number);
    return h * 60 + (m || 0);
  }

  private toHHMM(mins: number) {
    return `${String(Math.floor(mins / 60)).padStart(2, '0')}:${String(mins % 60).padStart(2, '0')}`;
  }

  async getAvailableSlots(doctorId: string, date: Date) {
    const doctor = await prisma.doctor.findUnique({ where: { id: doctorId } });
    if (!doctor) throw new NotFoundError('Doctor not found');
    if (!doctor.isAvailable) return [];

    const dayOfWeek = date.getDay();
    const availabilities = await this.repository.getDoctorAvailability(doctorId);
    const daySlot = availabilities.find(a => a.dayOfWeek === dayOfWeek && a.isAvailable);
    if (!daySlot) return [];

    let windowStart = daySlot.startTime;
    let windowEnd = daySlot.endTime;

    const workingHours = await this.repository.getDoctorWorkingHours(doctorId, date);
    const override = workingHours.find(w => w.isAvailable);
    if (override) {
      windowStart = override.startTime;
      windowEnd = override.endTime;
    } else if (workingHours.some(w => !w.isAvailable)) {
      return [];
    }

    const booked = await this.repository.findDoctorSlotsOnDate(doctorId, date);
    const slots: { startTime: string; endTime: string }[] = [];
    for (let m = this.toMinutes(windowStart); m + 30 <= this.toMinutes(windowEnd); m += 30) {
      const startTime = this.toHHMM(m);
      const endTime = this.toHHMM(m + 30);
      const conflict = booked.some(b => startTime < b.endTime && endTime > b.startTime);
      if (!conflict) slots.push({ startTime, endTime });
    }
    return slots;
  }

  async getById(userId: string, role: string, appointmentId: string) {
    const appointment = await this.repository.findById(appointmentId);
    if (!appointment) throw new NotFoundError('Appointment not found');
    const owns = appointment.patient.userId === userId || appointment.doctor.userId === userId;
    if (!owns && role !== 'admin') throw new ForbiddenError('Not your appointment');
    return appointment;
  }

  async getUpcoming(userId: string, role: string) {
    if (role === 'doctor') {
      const doctor = await prisma.doctor.findUnique({ where: { userId } });
      if (!doctor) throw new NotFoundError('Doctor profile not found');
      return this.repository.getUpcoming(doctor.id);
    }
    const patient = await prisma.patient.findUnique({ where: { userId } });
    if (!patient) throw new NotFoundError('Patient profile not found');
    return this.repository.getUpcoming(undefined, patient.id);
  }
}
