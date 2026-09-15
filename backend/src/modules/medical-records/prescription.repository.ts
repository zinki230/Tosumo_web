import prisma from '@shared/database/prisma';

export class PrescriptionRepository {
  private readonly baseInclude = { doctor: true, patient: true, consultation: true } as const;

  async findById(id: string) {
    return prisma.prescription.findUnique({ where: { id }, include: this.baseInclude });
  }

  async findByPatientId(patientId: string) {
    return prisma.prescription.findMany({
      where: { patientId, deletedAt: null },
      include: { doctor: true, consultation: true },
      orderBy: { prescribedDate: 'desc' },
    });
  }

  async findByDoctorId(doctorId: string) {
    return prisma.prescription.findMany({
      where: { doctorId, deletedAt: null },
      include: { patient: { include: { user: true } }, consultation: true },
      orderBy: { prescribedDate: 'desc' },
    });
  }

  async create(data: {
    patientId: string;
    doctorId: string;
    consultationId?: string;
    medicationName: string;
    dosage: string;
    frequency: string;
    duration: string;
    route?: string;
    instructions?: string;
    refills?: number;
    pharmacyName?: string;
    signature?: Record<string, unknown>;
    signedAt?: Date;
  }) {
    return prisma.prescription.create({ data: { ...data, signature: data.signature as any }, include: this.baseInclude });
  }

  private readonly allowedUpdateFields = [
    'medicationName', 'dosage', 'frequency', 'duration', 'route', 'instructions',
    'refills', 'isActive', 'pharmacyName', 'consultationId',
  ];

  async update(id: string, data: Record<string, unknown>) {
    const filtered: Record<string, unknown> = {};
    for (const key of this.allowedUpdateFields) {
      if (key in data) filtered[key] = data[key];
    }
    return prisma.prescription.update({ where: { id }, data: { ...filtered, version: { increment: 1 } } });
  }

  async fulfill(id: string) {
    return prisma.prescription.update({
      where: { id },
      data: { isFulfilled: true, fulfilledAt: new Date() },
    });
  }

  // Patient marks the medication as done / finished taking it.
  async complete(id: string) {
    return prisma.prescription.update({
      where: { id },
      data: { isCompleted: true, completedAt: new Date() },
    });
  }

  async undoComplete(id: string) {
    return prisma.prescription.update({
      where: { id },
      data: { isCompleted: false, completedAt: null },
    });
  }
}
