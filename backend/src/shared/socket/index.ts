import { Server as HttpServer } from 'http';
import { Server, Socket } from 'socket.io';
import jwt from 'jsonwebtoken';
import { config } from '@shared/config';
import { JwtPayload } from '@shared/types';
import prisma from '@shared/database/prisma';

let io: Server;

interface AuthenticatedSocket extends Socket {
  userId?: string;
  userRole?: string;
}

export function initializeSocket(httpServer: HttpServer): Server {
  io = new Server(httpServer, {
    path: config.socket.path,
    cors: {
      origin: config.cors.origins,
      credentials: true,
    },
    pingInterval: 10000,
    pingTimeout: 5000,
  });

  io.use((socket: AuthenticatedSocket, next) => {
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;
    if (!token) {
      return next(new Error('Authentication required'));
    }
    try {
      const decoded = jwt.verify(token as string, config.jwt.accessSecret) as JwtPayload;
      socket.userId = decoded.userId;
      socket.userRole = decoded.role;
      next();
    } catch {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', (socket: AuthenticatedSocket) => {
    const userId = socket.userId!;
    socket.join(`user:${userId}`);

    socket.on('join:chat', async (chatId: string) => {
      try {
        const doctor = await prisma.doctor.findUnique({ where: { userId } });
        const patient = await prisma.patient.findUnique({ where: { userId } });
        const chat = await prisma.chat.findUnique({
          where: { id: chatId },
          select: { participants: { select: { patientId: true, doctorId: true } } },
        });
        const isParticipant = chat?.participants.some(
          p => (doctor && p.doctorId === doctor.id) || (patient && p.patientId === patient.id)
        );
        if (isParticipant) {
          socket.join(`chat:${chatId}`);
        }
      } catch {
        // Ignore invalid chat join attempts
      }
    });

    socket.on('leave:chat', (chatId: string) => {
      socket.leave(`chat:${chatId}`);
    });

    socket.on('typing:start', (data: { chatId: string }) => {
      socket.to(`chat:${data.chatId}`).emit('typing:start', { userId, chatId: data.chatId });
    });

    socket.on('typing:stop', (data: { chatId: string }) => {
      socket.to(`chat:${data.chatId}`).emit('typing:stop', { userId, chatId: data.chatId });
    });

    socket.on('disconnect', () => {
      socket.leave(`user:${userId}`);
    });
  });

  return io;
}

export function getIO(): Server {
  if (!io) {
    throw new Error('Socket.IO not initialized');
  }
  return io;
}

export function emitToUser(userId: string, event: string, data: unknown): void {
  getIO().to(`user:${userId}`).emit(event, data);
}

export function emitToChat(chatId: string, event: string, data: unknown): void {
  getIO().to(`chat:${chatId}`).emit(event, data);
}

export function emitToAll(event: string, data: unknown): void {
  getIO().emit(event, data);
}
