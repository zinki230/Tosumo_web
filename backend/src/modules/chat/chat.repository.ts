import prisma from '@shared/database/prisma';

export class ChatRepository {
  async findChatsByUserId(userId: string) {
    const doctor = await prisma.doctor.findUnique({ where: { userId } });
    const patient = await prisma.patient.findUnique({ where: { userId } });

    const where: Record<string, unknown> = { deletedAt: null };
    if (doctor) {
      where.participants = { some: { doctorId: doctor.id } };
    }
    if (patient) {
      where.participants = { some: { patientId: patient.id } };
    }

    return prisma.chat.findMany({
      where,
      include: {
        participants: {
          include: {
            doctor: { include: { user: true } },
            patient: { include: { user: true } },
          },
        },
        messages: { orderBy: { createdAt: 'desc' }, take: 1 },
      },
      orderBy: { updatedAt: 'desc' },
    });
  }

  async findOrCreateDirectChat(patientId: string, doctorId: string) {
    const existing = await prisma.chat.findFirst({
      where: {
        isGroup: false,
        participants: {
          some: { patientId },
        },
        AND: {
          participants: {
            some: { doctorId },
          },
        },
      },
      include: { participants: true },
    });
    if (existing) return existing;

    return prisma.chat.create({
      data: {
        participants: {
          create: [
            { patientId },
            { doctorId },
          ],
        },
      },
      include: { participants: true },
    });
  }

  async getMessages(chatId: string, limit = 50, before?: string) {
    const where: Record<string, unknown> = { chatId, deletedAt: null };
    if (before) {
      where.createdAt = { lt: new Date(before) };
    }
    return prisma.chatMessage.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  async createMessage(data: {
    chatId: string;
    senderId: string;
    senderRole: string;
    content?: string;
    messageType: string;
    fileUrl?: string;
    fileSize?: number;
    mimeType?: string;
    replyToId?: string;
  }) {
    return prisma.chatMessage.create({ data });
  }

  async markAsRead(chatId: string, userId: string) {
    const doctor = await prisma.doctor.findUnique({ where: { userId } });
    const patient = await prisma.patient.findUnique({ where: { userId } });

    if (doctor) {
      await prisma.chatParticipant.updateMany({
        where: { chatId, doctorId: doctor.id },
        data: { lastReadAt: new Date() },
      });
    }
    if (patient) {
      await prisma.chatParticipant.updateMany({
        where: { chatId, patientId: patient.id },
        data: { lastReadAt: new Date() },
      });
    }

    return prisma.chatMessage.updateMany({
      where: { chatId, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });
  }

  async getUnreadCount(userId: string) {
    const doctor = await prisma.doctor.findUnique({ where: { userId } });
    const patient = await prisma.patient.findUnique({ where: { userId } });

    const where: Record<string, unknown> = { deletedAt: null };
    if (doctor) {
      where.participants = { some: { doctorId: doctor.id, lastReadAt: null } };
    }
    if (patient) {
      where.participants = { some: { patientId: patient.id, lastReadAt: null } };
    }

    return prisma.chatMessage.count({ where });
  }
}
