import { NotificationRepository } from './notification.repository';
import { emitToUser } from '@shared/socket';
import { NotificationPayload } from '@shared/types';
import { NotFoundError } from '@shared/utils/errors';

export class NotificationService {
  private repository = new NotificationRepository();

  async getNotifications(userId: string) {
    return this.repository.findByUserId(userId);
  }

  async getUnreadNotifications(userId: string) {
    return this.repository.findUnreadByUserId(userId);
  }

  async getUnreadCount(userId: string) {
    return this.repository.getUnreadCount(userId);
  }

  async markAsRead(userId: string, notificationId: string) {
    const notif = await this.repository.markAsRead(notificationId);
    emitToUser(userId, 'notification:updated', notif);
    return notif;
  }

  async markAllAsRead(userId: string) {
    await this.repository.markAllAsRead(userId);
    emitToUser(userId, 'notifications:all-read', { userId });
  }

  async deleteNotification(userId: string, notificationId: string) {
    await this.repository.delete(notificationId);
    emitToUser(userId, 'notification:deleted', { id: notificationId });
  }

  async sendNotification(payload: NotificationPayload) {
    const notification = await this.repository.create({
      userId: payload.userId,
      title: payload.title,
      body: payload.body,
      type: payload.type,
      data: payload.data,
      imageUrl: payload.imageUrl,
      actionUrl: payload.actionUrl,
    });

    emitToUser(payload.userId, 'notification:new', notification);
    return notification;
  }
}
