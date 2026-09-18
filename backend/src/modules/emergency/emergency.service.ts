import { EmergencyRepository } from './emergency.repository';
import { NotFoundError, ForbiddenError, BadRequestError } from '@shared/utils/errors';
import { emitToUser, emitToAll } from '@shared/socket';
import prisma from '@shared/database/prisma';
import { NotificationService } from '@modules/notifications/notification.service';

export class EmergencyService {
  private repository = new EmergencyRepository();
  private notifications = new NotificationService();

  private async criticalInfoPayload(patientId: string) {
    const criticalInfo = await this.repository.getPatientCriticalInfo(patientId);
    const patient = await prisma.patient.findUnique({
      where: { id: patientId },
      select: { firstName: true, lastName: true, gender: true, dateOfBirth: true },
    });
    const age = patient?.dateOfBirth
      ? Math.floor((Date.now() - patient.dateOfBirth.getTime()) / (365.25 * 24 * 60 * 60 * 1000))
      : 0;
    return {
      name: patient ? `${patient.firstName ?? ''} ${patient.lastName ?? ''}`.trim() : '',
      age,
      gender: patient?.gender ?? '',
      bloodType: criticalInfo?.bloodType ?? '',
      allergies: criticalInfo?.allergies ?? [],
      chronicDiseases: criticalInfo?.chronicDiseases ?? [],
      emergencyContact: criticalInfo
        ? {
            name: criticalInfo.emergencyContactName ?? '',
            phone: criticalInfo.emergencyContactPhone ?? '',
          }
        : null,
      medicalCardNumber: criticalInfo?.medicalCard?.cardNumber ?? '',
    };
  }

  async triggerSOS(userId: string, data: {
    latitude?: number;
    longitude?: number;
    message?: string;
  }) {
    const patient = await prisma.patient.findUnique({ where: { userId } });
    if (!patient) throw new NotFoundError('Patient profile not found');

    const criticalInfo = await this.criticalInfoPayload(patient.id);
    const nearbyHospitals = (data.latitude && data.longitude)
      ? await this.repository.getNearbyHospitals(data.latitude, data.longitude)
      : [];

    // Create an incoming emergency session so doctors can acknowledge it.
    const session = await this.repository.createSession({
      patientId: patient.id,
      message: data.message || 'SOS Emergency!',
      chiefComplaint: data.message || 'SOS Emergency!',
      location: data.latitude && data.longitude
        ? { latitude: data.latitude, longitude: data.longitude } : undefined,
      criticalInfo,
    });

    const sosPayload = {
      sessionId: session.id,
      patientId: patient.id,
      patientName: criticalInfo.name,
      criticalInfo,
      location: data.latitude && data.longitude ? { latitude: data.latitude, longitude: data.longitude } : null,
      message: data.message || 'SOS Emergency!',
      timestamp: new Date(),
      status: 'incoming',
    };

    // Notify doctors which have a standing relationship with the patient
    // (access grants, appointments) as well as all available verified doctors.
    const relevantDoctorIds = new Set<string>();
    const accessDocs = await prisma.accessManagement.findMany({
      where: { patientId: patient.id, isActive: true, deletedAt: null },
      select: { grantedToId: true },
    });
    for (const a of accessDocs) relevantDoctorIds.add(a.grantedToId);

    const appointmentDocs = await prisma.appointment.findMany({
      where: { patientId: patient.id, deletedAt: null },
      select: { doctor: { select: { userId: true } } },
    });
    for (const a of appointmentDocs) {
      if (a.doctor?.userId) relevantDoctorIds.add(a.doctor.userId);
    }

    const availableDoctors = await prisma.doctor.findMany({
      where: { isAvailable: true, isVerified: true, deletedAt: null },
      select: { userId: true },
      take: 20,
    });
    for (const d of availableDoctors) relevantDoctorIds.add(d.userId);

    for (const doctorUserId of relevantDoctorIds) {
      emitToUser(doctorUserId, 'emergency:new-session', sosPayload);
      await this.notifications.sendNotification({
        userId: doctorUserId,
        title: '🆘 Alerte d\'urgence',
        body: `${criticalInfo.name || 'Un patient'} a déclenché une urgence.`,
        type: 'emergency',
        data: { sessionId: session.id, patientId: patient.id, status: 'incoming' },
        actionUrl: `/emergency`,
      }).catch(() => undefined);
    }

    // Notify patient emergency contacts (phone-based users).
    const contacts = await prisma.emergencyInfo.findMany({
      where: { patientId: patient.id, deletedAt: null },
    });
    for (const contact of contacts) {
      try {
        const contactUser = await prisma.user.findUnique({ where: { phone: contact.phone } });
        if (contactUser) {
          emitToUser(contactUser.id, 'emergency:contact-alert', sosPayload);
        }
      } catch { /* contact may not be a user */ }
    }

    return {
      message: 'SOS alert sent successfully',
      sessionId: session.id,
      status: session.status,
      nearbyHospitals: nearbyHospitals.length,
      contactsNotified: contacts.length,
      doctorsNotified: relevantDoctorIds.size,
    };
  }

  /**
   * Doctor opens/acknowledges an emergency session for a patient. Adopts an
   * existing incoming session if one exists, otherwise creates a new one.
   * Grants the doctor an emergency access to the patient (24 hours).
   */
  async startSession(userId: string, patientId: string, justification?: string) {
    const doctor = await prisma.doctor.findUnique({ where: { userId } });
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    const patient = await prisma.patient.findUnique({ where: { id: patientId } });
    if (!patient) throw new NotFoundError('Patient not found');

    const incoming = await this.repository.findIncomingSessionForPatient(patient.id);
    let session;
    if (incoming) {
      session = await this.repository.acknowledgeSession(incoming.id, doctor.id);
    } else {
      session = await this.repository.createSession({
        patientId: patient.id,
        chiefComplaint: justification || 'Emergency consultation',
        criticalInfo: await this.criticalInfoPayload(patient.id),
      });
      session = await this.repository.acknowledgeSession(session.id, doctor.id);
    }

    // Ensure an active emergency access grant exists for this doctor.
    const existingAccess = await prisma.accessManagement.findFirst({
      where: {
        patientId: patient.id,
        grantedToId: userId,
        isActive: true,
        isEmergency: true,
        deletedAt: null,
      },
    });
    if (!existingAccess) {
      await prisma.accessManagement.create({
        data: {
          patientId: patient.id,
          grantedToId: userId,
          grantedById: patient.userId,
          accessLevel: 'full',
          accessType: 'temporary',
          endDate: new Date(Date.now() + 24 * 60 * 60 * 1000),
          reason: justification || 'Emergency access',
          isEmergency: true,
          isApproved: true,
        },
      });
    }

    if (patient.userId) {
      emitToUser(patient.userId, 'emergency:session-updated', {
        sessionId: session.id,
        status: 'acknowledged',
        doctorName: `Dr. ${doctor.firstName} ${doctor.lastName}`,
      });
    }
    return session;
  }

  async updateSession(userId: string, sessionId: string, status: string) {
    const doctor = await prisma.doctor.findUnique({ where: { userId } });
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    const session = await this.repository.findById(sessionId);
    if (!session || session.deletedAt) throw new NotFoundError('Emergency session not found');

    const isOwner = session.doctorId === doctor.id;
    const isIncoming = session.status === 'incoming' && status === 'acknowledged';
    if (!isOwner && !isIncoming) throw new ForbiddenError('Not your emergency session');

    if (session.doctorId && !isOwner) throw new ForbiddenError('Session already claimed by another doctor');

    const allowed = ['acknowledged', 'active', 'resolved', 'ended', 'void'];
    if (!allowed.includes(status)) throw new BadRequestError('Invalid session status');

    let updated;
    if (status === 'acknowledged' && !session.doctorId) {
      updated = await this.repository.acknowledgeSession(sessionId, doctor.id);
    } else {
      updated = await this.repository.transition(sessionId, status);
    }

    if (session.patient.userId) {
      emitToUser(session.patient.userId, 'emergency:session-updated', {
        sessionId,
        status: updated.status,
      });
    }
    emitToAll('emergency:session-updated', { sessionId, status: updated.status });
    return updated;
  }

  async getSessionsByDoctor(userId: string, status?: string) {
    const doctor = await prisma.doctor.findUnique({ where: { userId } });
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    return this.repository.findByDoctor(doctor.id, status);
  }

  async getActiveSession(userId: string) {
    const doctor = await prisma.doctor.findUnique({ where: { userId } });
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    const session = await this.repository.findActiveByDoctor(doctor.id);
    // compute patient summary to include in response
    if (!session) return null;
    const summary = session.patientId ? await this.criticalInfoPayload(session.patientId) : null;
    return { ...session, patientSummary: summary };
  }

  async getSessionByIdForDoctor(userId: string, sessionId: string) {
    const doctor = await prisma.doctor.findUnique({ where: { userId } });
    const session = await this.repository.findById(sessionId);
    if (!session || session.deletedAt) throw new NotFoundError('Emergency session not found');
    if (doctor && session.doctorId && session.doctorId !== doctor.id && session.status !== 'incoming') {
      throw new ForbiddenError('Not your emergency session');
    }
    const summary = await this.criticalInfoPayload(session.patientId);
    return { ...session, patientSummary: summary };
  }

  /**
   * Doctor fetches authorized critical info for a patient. Allowed when:
   * - an active emergency session exists for this doctor+patient, or
   * - an active emergency access grant exists, or
   * - an active normal access grant exists.
   */
  async getCriticalInfoForDoctor(userId: string, patientId: string) {
    const doctor = await prisma.doctor.findUnique({ where: { userId } });
    if (!doctor) throw new NotFoundError('Doctor profile not found');

    const session = await prisma.emergencySession.findFirst({
      where: {
        patientId,
        doctorId: doctor.id,
        status: { in: ['acknowledged', 'active'] },
        deletedAt: null,
      },
    });
    const access = await prisma.accessManagement.findFirst({
      where: {
        patientId,
        grantedToId: userId,
        isActive: true,
        deletedAt: null,
        OR: [{ isEmergency: true }, { endDate: null }, { endDate: { gt: new Date() } }],
      },
    });

    if (!session && !access) {
      throw new ForbiddenError('No emergency or access authorization for this patient');
    }
    return this.criticalInfoPayload(patientId);
  }

  async getCriticalInfo(userId: string) {
    const patient = await prisma.patient.findUnique({ where: { userId } });
    if (!patient) throw new NotFoundError('Patient profile not found');
    return this.criticalInfoPayload(patient.id);
  }

  async getNearbyHospitals(latitude: number, longitude: number, radiusKm?: number) {
    return this.repository.getNearbyHospitals(latitude, longitude, radiusKm);
  }
}