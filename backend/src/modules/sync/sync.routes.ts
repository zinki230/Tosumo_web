import { Router } from 'express';
import { authenticate } from '@shared/middleware/auth';
import { AuthenticatedRequest } from '@shared/types';
import { Response, NextFunction } from 'express';
import prisma from '@shared/database/prisma';

const router = Router();

router.post('/', authenticate, async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    const { lastSyncTimestamp, entityTypes } = req.body;
    const lastSync = lastSyncTimestamp ? new Date(lastSyncTimestamp) : new Date(0);
    const userId = req.user!.userId;

    const patient = await prisma.patient.findUnique({ where: { userId } });
    const doctor = await prisma.doctor.findUnique({ where: { userId } });

    if (!patient && !doctor) {
      res.json({ success: true, data: {}, syncTimestamp: new Date().toISOString() });
      return;
    }

    const result: Record<string, { created: unknown[]; updated: unknown[]; deleted: unknown[] }> = {};

    const filter = { createdAt: { gte: lastSync }, deletedAt: null };
    const updateFilter = { updatedAt: { gte: lastSync }, deletedAt: null };
    const deleteFilter = { deletedAt: { gte: lastSync } };

    const buildWhere = (patientField: string, doctorField: string) => {
      if (patient) return { [patientField]: patient.id };
      if (doctor) return { [doctorField]: doctor.id };
      return {};
    };

    for (const entityType of entityTypes || []) {
      let created: unknown[] = [];
      let updated: unknown[] = [];
      let deleted: unknown[] = [];

      switch (entityType) {
        case 'patient': {
          if (patient) {
            const p = await prisma.patient.findUnique({ where: { id: patient.id } });
            if (p) created = [p];
          }
          break;
        }
        case 'doctor': {
          if (doctor) {
            const d = await prisma.doctor.findUnique({ where: { id: doctor.id } });
            if (d) created = [d];
          }
          break;
        }
        case 'appointments': {
          const where = buildWhere('patientId', 'doctorId');
          created = await prisma.appointment.findMany({ where: { ...where, ...filter } });
          updated = await prisma.appointment.findMany({ where: { ...where, ...updateFilter } });
          deleted = await prisma.appointment.findMany({ where: { ...where, ...deleteFilter } });
          break;
        }
        case 'consultations': {
          const w = buildWhere('patientId', 'doctorId');
          created = await prisma.consultation.findMany({ where: { ...w, ...filter } });
          updated = await prisma.consultation.findMany({ where: { ...w, ...updateFilter } });
          deleted = await prisma.consultation.findMany({ where: { ...w, ...deleteFilter } });
          break;
        }
        case 'lab_results': {
          const w = buildWhere('patientId', 'doctorId');
          created = await prisma.labResult.findMany({ where: { ...w, ...filter } });
          updated = await prisma.labResult.findMany({ where: { ...w, ...updateFilter } });
          deleted = await prisma.labResult.findMany({ where: { ...w, ...deleteFilter } });
          break;
        }
        case 'imaging_results': {
          const w = buildWhere('patientId', 'doctorId');
          created = await prisma.imagingResult.findMany({ where: { ...w, ...filter } });
          updated = await prisma.imagingResult.findMany({ where: { ...w, ...updateFilter } });
          deleted = await prisma.imagingResult.findMany({ where: { ...w, ...deleteFilter } });
          break;
        }
        case 'prescriptions': {
          const w = buildWhere('patientId', 'doctorId');
          created = await prisma.prescription.findMany({ where: { ...w, ...filter } });
          updated = await prisma.prescription.findMany({ where: { ...w, ...updateFilter } });
          deleted = await prisma.prescription.findMany({ where: { ...w, ...deleteFilter } });
          break;
        }
        case 'notifications': {
          created = await prisma.notification.findMany({ where: { userId, ...filter } });
          updated = await prisma.notification.findMany({ where: { userId, ...updateFilter } });
          deleted = await prisma.notification.findMany({ where: { userId, ...deleteFilter } });
          break;
        }
        case 'chats': {
          if (patient || doctor) {
            const participantWhere = patient
              ? { participants: { some: { patientId: patient.id } } }
              : { participants: { some: { doctorId: doctor!.id } } };
            created = await prisma.chat.findMany({ where: { ...participantWhere, ...filter }, include: { participants: true, messages: { take: 1, orderBy: { createdAt: 'desc' } } } });
          }
          break;
        }
        case 'messages': {
          if (patient || doctor) {
            const chatsWhere = patient
              ? { participants: { some: { patientId: patient.id } } }
              : { participants: { some: { doctorId: doctor!.id } } };
            const chats = await prisma.chat.findMany({ where: chatsWhere, select: { id: true } });
            const chatIds = chats.map(c => c.id);
            created = await prisma.chatMessage.findMany({ where: { chatId: { in: chatIds }, ...filter } });
            updated = await prisma.chatMessage.findMany({ where: { chatId: { in: chatIds }, ...updateFilter } });
            deleted = await prisma.chatMessage.findMany({ where: { chatId: { in: chatIds }, ...deleteFilter } });
          }
          break;
        }
        case 'medical_booklets': {
          if (patient) {
            created = await prisma.medicalBooklet.findMany({ where: { patientId: patient.id, ...filter } });
            updated = await prisma.medicalBooklet.findMany({ where: { patientId: patient.id, ...updateFilter } });
            deleted = await prisma.medicalBooklet.findMany({ where: { patientId: patient.id, ...deleteFilter } });
          }
          break;
        }
        case 'emergency_contacts': {
          if (patient) {
            created = await prisma.emergencyInfo.findMany({ where: { patientId: patient.id, ...filter } });
            updated = await prisma.emergencyInfo.findMany({ where: { patientId: patient.id, ...updateFilter } });
            deleted = await prisma.emergencyInfo.findMany({ where: { patientId: patient.id, ...deleteFilter } });
          }
          break;
        }
        case 'access_grants': {
          created = await prisma.accessManagement.findMany({ where: { grantedToId: userId, ...filter }, include: { patient: { include: { user: true } } } });
          break;
        }
        case 'journey': {
          if (patient) {
            created = await prisma.journeyEntry.findMany({ where: { patientId: patient.id, ...filter } });
            updated = await prisma.journeyEntry.findMany({ where: { patientId: patient.id, ...updateFilter } });
            deleted = await prisma.journeyEntry.findMany({ where: { patientId: patient.id, ...deleteFilter } });
          }
          break;
        }
      }
      result[entityType] = { created, updated, deleted };
    }

    res.json({
      success: true,
      data: result,
      syncTimestamp: new Date().toISOString(),
    });
  } catch (error) {
    next(error);
  }
});

export default router;
