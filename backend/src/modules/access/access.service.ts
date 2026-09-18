import { AccessRepository } from './access.repository';
import { NotFoundError, ForbiddenError, BadRequestError } from '@shared/utils/errors';
import { emitToUser } from '@shared/socket';
import prisma from '@shared/database/prisma';
import { NotificationService } from '@modules/notifications/notification.service';

export class AccessService {
  private repository = new AccessRepository();
  private notifications = new NotificationService();

  async grantAccess(userId: string, data: {
    patientId: string;
    doctorUserId: string;
    accessLevel: string;
    accessType: string;
    endDate?: Date;
    reason?: string;
  }) {
    const grant = await this.repository.create({
      ...data,
      grantedToId: data.doctorUserId,
      grantedById: userId,
      deletedAt: null,
    });

    emitToUser(data.doctorUserId, 'access:granted', grant);

    const patient = await prisma.patient.findUnique({
      where: { id: data.patientId },
      include: { user: true },
    });
    await this.notifications.sendNotification({
      userId: data.doctorUserId,
      title: 'Accès patient accordé',
      body: `${patient?.firstName ?? 'Un patient'} vous a accordé l'accès à son dossier médical.`,
      type: 'access',
      data: { accessId: grant.id, patientId: data.patientId, accessLevel: data.accessLevel },
      actionUrl: '/patients',
    }).catch(() => undefined);
    return grant;
  }

  /**
   * Doctor requests access to a patient's records. Creates a pending grant that
   * the patient must approve. The patient app is notified via socket + push.
   */
  async requestAccess(userId: string, data: {
    patientId: string;
    accessLevel?: string;
    reason?: string;
  }) {
    const doctor = await prisma.doctor.findUnique({ where: { userId } });
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    const patient = await prisma.patient.findUnique({
      where: { id: data.patientId },
      include: { user: true },
    });
    if (!patient) throw new NotFoundError('Patient not found');

    const alreadyActive = await this.repository.findActiveByDoctor(patient.id, userId);
    if (alreadyActive && alreadyActive.isApproved) {
      return alreadyActive;
    }

    const request = await this.repository.create({
      patientId: patient.id,
      grantedToId: userId,
      grantedById: patient.userId,
      accessLevel: data.accessLevel || 'read',
      accessType: 'temporary',
      endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      reason: data.reason,
      isApproved: false,
      deletedAt: null,
    });

    if (patient.userId) {
      emitToUser(patient.userId, 'access:request', request);
      await this.notifications.sendNotification({
        userId: patient.userId,
        title: 'Demande d\'accès',
        body: `Le Dr ${doctor.firstName} ${doctor.lastName} demande l'accès à votre dossier médical.`,
        type: 'access',
        data: { accessId: request.id, doctorUserId: userId, status: 'pending' },
        actionUrl: '/access',
      }).catch(() => undefined);
    }

    return this.repository.findByGrantedToId(userId);
  }

  async approveAccess(accessId: string) {
    const record = await this.repository.update(accessId, { isApproved: true });
    const full = await prisma.accessManagement.findUnique({
      where: { id: accessId },
      include: { grantedTo: true },
    });
    if (full?.grantedById) {
      emitToUser(full.grantedById, 'access:approved', { id: accessId, isApproved: true });
    }
    return record;
  }

  /**
   * In-person consent model: when an authenticated doctor scans a valid,
   * signed, unexpired patient medical-card QR token, the patient is deemed to
   * have authorised that specific doctor for this specific card. We record a
   * temporary, auto-approved, full-access grant (idempotent — refreshes the
   * expiry if one already exists). This is the authorization rule that gates
   * access to the patient's full record; it never bypasses authentication.
   */
  async grantScanAccess(patientId: string, doctorUserId: string, ttlHours = 8) {
    const patient = await prisma.patient.findUnique({ where: { id: patientId } });
    if (!patient) throw new NotFoundError('Patient not found');

    const existing = await this.repository.findActiveByDoctor(patientId, doctorUserId);
    const endDate = new Date(Date.now() + ttlHours * 60 * 60 * 1000);

    if (existing) {
      return this.repository.update(existing.id, {
        isActive: true,
        isApproved: true,
        endDate,
        reason: 'Accès scanné via QR patient (présence)',
      });
    }

    const grant = await this.repository.create({
      patientId,
      grantedToId: doctorUserId,
      grantedById: doctorUserId,
      accessLevel: 'full',
      accessType: 'temporary',
      endDate,
      reason: 'Accès scanné via QR patient (présence)',
      isApproved: true,
      isActive: true,
      deletedAt: null,
    });

    if (patient.userId) {
      await this.notifications
        .sendNotification({
          userId: patient.userId,
          title: 'Accès médecin autorisé',
          body: 'Un médecin a scanné votre carte médicale et dispose d\'un accès temporaire à votre dossier.',
          type: 'access',
          data: { accessId: grant.id, patientId, accessLevel: 'full' },
          actionUrl: '/access',
        })
        .catch(() => undefined);
    }

    return grant;
  }

  async revokeAccess(userId: string, accessId: string, reason?: string) {
    const record = await this.repository.update(accessId, {
      isActive: false,
      revokedAt: new Date(),
      revokedById: userId,
      revokeReason: reason,
    });

    const full = await prisma.accessManagement.findUnique({
      where: { id: accessId },
      include: { grantedTo: true },
    });

    if (full) {
      emitToUser(full.grantedToId, 'access:revoked', { id: accessId });
      await this.notifications.sendNotification({
        userId: full.grantedToId,
        title: 'Accès révoqué',
        body: `Votre accès au dossier patient a été révoqué${reason ? ` : ${reason}` : '.'}`,
        type: 'access',
        data: { accessId, reason },
      }).catch(() => undefined);
    }
    return record;
  }

  async getPatientAccesses(userId: string) {
    const patient = await prisma.patient.findUnique({ where: { userId } });
    if (!patient) throw new NotFoundError('Patient profile not found');
    return this.repository.findByPatientId(patient.id);
  }

  async getDoctorAccesses(userId: string) {
    return this.repository.findByGrantedToId(userId);
  }

  async checkAccess(patientUserId: string, doctorUserId: string) {
    const patient = await prisma.patient.findUnique({ where: { userId: patientUserId } });
    if (!patient) throw new NotFoundError('Patient not found');

    const access = await this.repository.findActiveByDoctor(patient.id, doctorUserId);
    return { hasAccess: !!access, access };
  }

  async grantEmergencyAccess(userId: string, patientUserId: string, reason?: string) {
    const patient = await prisma.patient.findUnique({ where: { userId: patientUserId } });
    if (!patient) throw new NotFoundError('Patient not found');

    const existing = await this.repository.findActiveByDoctor(patient.id, userId);
    if (existing) {
      return existing;
    }

    const access = await this.repository.create({
      patientId: patient.id,
      grantedToId: userId,
      grantedById: userId,
      accessLevel: 'full',
      accessType: 'temporary',
      endDate: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
      reason: reason || 'Emergency access',
      isEmergency: true,
      deletedAt: null,
    });

    emitToUser(patientUserId, 'emergency:access-granted', access);
    return access;
  }
}
