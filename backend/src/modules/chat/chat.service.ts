import { ChatRepository } from './chat.repository';
import { emitToChat } from '@shared/socket';
import { BadRequestError, NotFoundError } from '@shared/utils/errors';
import prisma from '@shared/database/prisma';
import { NotificationService } from '@modules/notifications/notification.service';

export class ChatService {
  private repository = new ChatRepository();

  async getChats(userId: string) {
    return this.repository.findChatsByUserId(userId);
  }

  async getChatById(userId: string, chatId: string) {
    const doctor = await prisma.doctor.findUnique({ where: { userId } });
    const patient = await prisma.patient.findUnique({ where: { userId } });
    const chat = await prisma.chat.findUnique({
      where: { id: chatId },
      include: {
        participants: {
          include: {
            doctor: { include: { user: true } },
            patient: { include: { user: true } },
          },
        },
        messages: { orderBy: { createdAt: 'desc' }, take: 50 },
      },
    });
    if (!chat) throw new NotFoundError('Chat not found');
    const isParticipant = chat.participants.some(
      p => (patient && p.patientId === patient.id) || (doctor && p.doctorId === doctor.id)
    );
    if (!isParticipant) throw new NotFoundError('Chat not found');
    return chat;
  }

  async getOrCreateChat(userId: string, doctorId: string) {
    const patient = await prisma.patient.findUnique({ where: { userId } });
    if (!patient) throw new NotFoundError('Patient profile not found');

    const doctor = await prisma.doctor.findUnique({ where: { id: doctorId } });
    if (!doctor) throw new NotFoundError('Doctor not found');

    return this.repository.findOrCreateDirectChat(patient.id, doctor.id);
  }

  async getMessages(userId: string, chatId: string, limit?: number, before?: string) {
    const doctor = await prisma.doctor.findUnique({ where: { userId } });
    const patient = await prisma.patient.findUnique({ where: { userId } });
    const chat = await prisma.chat.findUnique({ where: { id: chatId }, include: { participants: true } });
    if (!chat) throw new NotFoundError('Chat not found');
    const isParticipant = chat.participants.some(
      p => (patient && p.patientId === patient.id) || (doctor && p.doctorId === doctor.id)
    );
    if (!isParticipant) throw new NotFoundError('Chat not found');
    return this.repository.getMessages(chatId, limit, before);
  }

  async sendMessage(userId: string, userRole: string, chatId: string, data: {
    content?: string;
    messageType?: string;
    fileUrl?: string;
    fileSize?: number;
    mimeType?: string;
    replyToId?: string;
  }) {
    const chat = await prisma.chat.findUnique({ where: { id: chatId }, include: { participants: true } });
    if (!chat) throw new NotFoundError('Chat not found');

    const message = await this.repository.createMessage({
      chatId,
      senderId: userId,
      senderRole: userRole,
      ...data,
      messageType: data.messageType || 'text',
    });

    await prisma.chat.update({ where: { id: chatId }, data: { updatedAt: new Date() } });

    const fullMessage = await prisma.chatMessage.findUnique({
      where: { id: message.id },
      include: { sender: true },
    });

    emitToChat(chatId, 'message:new', fullMessage);

    // Notify the other participant (doctor or patient) about the new message.
    let otherUserId: string | null = null;
    for (const p of chat.participants) {
      if (userRole === 'doctor') {
        if (p.patientId) {
          const otherPatient = await prisma.patient.findUnique({ where: { id: p.patientId } });
          if (otherPatient) otherUserId = otherPatient.userId;
        }
      } else if (p.doctorId) {
        const otherDoctor = await prisma.doctor.findUnique({ where: { id: p.doctorId } });
        if (otherDoctor) otherUserId = otherDoctor.userId;
      }
      if (otherUserId) break;
    }
    if (otherUserId) {
      try {
        const notif = await new NotificationService().sendNotification({
          userId: otherUserId,
          title: userRole === 'doctor' ? 'Réponse du médecin' : 'Nouveau message',
          body: data.content?.length
            ? (data.content.length > 80 ? `${data.content.slice(0, 80)}…` : data.content)
            : 'Vous avez reçu un nouveau message.',
          type: 'message',
          data: { chatId, messageId: message.id },
          actionUrl: '/chat',
        }).catch(() => undefined);
      } catch { /* notification failure should not break messaging */ }
    }

    return fullMessage;
  }

  async markAsRead(userId: string, chatId: string) {
    await this.repository.markAsRead(chatId, userId);
    emitToChat(chatId, 'chat:read', { chatId, userId });
  }

  async getUnreadCount(userId: string) {
    return this.repository.getUnreadCount(userId);
  }
}
