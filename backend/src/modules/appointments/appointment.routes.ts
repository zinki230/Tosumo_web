import { Router } from 'express';
import { AppointmentController } from './appointment.controller';
import { authenticate } from '@shared/middleware/auth';
import { validate } from '@shared/middleware/validate';
import {
  bookAppointmentSchema,
  cancelAppointmentSchema,
  rescheduleAppointmentSchema,
} from './appointment.validation';

const router = Router();
const controller = new AppointmentController();

router.post('/', authenticate, validate(bookAppointmentSchema), controller.book);
router.get('/upcoming', authenticate, controller.getUpcoming);
router.get('/available-slots', authenticate, controller.getAvailableSlots);
router.get('/:id', authenticate, controller.getById);
router.put('/:id/approve', authenticate, controller.approve);
router.put('/:id/confirm', authenticate, controller.confirm);
router.put('/:id/cancel', authenticate, validate(cancelAppointmentSchema), controller.cancel);
router.put('/:id/reschedule', authenticate, validate(rescheduleAppointmentSchema), controller.reschedule);
router.put('/:id/complete', authenticate, controller.complete);
router.put('/:id/no-show', authenticate, controller.markNoShow);

export default router;
