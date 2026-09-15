import prisma from '@shared/database/prisma';

export class NotificationRepository {
  async findByUserId(userId: string) {
    return prisma.notification.findMany({
      where: { userId, deletedAt: null },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findUnreadByUserId(userId: string) {
    return prisma.notification.findMany({
      where: { userId, isRead: false, deletedAt: null },
      orderBy: { createdAt: 'desc' },
    });
  }

  async create(data: {
    userId: string;
    title: string;
    body: string;
    type: string;
    data?: Record<string, unknown>;
    imageUrl?: string;
    actionUrl?: string;
  }) {
    return prisma.notification.create({ data: { ...data, data: data.data as any } });
  }

  async markAsRead(id: string) {
    return prisma.notification.update({
      where: { id },
      data: { isRead: true, readAt: new Date() },
    });
  }

  async markAllAsRead(userId: string) {
    return prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });
  }

  async delete(id: string) {
    return prisma.notification.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }

  async getUnreadCount(userId: string) {
    return prisma.notification.count({
      where: { userId, isRead: false, deletedAt: null },
    });
  }
}
