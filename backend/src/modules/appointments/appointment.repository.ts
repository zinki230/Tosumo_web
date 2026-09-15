import prisma from '@shared/database/prisma';

export class AppointmentRepository {
  async findById(id: string) {
    return prisma.appointment.findUnique({
      where: { id },
      include: { patient: { include: { user: true } }, doctor: { include: { user: true } }, institution: true },
    });
  }

  async findByPatientId(patientId: string) {
    return prisma.appointment.findMany({
      where: { patientId, deletedAt: null },
      include: { doctor: true, institution: true },
      orderBy: { appointmentDate: 'desc' },
    });
  }

  async findByDoctorId(doctorId: string) {
    return prisma.appointment.findMany({
      where: { doctorId, deletedAt: null },
      include: { patient: true, institution: true },
      orderBy: { appointmentDate: 'desc' },
    });
  }

  async create(data: {
    patientId: string;
    doctorId: string;
    appointmentDate: Date;
    startTime: string;
    endTime: string;
    durationMinutes?: number;
    type: string;
    reason?: string;
    institutionId?: string;
    amount?: number;
  }) {
    return prisma.appointment.create({ data: { ...data, status: 'pending' } });
  }

  private readonly allowedUpdateFields = [
    'status', 'startTime', 'endTime', 'appointmentDate', 'durationMinutes',
    'cancellationReason', 'notes', 'rescheduleCount', 'paymentMethod', 'paymentReference',
    'isPaid', 'amount', 'metadata',
  ];

  async update(id: string, data: Record<string, unknown>) {
    const filtered: Record<string, unknown> = {};
    for (const key of this.allowedUpdateFields) {
      if (key in data) filtered[key] = data[key];
    }
    return prisma.appointment.update({
      where: { id },
      data: { ...filtered, version: { increment: 1 } },
    });
  }

  async checkConflict(doctorId: string, date: Date, startTime: string, endTime: string, excludeId?: string) {
    const startOfDay = new Date(date);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(date);
    endOfDay.setHours(23, 59, 59, 999);

    const where: Record<string, unknown> = {
      doctorId,
      appointmentDate: { gte: startOfDay, lte: endOfDay },
      status: { notIn: ['cancelled', 'no_show', 'completed'] },
      deletedAt: null,
    };
    if (excludeId) where.id = { not: excludeId };

    const appointments = await prisma.appointment.findMany({ where });
    return appointments.some(a => startTime < a.endTime && endTime > a.startTime);
  }

  async findDoctorSlotsOnDate(doctorId: string, date: Date) {
    const startOfDay = new Date(date);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(date);
    endOfDay.setHours(23, 59, 59, 999);

    return prisma.appointment.findMany({
      where: {
        doctorId,
        appointmentDate: { gte: startOfDay, lte: endOfDay },
        status: { notIn: ['cancelled', 'no_show', 'completed'] },
        deletedAt: null,
      },
      select: { startTime: true, endTime: true },
    });
  }

  async getDoctorAvailability(doctorId: string) {
    return prisma.doctorAvailability.findMany({ where: { doctorId } });
  }

  async getDoctorWorkingHours(doctorId: string, date: Date) {
    const startOfDay = new Date(date);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(date);
    endOfDay.setHours(23, 59, 59, 999);
    return prisma.workingHours.findMany({
      where: { doctorId, date: { gte: startOfDay, lte: endOfDay } },
    });
  }

  async getUpcoming(doctorId?: string, patientId?: string) {
    const where: Record<string, unknown> = {
      appointmentDate: { gte: new Date() },
      status: { notIn: ['cancelled', 'completed', 'no_show'] },
      deletedAt: null,
    };
    if (doctorId) where.doctorId = doctorId;
    if (patientId) where.patientId = patientId;

    return prisma.appointment.findMany({
      where,
      include: { doctor: true, patient: true, institution: true },
      orderBy: { appointmentDate: 'asc' },
    });
  }

  async getByDateRange(doctorId: string, startDate: Date, endDate: Date) {
    return prisma.appointment.findMany({
      where: {
        doctorId,
        appointmentDate: { gte: startDate, lte: endDate },
        deletedAt: null,
      },
      orderBy: { appointmentDate: 'asc' },
    });
  }

  async getStats(doctorId: string) {
    const [total, completed, cancelled, pending] = await Promise.all([
      prisma.appointment.count({ where: { doctorId, deletedAt: null } }),
      prisma.appointment.count({ where: { doctorId, status: 'completed', deletedAt: null } }),
      prisma.appointment.count({ where: { doctorId, status: 'cancelled', deletedAt: null } }),
      prisma.appointment.count({ where: { doctorId, status: 'pending', deletedAt: null } }),
    ]);
    return { total, completed, cancelled, pending };
  }
}
