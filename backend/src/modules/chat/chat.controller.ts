import { Response, NextFunction } from 'express';
import { ChatService } from './chat.service';
import { AuthenticatedRequest } from '@shared/types';

const chatService = new ChatService();

export class ChatController {
  async getChats(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const chats = await chatService.getChats(req.user!.userId);
      res.json({ success: true, data: chats });
    } catch (error) { next(error); }
  }

  async getChatById(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const chat = await chatService.getChatById(req.user!.userId, req.params.chatId as string);
      res.json({ success: true, data: chat });
    } catch (error) { next(error); }
  }

  async getOrCreateChat(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const chat = await chatService.getOrCreateChat(req.user!.userId, req.params.doctorId as string);
      res.json({ success: true, data: chat });
    } catch (error) { next(error); }
  }

  async getMessages(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const { chatId } = req.params;
      const limit = req.query.limit ? parseInt(req.query.limit as string) : 50;
      const before = req.query.before as string;
      const messages = await chatService.getMessages(req.user!.userId, chatId as string, limit, before);
      res.json({ success: true, data: messages });
    } catch (error) { next(error); }
  }

  async sendMessage(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const message = await chatService.sendMessage(req.user!.userId, req.user!.role, req.params.chatId as string, req.body);
      res.status(201).json({ success: true, data: message });
    } catch (error) { next(error); }
  }

  async markAsRead(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      await chatService.markAsRead(req.user!.userId, req.params.chatId as string);
      res.json({ success: true, message: 'Messages marked as read' });
    } catch (error) { next(error); }
  }

  async getUnreadCount(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const count = await chatService.getUnreadCount(req.user!.userId);
      res.json({ success: true, data: { count } });
    } catch (error) { next(error); }
  }
}
