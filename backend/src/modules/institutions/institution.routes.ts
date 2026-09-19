import { Router } from 'express';
import { InstitutionController } from './institution.controller';
import { authenticate, authorize } from '@shared/middleware/auth';
import { validate } from '@shared/middleware/validate';
import { UserRole } from '@shared/types';
import { createDoctorSchema } from './institution.validation';

const router = Router();
const controller = new InstitutionController();

// Public route for registration form
router.get('/', controller.getAll);
router.get('/:id', authenticate, controller.getById);
router.post('/', authenticate, authorize(UserRole.DOCTOR, UserRole.ADMIN, UserRole.SUPERADMIN), controller.create);

// Institution admin routes
router.post('/doctors', authenticate, authorize(UserRole.INSTITUTION_ADMIN), validate(createDoctorSchema), controller.createDoctor);
router.get('/doctors/list', authenticate, authorize(UserRole.INSTITUTION_ADMIN), controller.getDoctors);

export default router;
