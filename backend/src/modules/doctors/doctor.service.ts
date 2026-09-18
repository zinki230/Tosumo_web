import { DoctorRepository } from './doctor.repository';
import { BadRequestError, ConflictError, NotFoundError, ForbiddenError, QrTokenUsedError } from '@shared/utils/errors';
import { verifyQrToken, markQrTokenUsed } from '@shared/utils/qr';
import { AccessService } from '@modules/access/access.service';
import prisma from '@shared/database/prisma';

export class DoctorService {
  private repository = new DoctorRepository();
  private accessService = new AccessService();

  async getAll(institutionId?: string) {
    return this.repository.findAll(institutionId);
  }

  async getById(id: string) {
    const doctor = await this.repository.findById(id);
    if (!doctor) throw new NotFoundError('Doctor not found');
    return doctor;
  }

  async register(userId: string, data: {
    firstName?: string;
    lastName?: string;
    specialty: string;
    licenseNumber: string;
    yearsOfExperience?: number;
    consultationFee?: number;
    bio?: string;
    title?: string;
    languages?: string[];
    city?: string;
    region?: string;
  }) {
    const existing = await this.repository.findByLicenseNumber(data.licenseNumber);
    if (existing) {
      throw new ConflictError('License number already registered');
    }
    const doctor = await this.repository.create({
      firstName: data.firstName ?? '',
      lastName: data.lastName ?? '',
      ...data,
      userId,
    });
    return doctor;
  }

  async getProfile(userId: string) {
    const doctor = await this.repository.findByUserId(userId);
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    return doctor;
  }

  async updateProfile(userId: string, data: Record<string, unknown>) {
    const doctor = await this.repository.findByUserId(userId);
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    return this.repository.update(doctor.id, data);
  }

  async getAvailability(userId: string) {
    const doctor = await this.repository.findByUserId(userId);
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    return this.repository.getAvailability(doctor.id);
  }

  async setAvailability(userId: string, slots: Array<{
    dayOfWeek: number;
    startTime: string;
    endTime: string;
    isAvailable?: boolean;
    slotDuration?: number;
  }>) {
    const doctor = await this.repository.findByUserId(userId);
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    await this.repository.setAvailability(doctor.id, slots);
    return this.repository.getAvailability(doctor.id);
  }

  async getWorkingHours(userId: string, date: Date) {
    const doctor = await this.repository.findByUserId(userId);
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    return this.repository.getWorkingHours(doctor.id, date);
  }

  async setWorkingHours(userId: string, hours: Array<{
    date: Date;
    startTime: string;
    endTime: string;
    isAvailable?: boolean;
    reason?: string;
  }>) {
    const doctor = await this.repository.findByUserId(userId);
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    await this.repository.setWorkingHours(doctor.id, hours);
    return this.repository.getWorkingHours(doctor.id, hours[0].date);
  }

  async getAppointments(userId: string, status?: string) {
    const doctor = await this.repository.findByUserId(userId);
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    return this.repository.getAppointments(doctor.id, status);
  }

  async getPatients(userId: string) {
    const doctor = await this.repository.findByUserId(userId);
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    return this.repository.getPatients(doctor.id);
  }

  async searchPatients(userId: string, role: string, query: string) {
    if (role !== 'doctor') throw new ForbiddenError('Only doctors can search patients');
    const doctor = await this.repository.findByUserId(userId);
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    const q = (query || '').trim();
    if (!q) return [];
    return this.repository.searchPatients(q);
  }

  async lookupPatientByCard(
    userId: string,
    role: string,
    cardNumber: string,
    token?: string,
  ) {
    if (role !== 'doctor') throw new ForbiddenError('Only doctors can scan patient cards');
    const doctor = await this.repository.findByUserId(userId);
    if (!doctor) throw new NotFoundError('Doctor profile not found');

    // Preferred path: a signed QR token from the patient app. The token is
    // cryptographically verified (signature + expiry + single-use) and the
    // doctor's authenticated identity is required before any patient data is
    // returned. A valid token is treated as in-person consent and creates a
    // temporary, auto-approved access grant for this doctor→patient pair.
    if (token) {
      const decoded = verifyQrToken(token);
      const patient = await this.repository.findPatientByCard(decoded.cardNumber);
      if (!patient) throw new NotFoundError('No patient found for this medical card');

      // Single-use with a graceful fallback: if the token was already redeemed
      // but this doctor already holds an active access grant, allow the lookup
      // so the demo / repeated views never get stuck. Otherwise reject.
      if (decoded.used) {
        const activeGrant = await prisma.accessManagement.findFirst({
          where: {
            patientId: patient.id,
            grantedToId: userId,
            isActive: true,
            deletedAt: null,
            OR: [{ endDate: null }, { endDate: { gte: new Date() } }],
          },
        });
        if (!activeGrant) {
          throw new QrTokenUsedError();
        }
      } else {
        const access = await this.accessService.grantScanAccess(patient.id, userId);
        markQrTokenUsed(decoded.jti);
        return { patient, access, scannedVia: 'token' };
      }

      const access = await prisma.accessManagement.findFirst({
        where: {
          patientId: patient.id,
          grantedToId: userId,
          isActive: true,
          deletedAt: null,
          OR: [{ endDate: null }, { endDate: { gte: new Date() } }],
        },
      });
      return { patient, access, scannedVia: 'token' };
    }

    // Backwards-compatible fallback: the raw card number (legacy QR codes).
    const patient = await this.repository.findPatientByCard(cardNumber);
    if (!patient) throw new NotFoundError('No patient found for this medical card');

    const access = await prisma.accessManagement.findFirst({
      where: {
        patientId: patient.id,
        grantedToId: userId,
        isActive: true,
        deletedAt: null,
        OR: [
          { endDate: null },
          { endDate: { gte: new Date() } },
        ],
      },
    });
    return { patient, access };
  }

  async getDashboard(userId: string) {
    const doctor = await this.repository.findByUserId(userId);
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    return this.repository.getDashboard(doctor.id);
  }

  async getStats(userId: string) {
    const doctor = await this.repository.findByUserId(userId);
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    return this.repository.getStats(doctor.id);
  }

  async getReviews(userId: string) {
    const doctor = await this.repository.findByUserId(userId);
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    return this.repository.getReviews(doctor.id);
  }

  async getInstitutions(userId: string) {
    const doctor = await this.repository.findByUserId(userId);
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    return this.repository.getInstitutions(doctor.id);
  }

  async verifyDoctor(doctorId: string, isVerified: boolean, rejectionReason?: string) {
    const doctor = await this.repository.findById(doctorId);
    if (!doctor) throw new NotFoundError('Doctor not found');
    return this.repository.update(doctorId, {
      isVerified,
      verifiedAt: isVerified ? new Date() : null,
      rejectionReason: isVerified ? null : (rejectionReason || null),
    });
  }

  async setAvailabilityStatus(userId: string, isAvailable: boolean) {
    const doctor = await this.repository.findByUserId(userId);
    if (!doctor) throw new NotFoundError('Doctor profile not found');
    return this.repository.update(doctor.id, { isAvailable });
  }
}
