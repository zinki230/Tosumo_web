import { Router } from 'express';
import { EmergencyController } from './emergency.controller';
import { authenticate } from '@shared/middleware/auth';

const router = Router();
const controller = new EmergencyController();

router.post('/sos', authenticate, controller.triggerSOS);

router.post('/sessions', authenticate, controller.startSession);
router.get('/sessions', authenticate, controller.getSessions);
router.get('/sessions/active', authenticate, controller.getActiveSession);
router.get('/sessions/:id', authenticate, controller.getSessionById);
router.patch('/sessions/:id', authenticate, controller.updateSession);

router.get('/critical-info', authenticate, controller.getCriticalInfo);
router.get('/critical-info/:patientId', authenticate, controller.getCriticalInfoForDoctor);
router.get('/nearby-hospitals', authenticate, controller.getNearbyHospitals);

export default router;