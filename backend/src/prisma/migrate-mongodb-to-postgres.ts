import dotenv from 'dotenv';
import { MongoClient, ObjectId } from 'mongodb';
import { Prisma, PrismaClient } from '@prisma/client';

dotenv.config();

const sourceUrl = process.env.MONGODB_SOURCE_URL;
const targetUrl = process.env.DATABASE_URL;
if (!sourceUrl) throw new Error('MONGODB_SOURCE_URL must point to the source MongoDB database.');
if (!targetUrl?.startsWith('postgresql://') && !targetUrl?.startsWith('postgres://')) {
  throw new Error('DATABASE_URL must point to the destination PostgreSQL database.');
}

// Parents are copied before children so PostgreSQL foreign keys remain valid.
const collectionsInOrder = [
  'User', 'Institution', 'Patient', 'Doctor', 'PhoneOtp', 'Device',
  'MedicalCard', 'MedicalBooklet', 'EmergencyInfo', 'JourneyEntry',
  'DoctorAvailability', 'WorkingHours', 'DoctorInstitution', 'DoctorReview',
  'Appointment', 'Visit', 'Consultation', 'LabResult', 'ImagingResult',
  'Prescription', 'Chat', 'ChatParticipant', 'ChatMessage', 'AccessManagement',
  'Notification', 'AuditLog', 'EmergencySession', 'PaymentTransaction',
];

function mongoValueToPostgres(value: unknown): unknown {
  if (value instanceof ObjectId) return value.toHexString();
  if (value instanceof Date || value === null || value === undefined) return value;
  if (Array.isArray(value)) return value.map(mongoValueToPostgres);
  if (Buffer.isBuffer(value)) return value;

  if (typeof value === 'object') {
    const bsonType = (value as { _bsontype?: string })._bsontype;
    if (bsonType === 'Decimal128') return Number((value as { toString(): string }).toString());
    if (bsonType === 'Long' || bsonType === 'Int32' || bsonType === 'Double') {
      return Number((value as { toString(): string }).toString());
    }
    const result: Record<string, unknown> = {};
    for (const [key, child] of Object.entries(value as Record<string, unknown>)) {
      result[key] = mongoValueToPostgres(child);
    }
    return result;
  }
  return value;
}

async function main(): Promise<void> {
  const mongo = new MongoClient(sourceUrl!);
  const postgres = new PrismaClient({ datasources: { db: { url: targetUrl } } });

  try {
    await mongo.connect();
    await postgres.$connect();
    const source = mongo.db();
    const sourceUserIds = new Set(
      (await source.collection('User').find({}, { projection: { _id: 1 } }).toArray()).map((user) =>
        user._id instanceof ObjectId ? user._id.toHexString() : String(user._id),
      ),
    );

    for (const collectionName of collectionsInOrder) {
      const collection = source.collection(collectionName);
      const total = await collection.countDocuments();
      if (total === 0) continue;

      const model = Prisma.dmmf.datamodel.models.find((candidate) => candidate.name === collectionName);
      if (!model) throw new Error(`No PostgreSQL model matches MongoDB collection ${collectionName}.`);
      const writableFields = new Set(
        model.fields.filter((field) => field.kind === 'scalar' || field.kind === 'enum').map((field) => field.name),
      );

      let inserted = 0;
      let detachedOrphanedPatientLinks = 0;
      const cursor = collection.find({}).batchSize(500);
      let batch: Record<string, unknown>[] = [];

      const flush = async () => {
        if (batch.length === 0) return;
        const docs = batch.map((doc) => {
          const converted = mongoValueToPostgres(doc) as Record<string, unknown>;
          if (converted._id !== undefined) {
            converted.id = converted._id;
            delete converted._id;
          }
          // MongoDB documents can contain ODM metadata or fields removed from
          // the current schema. Only send columns known to this Prisma model.
          const data = Object.fromEntries(
            Object.entries(converted).filter(([field]) => writableFields.has(field)),
          );
          // Preserve the patient record if its legacy account document is
          // missing. Patient.userId is optional in PostgreSQL; keep the
          // medical record and report this relationship repair explicitly.
          if (collectionName === 'Patient' && data.userId != null && !sourceUserIds.has(String(data.userId))) {
            data.userId = null;
            detachedOrphanedPatientLinks += 1;
          }
          return data;
        });
        const result = await (postgres as any)[collectionName[0].toLowerCase() + collectionName.slice(1)]
          .createMany({ data: docs, skipDuplicates: true });
        inserted += result.count;
        batch = [];
      };

      for await (const doc of cursor) {
        batch.push(doc as unknown as Record<string, unknown>);
        if (batch.length >= 500) await flush();
      }
      await flush();
      console.info(`${collectionName}: ${inserted}/${total} records copied (existing IDs skipped).`);
      if (detachedOrphanedPatientLinks > 0) {
        console.warn(`Patient: ${detachedOrphanedPatientLinks} records retained with userId cleared because the referenced User record is missing.`);
      }
    }

    console.info('MongoDB to PostgreSQL copy finished. Verify row counts and application flows before cutover.');
  } finally {
    await Promise.allSettled([mongo.close(), postgres.$disconnect()]);
  }
}

main().catch((error) => {
  const code = typeof error === 'object' && error !== null && 'code' in error
    ? String((error as { code: unknown }).code)
    : error instanceof Error ? error.name : 'UnknownError';
  console.error(`Data migration failed (${code}). Check the source data/schema compatibility; sensitive record details were omitted.`);
  process.exitCode = 1;
});
