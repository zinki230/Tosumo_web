import prisma from '@shared/database/prisma';
import { generateId } from '@shared/utils/helpers';

export class PatientRepository {
  private generateTempNin(): string {
    return `TMP-${generateId()}`;
  }
  async findByUserId(userId: string) {
    return prisma.patient.findUnique({
      where: { userId },
      include: { user: true, medicalCard: true, emergencyInfos: true, medicalBooklets: true },
    });
  }

  async findById(id: string) {
    return prisma.patient.findUnique({
      where: { id },
      include: { user: true, medicalCard: true, emergencyInfos: true, medicalBooklets: true },
    });
  }

  async create(data: {
    userId: string;
    firstName?: string;
    lastName?: string;
    dateOfBirth?: Date;
    gender?: string;
    bloodType?: string;
    allergies?: string[];
    chronicDiseases?: string[];
    currentMeds?: string[];
    emergencyContactName?: string;
    emergencyContactPhone?: string;
    address?: string;
    city?: string;
    region?: string;
    nin?: string;
    isOnboarded?: boolean;
    onboardingStep?: number;
  }) {
    const input = { ...data, nin: data.nin ?? this.generateTempNin() };
    return prisma.patient.create({ data: input });
  }

  private readonly allowedUpdateFields = [
    'nin', 'firstName', 'lastName', 'dateOfBirth', 'gender', 'bloodType', 'heightCm', 'weightKg',
    'allergies', 'chronicDiseases', 'chronicConditions', 'currentMeds', 
    'emergencyContactName', 'emergencyContactPhone', 'emergencyContactRelationship',
    'address', 'city', 'region', 'profilePhotoUrl', 
    'insuranceProvider', 'insuranceNumber', 'healthScore', 'lastVisit',
    'isOnboarded', 'onboardingStep',
    'isVerified', 'verifiedBy', 'verifiedByName', 'verifiedAt',
  ];

  async update(patientId: string, data: Record<string, unknown>) {
    const filtered: Record<string, unknown> = {};
    for (const key of this.allowedUpdateFields) {
      if (key in data) filtered[key] = data[key];
    }
    return prisma.patient.update({
      where: { id: patientId },
      data: { ...filtered, version: { increment: 1 } },
    });
  }

  async getMedicalCard(patientId: string) {
    return prisma.medicalCard.findUnique({ where: { patientId } });
  }

  async createMedicalCard(patientId: string, cardNumber: string) {
    return prisma.medicalCard.create({
      data: { patientId, cardNumber, deletedAt: null },
    });
  }

  async getEmergencyInfos(patientId: string) {
    return prisma.emergencyInfo.findMany({ where: { patientId, deletedAt: null } });
  }

  async createEmergencyInfo(data: {
    patientId: string;
    fullName: string;
    phone: string;
    relationship: string;
    isPrimary?: boolean;
  }) {
    if (data.isPrimary) {
      await prisma.emergencyInfo.updateMany({
        where: { patientId: data.patientId, isPrimary: true },
        data: { isPrimary: false },
      });
    }
    return prisma.emergencyInfo.create({ data });
  }

  private readonly allowedEmergencyUpdateFields = ['fullName', 'phone', 'relationship', 'isPrimary'];

  async updateEmergencyInfo(id: string, data: Record<string, unknown>) {
    const filtered: Record<string, unknown> = {};
    for (const key of this.allowedEmergencyUpdateFields) {
      if (key in data) filtered[key] = data[key];
    }
    return prisma.emergencyInfo.update({ where: { id }, data: filtered });
  }

  async deleteEmergencyInfo(id: string) {
    return prisma.emergencyInfo.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }

  async getMedicalBooklets(patientId: string) {
    return prisma.medicalBooklet.findMany({
      where: { patientId, deletedAt: null },
      orderBy: { recordDate: 'desc' },
    });
  }

  async createMedicalBooklet(data: {
    patientId: string;
    title: string;
    description?: string;
    fileUrl?: string;
    bookletType: string;
    hospitalName?: string;
    doctorName?: string;
    recordDate?: Date;
  }) {
    return prisma.medicalBooklet.create({ data });
  }

  async deleteMedicalBooklet(id: string) {
    return prisma.medicalBooklet.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }

  async getJourney(patientId: string) {
    return prisma.journeyEntry.findMany({
      where: { patientId, deletedAt: null },
      orderBy: { entryDate: 'desc' },
    });
  }

  async createJourneyEntry(data: {
    patientId: string;
    title: string;
    description?: string;
    entryType: string;
    referenceId?: string;
    hospitalName?: string;
    doctorName?: string;
  }) {
    return prisma.journeyEntry.create({ data });
  }

  async getAppointments(patientId: string) {
    return prisma.appointment.findMany({
      where: { patientId, deletedAt: null },
      include: { doctor: true, institution: true },
      orderBy: { appointmentDate: 'desc' },
    });
  }

  async getMedicalRecords(patientId: string) {
    const [consultations, labResults, imagingResults, prescriptions] = await Promise.all([
      prisma.consultation.findMany({
        where: { patientId, deletedAt: null },
        include: { doctor: true, prescriptions: true },
        orderBy: { consultationDate: 'desc' },
      }),
      prisma.labResult.findMany({ where: { patientId, deletedAt: null }, orderBy: { orderedDate: 'desc' } }),
      prisma.imagingResult.findMany({ where: { patientId, deletedAt: null }, orderBy: { orderedDate: 'desc' } }),
      prisma.prescription.findMany({ where: { patientId, deletedAt: null }, orderBy: { prescribedDate: 'desc' } }),
    ]);
    return { consultations, labResults, imagingResults, prescriptions };
  }
}
