import { PaymentRepository } from './payment.repository';
import { NotFoundError, BadRequestError, ForbiddenError } from '@shared/utils/errors';
import { emitToUser } from '@shared/socket';
import prisma from '@shared/database/prisma';

interface MockProviderResponse {
  success: boolean;
  reference: string;
  message: string;
}

async function mockPaymentProvider(amount: number, phone: string): Promise<MockProviderResponse> {
  await new Promise(resolve => setTimeout(resolve, 1000));
  const success = Math.random() > 0.1;
  return {
    success,
    reference: `MOCK-${Date.now()}-${Math.random().toString(36).substring(2, 8).toUpperCase()}`,
    message: success ? 'Payment successful' : 'Insufficient balance',
  };
}

async function mockCardProvider(amount: number, cardLastFour: string): Promise<MockProviderResponse> {
  await new Promise(resolve => setTimeout(resolve, 800));
  return {
    success: true,
    reference: `CARD-${Date.now()}-${Math.random().toString(36).substring(2, 8).toUpperCase()}`,
    message: 'Card payment successful',
  };
}

export class PaymentService {
  private repository = new PaymentRepository();

  async initiatePayment(userId: string, data: {
    appointmentId?: string;
    amount: number;
    provider: string;
    phoneNumber?: string;
    cardLastFour?: string;
  }) {
    const transaction = await this.repository.create({
      userId,
      appointmentId: data.appointmentId,
      amount: data.amount,
      provider: data.provider,
      phoneNumber: data.phoneNumber,
    });

    emitToUser(userId, 'payment:initiated', transaction);

    let result: MockProviderResponse;
    if (data.provider === 'card') {
      result = await mockCardProvider(data.amount, data.cardLastFour || '****');
    } else {
      result = await mockPaymentProvider(data.amount, data.phoneNumber || '');
    }

    if (result.success) {
      const updated = await this.repository.updateStatus(transaction.id, 'completed', result.reference);
      emitToUser(userId, 'payment:completed', updated);
      if (data.appointmentId) {
        await prisma.appointment.update({
          where: { id: data.appointmentId },
          data: { isPaid: true, paymentReference: result.reference, paymentMethod: data.provider },
        });
      }
      return updated;
    }

    const failed = await this.repository.updateStatus(transaction.id, 'failed', undefined, result.message);
    emitToUser(userId, 'payment:failed', failed);
    throw new BadRequestError(result.message);
  }

  async getTransactions(userId: string) {
    return this.repository.findByUserId(userId);
  }

  async getTransaction(transactionId: string) {
    const transaction = await this.repository.findById(transactionId);
    if (!transaction) throw new NotFoundError('Transaction not found');
    return transaction;
  }

  async refundTransaction(userId: string, role: string, transactionId: string) {
    const transaction = await this.repository.findById(transactionId);
    if (!transaction) throw new NotFoundError('Transaction not found');
    if (transaction.userId !== userId && role !== 'admin') throw new ForbiddenError('Not your transaction');
    if (transaction.status !== 'completed') throw new BadRequestError('Only completed transactions can be refunded');
    if (transaction.refundedAt) throw new BadRequestError('Transaction already refunded');
    return this.repository.refund(transactionId);
  }
}
