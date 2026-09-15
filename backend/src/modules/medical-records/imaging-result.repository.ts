import prisma from '@shared/database/prisma';

export class ImagingResultRepository {
  async findById(id: string) {
    return prisma.imagingResult.findUnique({ where: { id }, include: { doctor: true, patient: true } });
  }

  async findByPatientId(patientId: string) {
    return prisma.imagingResult.findMany({
      where: { patientId, deletedAt: null },
      include: { doctor: true },
      orderBy: { orderedDate: 'desc' },
    });
  }

  async findByDoctorId(doctorId: string) {
    return prisma.imagingResult.findMany({
      where: { doctorId, deletedAt: null },
      include: { patient: { include: { user: true } } },
      orderBy: { orderedDate: 'desc' },
    });
  }

  async create(data: {
    patientId: string;
    doctorId: string;
    imagingType: string;
    bodyPart?: string;
    reportText?: string;
    reportFileUrl?: string;
    facilityName?: string;
    notes?: string;
    signature?: Record<string, unknown>;
    signedAt?: Date;
  }) {
    return prisma.imagingResult.create({ data: { ...data, status: 'ordered', signature: data.signature as any } });
  }

  private readonly allowedUpdateFields = [
    'imagingType', 'bodyPart', 'imageUrls', 'reportText', 'reportFileUrl',
    'facilityName', 'status', 'resultDate', 'notes',
  ];

  async update(id: string, data: Record<string, unknown>) {
    const filtered: Record<string, unknown> = {};
    for (const key of this.allowedUpdateFields) {
      if (key in data) filtered[key] = data[key];
    }
    return prisma.imagingResult.update({ where: { id }, data: { ...filtered, version: { increment: 1 } } });
  }
}
