import prisma from '@shared/database/prisma';

export class AuthRepository {
  async findByEmail(email: string) {
    return prisma.user.findUnique({
      where: { email },
      include: { 
        patientProfile: { select: { id: true, isOnboarded: true } },
        doctorProfile: { 
          select: { 
            id: true,
            institutions: {
              where: { isPrimary: true },
              select: { institutionId: true },
              take: 1
            }
          } 
        },
        createdInstitutions: {
          select: { id: true },
          take: 1
        }
      },
    });
  }

  async findByPhone(phone: string) {
    return prisma.user.findUnique({
      where: { phone },
      include: { 
        patientProfile: { select: { id: true, isOnboarded: true } },
        doctorProfile: { 
          select: { 
            id: true,
            institutions: {
              where: { isPrimary: true },
              select: { institutionId: true },
              take: 1
            }
          } 
        },
        createdInstitutions: {
          select: { id: true },
          take: 1
        }
      },
    });
  }

  async findById(id: string) {
    return prisma.user.findUnique({
      where: { id },
      include: { 
        patientProfile: { select: { id: true, isOnboarded: true } },
        doctorProfile: { 
          select: { 
            id: true,
            institutions: {
              where: { isPrimary: true },
              select: { institutionId: true },
              take: 1
            }
          } 
        },
        createdInstitutions: {
          select: { id: true },
          take: 1
        }
      },
    });
  }

  async create(data: {
    email: string;
    phone: string;
    passwordHash: string;
    role: string;
  }) {
    return prisma.user.create({ data });
  }

  async updateRefreshToken(userId: string, refreshToken: string | null) {
    return prisma.user.update({
      where: { id: userId },
      data: { refreshToken },
    });
  }

  async updateLastLogin(userId: string) {
    return prisma.user.update({
      where: { id: userId },
      data: { lastLoginAt: new Date() },
    });
  }

  async setEmailVerified(userId: string) {
    return prisma.user.update({
      where: { id: userId },
      data: { isEmailVerified: true },
    });
  }

  async setPhoneVerified(userId: string) {
    return prisma.user.update({
      where: { id: userId },
      data: { isPhoneVerified: true },
    });
  }

  async updatePassword(userId: string, passwordHash: string) {
    return prisma.user.update({
      where: { id: userId },
      data: { passwordHash },
    });
  }

  async updateFcmToken(userId: string, fcmToken: string) {
    return prisma.user.update({
      where: { id: userId },
      data: { fcmToken },
    });
  }
}
