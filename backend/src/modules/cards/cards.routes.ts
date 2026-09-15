import { Router } from 'express';
import { CardsController } from './cards.controller';
import { authenticate } from '@shared/middleware/auth';

const router = Router();
const controller = new CardsController();

router.post('/reissue', authenticate, controller.reissue);

export default router;
