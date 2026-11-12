import { ChatRepository } from './chat.repository';
import { emitToChat } from '@shared/socket';
import { BadRequestError, ForbiddenError, NotFoundError } from '@shared/utils/errors';
import prisma from '@shared/database/prisma';
import { NotificationService } from '@modules/notifications/notification.service';

export class ChatService {
  private repository = new ChatRepository();

  private async assertParticipant(userId: string, chatId: string) {
    const [doctor, patient, chat] = await Promise.all([
      prisma.doctor.findUnique({ where: { userId } }),
      prisma.patient.findUnique({ where: { userId } }),
      prisma.chat.findUnique({ where: { id: chatId }, include: { participants: true } }),
    ]);
    if (!chat || !chat.participants.some(p => (doctor && p.doctorId === doctor.id) || (patient && p.patientId === patient.id))) {
      throw new NotFoundError('Chat not found');
    }
    return { doctor, patient, chat };
  }

  async getChats(userId: string) {
    return this.repository.findChatsByUserId(userId);
  }

  async getChatById(userId: string, chatId: string) {
    const { doctor, patient } = await this.assertParticipant(userId, chatId);
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
    await this.assertParticipant(userId, chatId);
    return this.repository.getMessages(chatId, Math.min(100, Math.max(1, limit ?? 50)), before);
  }

  async sendMessage(userId: string, userRole: string, chatId: string, data: {
    content?: string;
    messageType?: string;
    fileUrl?: string;
    fileName?: string;
    fileSize?: number;
    mimeType?: string;
    replyToId?: string;
  }) {
    const { doctor, patient, chat } = await this.assertParticipant(userId, chatId);
    if ((userRole === 'doctor' && !doctor) || (userRole === 'patient' && !patient) || !['doctor', 'patient'].includes(userRole)) {
      throw new ForbiddenError('Only chat participants can send messages');
    }
    const content = data.content?.trim() ?? '';
    const fileUrl = data.fileUrl?.trim();
    if (!content && !fileUrl) throw new BadRequestError('Message text or an attachment is required');
    if (content.length > 5000) throw new BadRequestError('Message is too long');
    if (fileUrl && !/^\/uploads\/[a-zA-Z0-9._-]+$/.test(fileUrl)) throw new BadRequestError('Invalid attachment URL');
    const messageType = fileUrl
      ? (data.mimeType?.startsWith('image/') ? 'image' : 'document')
      : 'text';

    const message = await this.repository.createMessage({
      chatId,
      senderId: userId,
      senderRole: userRole,
      content,
      fileUrl,
      fileName: data.fileName?.slice(0, 255),
      fileSize: data.fileSize,
      mimeType: data.mimeType,
      messageType,
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
          body: content
            ? (content.length > 80 ? `${content.slice(0, 80)}…` : content)
            : `Pièce jointe : ${data.fileName || 'fichier'}`,
          type: 'message',
          data: { chatId, messageId: message.id },
          actionUrl: '/chat',
        }).catch(() => undefined);
      } catch { /* notification failure should not break messaging */ }
    }

    return fullMessage;
  }

  async markAsRead(userId: string, chatId: string) {
    await this.assertParticipant(userId, chatId);
    await this.repository.markAsRead(chatId, userId);
    emitToChat(chatId, 'chat:read', { chatId, userId });
  }

  async getUnreadCount(userId: string) {
    return this.repository.getUnreadCount(userId);
  }
}
