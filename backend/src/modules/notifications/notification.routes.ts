import { Router } from 'express';
import { NotificationController } from './notification.controller';
import { authenticate } from '@shared/middleware/auth';

const router = Router();
const controller = new NotificationController();

router.get('/', authenticate, controller.getNotifications);
router.get('/unread', authenticate, controller.getUnread);
router.get('/unread/count', authenticate, controller.getUnreadCount);
router.put('/:id/read', authenticate, controller.markAsRead);
router.put('/read-all', authenticate, controller.markAllAsRead);
router.delete('/:id', authenticate, controller.delete);

export default router;
