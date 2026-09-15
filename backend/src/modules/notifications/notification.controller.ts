import { Response, NextFunction } from 'express';
import { NotificationService } from './notification.service';
import { AuthenticatedRequest } from '@shared/types';

const notificationService = new NotificationService();

export class NotificationController {
  async getNotifications(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const notifications = await notificationService.getNotifications(req.user!.userId);
      res.json({ success: true, data: notifications });
    } catch (error) { next(error); }
  }

  async getUnread(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const notifications = await notificationService.getUnreadNotifications(req.user!.userId);
      res.json({ success: true, data: notifications });
    } catch (error) { next(error); }
  }

  async getUnreadCount(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      const count = await notificationService.getUnreadCount(req.user!.userId);
      res.json({ success: true, data: { count } });
    } catch (error) { next(error); }
  }

  async markAsRead(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      await notificationService.markAsRead(req.user!.userId, req.params.id as string);
      res.json({ success: true, message: 'Notification marked as read' });
    } catch (error) { next(error); }
  }

  async markAllAsRead(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      await notificationService.markAllAsRead(req.user!.userId);
      res.json({ success: true, message: 'All notifications marked as read' });
    } catch (error) { next(error); }
  }

  async delete(req: AuthenticatedRequest, res: Response, next: NextFunction) {
    try {
      await notificationService.deleteNotification(req.user!.userId, req.params.id as string);
      res.json({ success: true, message: 'Notification deleted' });
    } catch (error) { next(error); }
  }
}
