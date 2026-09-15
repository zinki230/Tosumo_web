import prisma from '@shared/database/prisma';

export class AuditRepository {
  async findByUserId(userId: string) {
    return prisma.auditLog.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async findAll(filters?: { action?: string; entity?: string; userId?: string }) {
    const where: Record<string, unknown> = {};
    if (filters?.action) where.action = filters.action;
    if (filters?.entity) where.entity = filters.entity;
    if (filters?.userId) where.userId = filters.userId;

    return prisma.auditLog.findMany({
      where,
      include: { user: { select: { email: true, role: true } } },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }

  async create(data: {
    userId: string;
    action: string;
    entity: string;
    entityId?: string;
    description: string;
    metadata?: Record<string, unknown>;
    ipAddress?: string;
    userAgent?: string;
  }) {
    return prisma.auditLog.create({ data: { ...data, metadata: data.metadata as any } });
  }
}
