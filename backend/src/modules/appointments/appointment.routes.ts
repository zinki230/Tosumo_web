import { Router } from 'express';
import { AppointmentController } from './appointment.controller';
import { authenticate, authorize } from '@shared/middleware/auth';
import { UserRole, AuthenticatedRequest } from '@shared/types';
import { Response, NextFunction } from 'express';
import prisma from '@shared/database/prisma';
import { validate } from '@shared/middleware/validate';
import {
  bookAppointmentSchema,
  cancelAppointmentSchema,
  rescheduleAppointmentSchema,
} from './appointment.validation';

const router = Router();
const controller = new AppointmentController();

router.post('/', authenticate, validate(bookAppointmentSchema), controller.book);
router.get('/', authenticate, authorize(UserRole.ADMIN, UserRole.SUPERADMIN, UserRole.INSTITUTION_ADMIN), async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const limit = Math.min(Number(req.query.limit ?? 200), 500);
    const { doctorId, patientId, status, startDate, endDate } = req.query;
    const where: Record<string, unknown> = { deletedAt: null };

    // Filter by institution for institution_admin
    if (req.user!.role === 'institution_admin' && req.user!.institutionId) {
      where.institutionId = req.user!.institutionId;
    }

    if (doctorId) where.doctorId = String(doctorId);
    if (patientId) where.patientId = String(patientId);
    if (status) where.status = String(status);
    if (startDate || endDate) {
      where.appointmentDate = {
        ...(startDate ? { gte: new Date(String(startDate)) } : {}),
        ...(endDate ? { lte: new Date(String(endDate)) } : {}),
      };
    }

    const appointments = await prisma.appointment.findMany({
      where,
      include: {
        patient: { include: { user: { select: { email: true, phone: true } } } },
        doctor: { include: { user: { select: { email: true, phone: true } } } },
        institution: true,
      },
      orderBy: { appointmentDate: 'desc' },
      take: limit,
    });

    res.json({ success: true, data: appointments });
  } catch (error) {
    next(error);
  }
});
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
