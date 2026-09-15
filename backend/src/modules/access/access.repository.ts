import prisma from '@shared/database/prisma';

export class AccessRepository {
  async findByPatientId(patientId: string) {
    return prisma.accessManagement.findMany({
      where: { patientId, deletedAt: null },
      include: { grantedTo: true, grantedBy: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findByGrantedToId(grantedToId: string) {
    return prisma.accessManagement.findMany({
      where: { grantedToId, deletedAt: null },
      include: { patient: { include: { user: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  async create(data: {
    patientId: string;
    grantedToId: string;
    grantedById?: string | null;
    accessLevel: string;
    accessType: string;
    startDate?: Date;
    endDate?: Date;
    reason?: string;
    isEmergency?: boolean;
    isApproved?: boolean;
    isActive?: boolean;
    deletedAt?: Date | null;
  }) {
    return prisma.accessManagement.create({ data });
  }

  async update(id: string, data: Record<string, unknown>) {
    return prisma.accessManagement.update({ where: { id }, data });
  }

  async revoke(id: string, revokedById: string, revokeReason?: string) {
    return prisma.accessManagement.update({
      where: { id },
      data: { isActive: false, revokedAt: new Date(), revokedById, revokeReason },
    });
  }

  async findActiveByDoctor(patientId: string, doctorUserId: string) {
    return prisma.accessManagement.findFirst({
      where: {
        patientId,
        grantedToId: doctorUserId,
        isActive: true,
        deletedAt: null,
        OR: [
          { endDate: null },
          { endDate: { gte: new Date() } },
        ],
      },
    });
  }
}
