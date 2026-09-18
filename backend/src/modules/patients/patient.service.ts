import { PatientRepository } from './patient.repository';
import { BadRequestError, NotFoundError } from '@shared/utils/errors';
import { generateCardNumber } from '@shared/utils/helpers';
import { generateQrToken } from '@shared/utils/qr';

export class PatientService {
  private repository = new PatientRepository();

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

  async updateByDoctor(patientId: string, data: Record<string, unknown>) {
    const patient = await this.repository.findById(patientId);
    if (!patient) throw new NotFoundError('Patient profile not found');
    const payload: Record<string, unknown> = { ...data };
    
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
    
    if (payload['isVerified'] === true) {
      payload['verifiedAt'] = new Date();
    }
    return this.repository.update(patient.id, payload);
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
