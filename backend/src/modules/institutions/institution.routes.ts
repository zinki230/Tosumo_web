import { Router } from 'express';
import { InstitutionController } from './institution.controller';
import { authenticate, authorize } from '@shared/middleware/auth';
import { UserRole } from '@shared/types';

const router = Router();
const controller = new InstitutionController();

// Public route for registration form
router.get('/', controller.getAll);
router.get('/:id', authenticate, controller.getById);
router.post('/', authenticate, authorize(UserRole.DOCTOR, UserRole.ADMIN, UserRole.SUPERADMIN), controller.create);

export default router;
