import prisma from '@shared/database/prisma';

export class ConsultationRepository {
  async findById(id: string) {
    return prisma.consultation.findUnique({ where: { id }, include: { doctor: true, patient: true, prescriptions: true } });
  }

  async findByPatientId(patientId: string) {
    return prisma.consultation.findMany({
      where: { patientId, deletedAt: null },
      include: { doctor: true, prescriptions: true },
      orderBy: { consultationDate: 'desc' },
    });
  }

  async findByDoctorId(doctorId: string) {
    return prisma.consultation.findMany({
      where: { doctorId, deletedAt: null },
      include: { patient: { include: { user: true } }, prescriptions: true },
      orderBy: { consultationDate: 'desc' },
    });
  }

  async create(data: {
    patientId: string;
    doctorId: string;
    appointmentId?: string;
    chiefComplaint: string;
    historyOfPresentIllness?: string;
    diagnosis?: string;
    symptoms?: string[];
    vitalSigns?: Record<string, unknown>;
    assessment?: string;
    plan?: string;
    notes?: string;
    orderedExams?: unknown;
  }) {
    return prisma.consultation.create({ data: { ...data, vitalSigns: data.vitalSigns as any, orderedExams: data.orderedExams as any } });
  }

  private readonly allowedUpdateFields = [
    'diagnosis', 'symptoms', 'vitalSigns', 'assessment', 'plan', 'notes',
    'chiefComplaint', 'historyOfPresentIllness', 'orderedExams',
  ];

  async update(id: string, data: Record<string, unknown>) {
    const filtered: Record<string, unknown> = {};
    for (const key of this.allowedUpdateFields) {
      if (key in data) filtered[key] = data[key];
    }
    return prisma.consultation.update({ where: { id }, data: { ...filtered, version: { increment: 1 } } });
  }

  async delete(id: string) {
    return prisma.consultation.update({ where: { id }, data: { deletedAt: new Date() } });
  }
}
