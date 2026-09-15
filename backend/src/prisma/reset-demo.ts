import { PrismaClient } from '@prisma/client';
import dotenv from 'dotenv';

dotenv.config();

const databaseUrl =
  process.env.MONGODB_URI || process.env.DATABASE_URL || 'mongodb://localhost:27017/tosumo';

const prisma = new PrismaClient({
  datasources: { db: { url: databaseUrl } },
});

async function main() {
  console.log('Resetting demo accounts...');

  // Every demo-seeded row is tagged on the user with isDemoAccount.
  const demoUsers = await prisma.user.findMany({
    where: { isDemoAccount: true },
    select: { id: true },
  });
  const userIds = demoUsers.map((u) => u.id);

  if (userIds.length === 0) {
    console.log('No demo accounts found — nothing to reset.');
    return;
  }
  console.log(`Found ${userIds.length} demo user(s): ${textJoin(userIds)}`);

  const patients = await prisma.patient.findMany({
    where: { userId: { in: userIds } },
    select: { id: true },
  });
  const patientIds = patients.map((p) => p.id);

  const doctors = await prisma.doctor.findMany({
    where: { userId: { in: userIds } },
    select: { id: true },
  });
  const doctorIds = doctors.map((d) => d.id);

  // chat participants/messages for demo patients or doctors
  const chats = await prisma.chatParticipant.findMany({
    where: { OR: [{ patientId: { in: patientIds } }, { doctorId: { in: doctorIds } }] },
    select: { chatId: true },
  });
  const chatIds = [...new Set(chats.map((c) => c.chatId))];

  // Payment/Notification/Audit tied to the demo users
  await dele(prisma.paymentTransaction.deleteMany({ where: { userId: { in: userIds } } }));
  await dele(prisma.notification.deleteMany({ where: { userId: { in: userIds } } }));
  await dele(prisma.auditLog.deleteMany({ where: { userId: { in: userIds } } }));
  await dele(prisma.device.deleteMany({ where: { userId: { in: userIds } } }));

  // Chat
  if (chatIds.length > 0) {
    await dele(prisma.chatMessage.deleteMany({ where: { chatId: { in: chatIds } } }));
    await dele(prisma.chatParticipant.deleteMany({ where: { chatId: { in: chatIds } } }));
    await dele(prisma.chat.deleteMany({ where: { id: { in: chatIds } } }));
  }

  // Patient-linked records
  await dele(prisma.accessManagement.deleteMany({
    where: { OR: [{ patientId: { in: patientIds } }, { grantedToId: { in: userIds } }, { grantedById: { in: userIds } }] },
  }));
  await dele(prisma.accessManagement.deleteMany({
    where: { OR: [{ patientId: { in: patientIds } }, { grantedToId: { in: userIds } }, { grantedById: { in: userIds } }] },
  }));
  await dele(prisma.journeyEntry.deleteMany({ where: { patientId: { in: patientIds } } }));
  await dele(prisma.medicalBooklet.deleteMany({ where: { patientId: { in: patientIds } } }));
  await dele(prisma.emergencyInfo.deleteMany({ where: { patientId: { in: patientIds } } }));

  const cards = await prisma.medicalCard.findMany({
    where: { patientId: { in: patientIds } },
    select: { id: true },
  });
  const cardIds = cards.map((c) => c.id);
  if (cardIds.length > 0) {
    await dele(prisma.visit.deleteMany({ where: { medicalCardId: { in: cardIds } } }));
  }
  await dele(prisma.prescription.deleteMany({ where: { patientId: { in: patientIds } } }));
  await dele(prisma.imagingResult.deleteMany({ where: { patientId: { in: patientIds } } }));
  await dele(prisma.labResult.deleteMany({ where: { patientId: { in: patientIds } } }));
  await dele(prisma.consultation.deleteMany({ where: { patientId: { in: patientIds } } }));
  await dele(prisma.appointment.deleteMany({ where: { OR: [{ patientId: { in: patientIds } }, { doctorId: { in: doctorIds } }] } }));
  await dele(prisma.medicalCard.deleteMany({ where: { patientId: { in: patientIds } } }));

  // Doctor-linked records
  await dele(prisma.doctorReview.deleteMany({ where: { doctorId: { in: doctorIds } } }));
  await dele(prisma.doctorInstitution.deleteMany({ where: { doctorId: { in: doctorIds } } }));
  await dele(prisma.doctorAvailability.deleteMany({ where: { doctorId: { in: doctorIds } } }));
  await dele(prisma.workingHours.deleteMany({ where: { doctorId: { in: doctorIds } } }));

  // Entities themselves
  await dele(prisma.doctor.deleteMany({ where: { userId: { in: userIds } } }));
  await dele(prisma.patient.deleteMany({ where: { userId: { in: userIds } } }));
  await dele(prisma.user.deleteMany({ where: { id: { in: userIds } } }));

  const leftover = await prisma.user.findMany({ where: { isDemoAccount: true }, select: { id: true } });
  if (leftover.length > 0) {
    console.error(`Residual demo users remaining: ${textJoin(leftover.map((l) => l.id))}. Manual cleanup required.`);
  } else {
    console.log('Demo data cleaned. Run `npm run seed:demo` to restore it.');
  }
}

function textJoin(ids: string[]): string {
  return ids.map((i) => i.slice(0, 8)).join(', ');
}

async function dele<T>(p: Promise<T>): Promise<T> {
  return p;
}

main()
  .catch((e) => {
    console.error('Reset error:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());