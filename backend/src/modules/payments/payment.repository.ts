import prisma from '@shared/database/prisma';

export class PaymentRepository {
  async findById(id: string) {
    return prisma.paymentTransaction.findUnique({ where: { id } });
  }

  async findByUserId(userId: string) {
    return prisma.paymentTransaction.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async create(data: {
    userId: string;
    appointmentId?: string;
    amount: number;
    currency?: string;
    provider: string;
    phoneNumber?: string;
  }) {
    return prisma.paymentTransaction.create({
      data: { ...data, status: 'pending' },
    });
  }

  async updateStatus(id: string, status: string, providerReference?: string, failureReason?: string) {
    return prisma.paymentTransaction.update({
      where: { id },
      data: { status, providerReference, failureReason },
    });
  }

  async refund(id: string, amount?: number) {
    return prisma.paymentTransaction.update({
      where: { id },
      data: { status: 'refunded', refundedAt: new Date(), refundAmount: amount },
    });
  }
}
