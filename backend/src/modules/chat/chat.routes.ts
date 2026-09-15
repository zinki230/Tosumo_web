import { Router } from 'express';
import { ChatController } from './chat.controller';
import { authenticate } from '@shared/middleware/auth';

const router = Router();
const controller = new ChatController();

router.get('/', authenticate, controller.getChats);
router.get('/unread', authenticate, controller.getUnreadCount);
router.get('/:chatId', authenticate, controller.getChatById);
router.post('/with/:doctorId', authenticate, controller.getOrCreateChat);
router.get('/:chatId/messages', authenticate, controller.getMessages);
router.post('/:chatId/messages', authenticate, controller.sendMessage);
router.put('/:chatId/read', authenticate, controller.markAsRead);

export default router;
