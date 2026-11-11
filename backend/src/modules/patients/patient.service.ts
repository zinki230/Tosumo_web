import { PatientRepository } from './patient.repository';
import { BadRequestError, ForbiddenError, NotFoundError } from '@shared/utils/errors';
import { generateCardNumber } from '@shared/utils/helpers';
import { generateQrToken } from '@shared/utils/qr';
import prisma from '@shared/database/prisma';

export class PatientService {
  private repository = new PatientRepository();

  async recordVisit(patientId: string, doctorUserId: string, institutionId: string) {
    const [doctor, patient, institution, access] = await Promise.all([
      prisma.doctor.findUnique({ where: { userId: doctorUserId } }),
      prisma.patient.findUnique({ where: { id: patientId }, include: { medicalCard: true } }),
      prisma.institution.findFirst({ where: { id: institutionId, isVerified: true, deletedAt: null } }),
      prisma.accessManagement.findFirst({
        where: {
          grantedToId: doctorUserId,
          patientId,
          isActive: true,
          deletedAt: null,
          OR: [{ endDate: null }, { endDate: { gte: new Date() } }],
        },
      }),
    ]);
    if (!doctor) throw new ForbiddenError('Profil médecin introuvable');
    if (!patient) throw new NotFoundError('Patient introuvable');
    if (!institution) throw new BadRequestError('Sélectionnez un centre de santé vérifié dans la liste');
    if (!access) throw new ForbiddenError('Le patient doit autoriser l’accès avant d’enregistrer la visite');

    const medicalCard = patient.medicalCard ?? await prisma.medicalCard.create({
      data: { patientId, cardNumber: generateCardNumber(), deletedAt: null },
    });
    const recentVisit = await prisma.visit.findFirst({
      where: {
        medicalCardId: medicalCard.id,
        doctorId: doctor.id,
        institutionId,
        visitDate: { gte: new Date(Date.now() - 15 * 60 * 1000) },
      },
      orderBy: { visitDate: 'desc' },
    });
    if (recentVisit) return recentVisit;
    return prisma.visit.create({
      data: {
        medicalCardId: medicalCard.id,
        doctorId: doctor.id,
        institutionId,
        visitDate: new Date(),
        notes: 'Visite enregistrée depuis l’application médecin',
      },
    });
  }

  async getProfile(userId: string) {
    let patient = await this.repository.findByUserId(userId);
    if (!patient) {
      const created = await this.repository.create({ userId });
      if (created.userId) {
        patient = await this.repository.findByUserId(created.userId);
      }
    }
    return patient;
  }

  async updateProfile(userId: string, data: Record<string, unknown>) {
    const patient = await this.repository.findByUserId(userId);
    if (!patient) throw new NotFoundError('Patient profile not found');
    return this.repository.update(patient.id, data);
  }

  async updateByDoctor(patientId: string, data: Record<string, unknown>, doctorUserId: string) {
    const patient = await this.repository.findById(patientId);
    if (!patient) throw new NotFoundError('Patient profile not found');
    const payload: Record<string, unknown> = { ...data };

    // Scanning the QR identifies the patient; signing is a separate action.
    // Do not persist a verified status until the doctor has recorded at least
    // one clinical detail (or a complete emergency contact).
    if (data['isVerified'] === true) {
      const institutionId = typeof data['institutionId'] === 'string' ? data['institutionId'] : '';
      if (!institutionId) throw new BadRequestError('Sélectionnez le centre de santé où la vérification est effectuée');
      const hasValue = (value: unknown) => typeof value === 'string' && value.trim().length > 0;
      const hasEntries = (incoming: unknown, existing: unknown) => {
        const values = Array.isArray(incoming) ? incoming : Array.isArray(existing) ? existing : [];
        return values.some((value) => hasValue(value));
      };
      const contact = (data['emergencyContact'] ?? {}) as Record<string, unknown>;
      const chronicHistory = patient.chronicConditions.length
        ? patient.chronicConditions
        : patient.chronicDiseases;
      const hasClinicalDetails =
        hasValue(data['bloodType'] ?? patient.bloodType) ||
        hasEntries(data['allergies'], patient.allergies) ||
        hasEntries(data['chronicConditions'] ?? data['chronicDiseases'], chronicHistory) ||
        hasEntries(data['currentMeds'], patient.currentMeds) ||
        (hasValue(contact['name'] ?? patient.emergencyContactName) &&
          hasValue(contact['relationship'] ?? patient.emergencyContactRelationship) &&
          hasValue(contact['phone'] ?? patient.emergencyContactPhone));

      if (!hasClinicalDetails) {
        throw new BadRequestError(
          'Renseignez au moins une information médicale ou un contact d’urgence complet avant de signer la carte.',
        );
      }

      const doctor = await prisma.doctor.findUnique({ where: { userId: doctorUserId } });
      if (!doctor) throw new ForbiddenError('Profil médecin introuvable. Complétez votre profil avant de vérifier une carte.');
      payload['verifiedBy'] = doctor.id;
      payload['verifiedByName'] = `${doctor.firstName} ${doctor.lastName}`.trim();
      payload['verifiedAt'] = new Date();
    } else if (data['isVerified'] === false) {
      payload['verifiedBy'] = null;
      payload['verifiedByName'] = null;
      payload['verifiedAt'] = null;
    }
    
    // Handle emergency contact mapping
    const ec = data['emergencyContact'] as Record<string, unknown> | undefined;
    if (ec != null) {
      payload['emergencyContactName'] = ec['name'] ?? patient.emergencyContactName;
      payload['emergencyContactPhone'] = ec['phone'] ?? patient.emergencyContactPhone;
      payload['emergencyContactRelationship'] = ec['relationship'] ?? patient.emergencyContactRelationship;
      delete payload['emergencyContact'];
    }
    
    // Sync chronicConditions with chronicDiseases for backward compatibility
    if (payload['chronicConditions'] != null && payload['chronicDiseases'] == null) {
      payload['chronicDiseases'] = payload['chronicConditions'];
    } else if (payload['chronicDiseases'] != null && payload['chronicConditions'] == null) {
      payload['chronicConditions'] = payload['chronicDiseases'];
    }
    
    const updated = await this.repository.update(patient.id, payload);
    if (data['isVerified'] === true) {
      await this.recordVisit(patient.id, doctorUserId, String(data['institutionId']));
    }
    return updated;
  }

  async onboardPatient(userId: string, data: {
    firstName?: string;
    lastName?: string;
    dateOfBirth: Date | string;
    gender: string;
    bloodType?: string;
    allergies?: string[];
    chronicDiseases?: string[];
    emergencyContactName?: string;
    emergencyContactPhone?: string;
    city?: string;
    address?: string;
  }) {
    let patient = await this.repository.findByUserId(userId);
    const payload = {
      ...data,
      dateOfBirth: data.dateOfBirth ? new Date(data.dateOfBirth) : undefined,
      isOnboarded: true,
      onboardingStep: 5,
    };
    if (!patient) {
      const created = await this.repository.create({ userId, ...payload });
      if (created.userId) {
        patient = await this.repository.findByUserId(created.userId);
      }
    } else {
      await this.repository.update(patient.id, payload);
      patient = await this.repository.findByUserId(userId);
    }

    const existingCard = await this.repository.getMedicalCard(patient!.id);
    if (!existingCard) {
      await this.repository.createMedicalCard(patient!.id, generateCardNumber());
    }

    return patient;
  }

  async getMedicalCard(userId: string) {
    const patient = await this.repository.findByUserId(userId);
    if (!patient) throw new NotFoundError('Patient profile not found');
    const existing = await this.repository.getMedicalCard(patient.id);
    const card = existing ?? (await this.repository.createMedicalCard(patient.id, generateCardNumber()));

    // Issue a signed, short-lived QR token that encodes the card number (not
    // any sensitive medical data). The doctor app sends this token back; the
    // backend verifies signature + expiry + single-use before returning data.
    const { token, expiresAt } = generateQrToken({
      patientId: patient.id,
      cardNumber: card.cardNumber,
    });

    return {
      ...card,
      qrToken: token,
      qrExpiresAt: expiresAt,
    };
  }

  async getEmergencyContacts(userId: string) {
    const patient = await this.repository.findByUserId(userId);
    if (!patient) throw new NotFoundError('Patient profile not found');
    return this.repository.getEmergencyInfos(patient.id);
  }

  async addEmergencyContact(userId: string, data: {
    fullName: string;
    phone: string;
    relationship: string;
    isPrimary?: boolean;
  }) {
    const patient = await this.repository.findByUserId(userId);
    if (!patient) throw new NotFoundError('Patient profile not found');
    return this.repository.createEmergencyInfo({ ...data, patientId: patient.id });
  }

  async updateEmergencyContact(userId: string, contactId: string, data: Record<string, unknown>) {
    const patient = await this.repository.findByUserId(userId);
    if (!patient) throw new NotFoundError('Patient profile not found');
    return this.repository.updateEmergencyInfo(contactId, data);
  }

  async deleteEmergencyContact(userId: string, contactId: string) {
    const patient = await this.repository.findByUserId(userId);
    if (!patient) throw new NotFoundError('Patient profile not found');
    return this.repository.deleteEmergencyInfo(contactId);
  }

  async getMedicalBooklets(userId: string) {
    const patient = await this.repository.findByUserId(userId);
    if (!patient) throw new NotFoundError('Patient profile not found');
    return this.repository.getMedicalBooklets(patient.id);
  }

  async addMedicalBooklet(userId: string, data: {
    title: string;
    description?: string;
    fileUrl?: string;
    bookletType: string;
    hospitalName?: string;
    doctorName?: string;
    recordDate?: Date;
  }) {
    const patient = await this.repository.findByUserId(userId);
    if (!patient) throw new NotFoundError('Patient profile not found');
    return this.repository.createMedicalBooklet({ ...data, patientId: patient.id });
  }

  async deleteMedicalBooklet(userId: string, bookletId: string) {
    const patient = await this.repository.findByUserId(userId);
    if (!patient) throw new NotFoundError('Patient profile not found');
    return this.repository.deleteMedicalBooklet(bookletId);
  }

  async getJourney(userId: string) {
    const patient = await this.repository.findByUserId(userId);
    if (!patient) throw new NotFoundError('Patient profile not found');
    return this.repository.getJourney(patient.id);
  }

  async getAppointments(userId: string) {
    const patient = await this.repository.findByUserId(userId);
    if (!patient) throw new NotFoundError('Patient profile not found');
    return this.repository.getAppointments(patient.id);
  }

  async getMedicalRecords(userId: string) {
    const patient = await this.repository.findByUserId(userId);
    if (!patient) throw new NotFoundError('Patient profile not found');
    return this.repository.getMedicalRecords(patient.id);
  }

  async getPatientByIdOrUserId(id: string) {
    let patient = await this.repository.findById(id);
    if (!patient) {
      patient = await this.repository.findByUserId(id);
    }
    return patient;
  }
}
