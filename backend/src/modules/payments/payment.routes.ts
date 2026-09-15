import { Router } from 'express';
import { PaymentController } from './payment.controller';
import { authenticate } from '@shared/middleware/auth';

const router = Router();
const controller = new PaymentController();

router.post('/initiate', authenticate, controller.initiatePayment);
router.get('/', authenticate, controller.getTransactions);
router.get('/:id', authenticate, controller.getTransaction);
router.post('/:id/refund', authenticate, controller.refund);

export default router;
