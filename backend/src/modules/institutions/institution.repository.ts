import prisma from '@shared/database/prisma';

export class InstitutionRepository {
  async findAll(filters?: { type?: string; city?: string; region?: string }) {
    const where: Record<string, unknown> = { deletedAt: null, isVerified: true };
    if (filters?.type) where.type = filters.type;
    if (filters?.city) where.city = { contains: filters.city, mode: 'insensitive' };
    if (filters?.region) where.region = { contains: filters.region, mode: 'insensitive' };
    return prisma.institution.findMany({ where, orderBy: { name: 'asc' } });
  }

  async findById(id: string) {
    return prisma.institution.findUnique({
      where: { id },
      include: {
        doctors: {
          include: { doctor: { include: { user: true } } },
        },
      },
    });
  }

  async create(data: {
    name: string;
    type: string;
    phone?: string;
    email?: string;
    address?: string;
    city?: string;
    region?: string;
    latitude?: number;
    longitude?: number;
    logoUrl?: string;
  }) {
    return prisma.institution.create({ data });
  }

  async update(id: string, data: Record<string, unknown>) {
    return prisma.institution.update({ where: { id }, data });
  }
}
