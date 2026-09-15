import { PrismaClient } from '@prisma/client';
import { config } from '@shared/config';

const MODELS_WITH_SOFT_DELETE: (string | undefined)[] = [
  'User',
  'Patient',
  'Doctor',
  'DoctorAvailability',
  'WorkingHours',
  'Appointment',
  'Institution',
  'Consultation',
  'LabResult',
  'ImagingResult',
  'Prescription',
];

const isCreate = (p: any) => p.action === 'create' || p.action === 'createMany' || p.action === 'upsert';

const prisma = new PrismaClient({
  datasources: { db: { url: config.database.url } },
  log: process.env.NODE_ENV === 'development' ? ['error', 'warn'] : ['error'],
});

prisma.$use(async (params, next) => {
  if (isCreate(params) && MODELS_WITH_SOFT_DELETE.includes(params.model)) {
    if (params.action === 'create') {
      if (params.args.data !== undefined) {
        params.args.data.deletedAt = params.args.data.deletedAt ?? null;
      }
    } else if (params.action === 'createMany' && Array.isArray(params.args.data)) {
      for (const item of params.args.data) {
        item.deletedAt = item.deletedAt ?? null;
      }
    } else if (params.action === 'upsert') {
      if (params.args.create !== undefined) {
        params.args.create.deletedAt = params.args.create.deletedAt ?? null;
      }
    }
  }
  return next(params);
});

export default prisma;