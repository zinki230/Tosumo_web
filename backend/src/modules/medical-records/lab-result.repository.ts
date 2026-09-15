import prisma from '@shared/database/prisma';

export class LabResultRepository {
  async findById(id: string) {
    return prisma.labResult.findUnique({ where: { id }, include: { doctor: true, patient: true } });
  }

  async findByPatientId(patientId: string) {
    return prisma.labResult.findMany({
      where: { patientId, deletedAt: null },
      include: { doctor: true },
      orderBy: { orderedDate: 'desc' },
    });
  }

  async findByDoctorId(doctorId: string) {
    return prisma.labResult.findMany({
      where: { doctorId, deletedAt: null },
      include: { patient: { include: { user: true } } },
      orderBy: { orderedDate: 'desc' },
    });
  }

  async create(data: {
    patientId: string;
    doctorId: string;
    testName: string;
    testCategory: string;
    resultData?: Record<string, unknown>;
    resultFileUrl?: string;
    laboratoryName?: string;
    notes?: string;
    signature?: Record<string, unknown>;
    signedAt?: Date;
  }) {
    return prisma.labResult.create({ data: { ...data, status: 'ordered', resultData: data.resultData as any, signature: data.signature as any } });
  }

  private readonly allowedUpdateFields = [
    'testName', 'resultData', 'resultFileUrl', 'laboratoryName', 'status',
    'resultDate', 'notes', 'isAbnormal',
  ];

  async update(id: string, data: Record<string, unknown>) {
    const filtered: Record<string, unknown> = {};
    for (const key of this.allowedUpdateFields) {
      if (key in data) filtered[key] = data[key];
    }
    return prisma.labResult.update({ where: { id }, data: { ...filtered, version: { increment: 1 } } });
  }
}
