import { Router } from 'express';
import { PatientController } from './patient.controller';
import { authenticate, authorize } from '@shared/middleware/auth';
import { UserRole, AuthenticatedRequest } from '@shared/types';
import { Response, NextFunction } from 'express';
import prisma from '@shared/database/prisma';

const router = Router();
const controller = new PatientController();
router.get('/', authenticate, authorize(UserRole.ADMIN, UserRole.SUPERADMIN, UserRole.INSTITUTION_ADMIN), async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const limit = Math.min(Number(req.query.limit ?? 100), 500);
    const search = String(req.query.search ?? '').trim();
    const where: Record<string, unknown> = { deletedAt: null };

    if (req.query.verified !== undefined) {
      where.isVerified = req.query.verified === 'true';
    }

    // Filter by institution for institution_admin
    if (req.user!.role === 'institution_admin' && req.user!.institutionId) {
      // Only show patients who have appointments at this institution
      where.appointments = {
        some: {
          institutionId: req.user!.institutionId,
          deletedAt: null
        }
      };
    }

    if (search) {
      where.OR = [
        { firstName: { contains: search, mode: 'insensitive' } },
        { lastName: { contains: search, mode: 'insensitive' } },
        { nin: { contains: search, mode: 'insensitive' } },
        { user: { phone: { contains: search } } },
      ];
    }

    const patients = await prisma.patient.findMany({
      where,
      include: { 
        user: { 
          select: { email: true, phone: true } 
        } 
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

    res.json({ success: true, data: patients });
  } catch (error) {
    next(error);
  }
});
router.get('/profile', authenticate, controller.getProfile);
router.put('/profile', authenticate, controller.updateProfile);
router.post('/onboard', authenticate, controller.onboard);
router.get('/medical-card', authenticate, controller.getMedicalCard);
router.get('/emergency-contacts', authenticate, controller.getEmergencyContacts);
router.post('/emergency-contacts', authenticate, controller.addEmergencyContact);
router.put('/emergency-contacts/:contactId', authenticate, controller.updateEmergencyContact);
router.delete('/emergency-contacts/:contactId', authenticate, controller.deleteEmergencyContact);
router.get('/medical-booklets', authenticate, controller.getMedicalBooklets);
router.post('/medical-booklets', authenticate, controller.addMedicalBooklet);
router.delete('/medical-booklets/:bookletId', authenticate, controller.deleteMedicalBooklet);
router.get('/journey', authenticate, controller.getJourney);
router.get('/appointments', authenticate, controller.getAppointments);
router.get('/medical-records', authenticate, controller.getMedicalRecords);
router.get('/:id', authenticate, controller.getPatientByIdOrUserId);
router.put('/:id', authenticate, controller.updateByDoctor);
router.post('/', authenticate, controller.createPatient);

export default router;
