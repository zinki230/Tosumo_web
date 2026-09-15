import { Router } from 'express';
import { AccessController } from './access.controller';
import { authenticate } from '@shared/middleware/auth';

const router = Router();
const controller = new AccessController();

router.post('/grant', authenticate, controller.grantAccess);
router.post('/request', authenticate, controller.requestAccess);
router.put('/:id/approve', authenticate, controller.approveAccess);
router.put('/:id/revoke', authenticate, controller.revokeAccess);
router.get('/patient', authenticate, controller.getPatientAccesses);
router.get('/doctor', authenticate, controller.getDoctorAccesses);
router.get('/check/:patientUserId', authenticate, controller.checkAccess);

export default router;
