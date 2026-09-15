import { Response, NextFunction } from 'express';
import { PaymentService } from './payment.service';
import { AuthenticatedRequest } from '@shared/types';

const paymentService = new PaymentService();

export class PaymentController {
  async initiatePayment(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const transaction = await paymentService.initiatePayment(req.user!.userId, req.body);
      res.json({ success: true, data: transaction });
    } catch (error) { next(error); }
  }

  async getTransactions(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const transactions = await paymentService.getTransactions(req.user!.userId);
      res.json({ success: true, data: transactions });
    } catch (error) { next(error); }
  }

  async getTransaction(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const transaction = await paymentService.getTransaction(req.params.id as string);
      res.json({ success: true, data: transaction });
    } catch (error) { next(error); }
  }

  async refund(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const transaction = await paymentService.refundTransaction(req.user!.userId, req.user!.role, req.params.id as string);
      res.json({ success: true, data: transaction });
    } catch (error) { next(error); }
  }
}
