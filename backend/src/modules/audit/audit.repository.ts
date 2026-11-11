import prisma from '@shared/database/prisma';

export class AuditRepository {
  async findByUserId(userId: string) {
    return prisma.auditLog.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async findAll(filters: {
    action?: string;
    entity?: string;
    userId?: string;
    search?: string;
    from?: Date;
    to?: Date;
    page: number;
    limit: number;
  }) {
    const where = {
      ...(filters.action ? { action: filters.action } : {}),
      ...(filters.entity ? { entity: filters.entity } : {}),
      ...(filters.userId ? { userId: filters.userId } : {}),
      ...(filters.from || filters.to
        ? { createdAt: { ...(filters.from ? { gte: filters.from } : {}), ...(filters.to ? { lte: filters.to } : {}) } }
        : {}),
      ...(filters.search
        ? {
            OR: [
              { action: { contains: filters.search, mode: 'insensitive' as const } },
              { entity: { contains: filters.search, mode: 'insensitive' as const } },
              { description: { contains: filters.search, mode: 'insensitive' as const } },
              { entityId: { contains: filters.search, mode: 'insensitive' as const } },
              { user: { email: { contains: filters.search, mode: 'insensitive' as const } } },
            ],
          }
        : {}),
    };
    const [logs, total] = await prisma.$transaction([
      prisma.auditLog.findMany({
        where,
        include: { user: { select: { email: true, role: true } } },
        orderBy: { createdAt: 'desc' },
        skip: (filters.page - 1) * filters.limit,
        take: filters.limit,
      }),
      prisma.auditLog.count({ where }),
    ]);
    return {
      logs,
      pagination: {
        page: filters.page,
        limit: filters.limit,
        total,
        totalPages: Math.ceil(total / filters.limit),
      },
    };
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
