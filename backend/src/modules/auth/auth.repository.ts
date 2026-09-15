import prisma from '@shared/database/prisma';

export class AuthRepository {
  async findByEmail(email: string) {
    return prisma.user.findUnique({
      where: { email },
      include: { patientProfile: { select: { id: true, isOnboarded: true } } },
    });
  }

  async findByPhone(phone: string) {
    return prisma.user.findUnique({
      where: { phone },
      include: { patientProfile: { select: { id: true, isOnboarded: true } } },
    });
  }

  async findById(id: string) {
    return prisma.user.findUnique({
      where: { id },
      include: { patientProfile: { select: { id: true, isOnboarded: true } } },
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
