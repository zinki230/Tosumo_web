import { Router } from 'express';
import { AuditController } from './audit.controller';
import { authenticate } from '@shared/middleware/auth';

const router = Router();
const controller = new AuditController();

router.get('/', authenticate, controller.getLogs);

export default router;
