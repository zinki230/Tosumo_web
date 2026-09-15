import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const databaseUrl = process.env.MONGODB_URI || process.env.DATABASE_URL || 'mongodb://localhost:27017/tosumo';

const prisma = new PrismaClient({
  datasources: { db: { url: databaseUrl } },
});

async function main() {
  console.log('Seeding database...');

  const passwordHash = await bcrypt.hash('Demo@1234', 12);

  const patientUser = await prisma.user.upsert({
    where: { email: 'patient@tosumo.cm' },
    update: {},
    create: {
      email: 'patient@tosumo.cm',
      phone: '+237699000100',
      passwordHash,
      role: 'patient',
      isActive: true,
      isEmailVerified: true,
      isPhoneVerified: true,
    },
  });
  console.log('Patient user:', patientUser.id);

  const doctorUser1 = await prisma.user.upsert({
    where: { email: 'doctor@tosumo.cm' },
    update: {},
    create: {
      email: 'doctor@tosumo.cm',
      phone: '+237699000101',
      passwordHash,
      role: 'doctor',
      isActive: true,
      isEmailVerified: true,
      isPhoneVerified: true,
    },
  });
  console.log('Doctor user 1:', doctorUser1.id);

  const doctorUser2 = await prisma.user.upsert({
    where: { email: 'cardiologue@tosumo.cm' },
    update: {},
    create: {
      email: 'cardiologue@tosumo.cm',
      phone: '+237699000102',
      passwordHash,
      role: 'doctor',
      isActive: true,
      isEmailVerified: true,
      isPhoneVerified: true,
    },
  });
  console.log('Doctor user 2:', doctorUser2.id);

  const doctorUser3 = await prisma.user.upsert({
    where: { email: 'pediatre@tosumo.cm' },
    update: {},
    create: {
      email: 'pediatre@tosumo.cm',
      phone: '+237699000103',
      passwordHash,
      role: 'doctor',
      isActive: true,
      isEmailVerified: true,
      isPhoneVerified: true,
    },
  });
  console.log('Doctor user 3:', doctorUser3.id);

  const patient = await prisma.patient.upsert({
    where: { userId: patientUser.id },
    update: { nin: 'NIN-CM-1990-0515-001' },
    create: {
      userId: patientUser.id,
      nin: 'NIN-CM-1990-0515-001',
      dateOfBirth: new Date('1990-05-15'),
      gender: 'FEMALE',
      bloodType: 'O+',
      heightCm: 165,
      weightKg: 68,
      allergies: ['Penicillin'],
      chronicDiseases: ['Asthma'],
      emergencyContactName: 'Pierre Nkeng',
      emergencyContactPhone: '+237677000002',
      address: '45 Rue de la Paix',
      city: 'Yaoundé',
      region: 'Centre',
      isOnboarded: true,
    },
  });
  console.log('Patient:', patient.id);

  const doctor1 = await prisma.doctor.upsert({
    where: { userId: doctorUser1.id },
    update: {},
    create: {
      userId: doctorUser1.id,
      firstName: 'Jean-Pierre',
      lastName: 'Mbarga',
      title: 'Dr.',
      specialty: 'General Practitioner',
      licenseNumber: 'CAM-MD-2024-001',
      yearsOfExperience: 10,
      consultationFee: 25000,
      bio: 'Experienced general practitioner with 10 years of service in Cameroon. Specializes in family medicine and preventive care.',
      isVerified: true,
      city: 'Yaoundé',
      region: 'Centre',
      languages: ['French', 'English'],
      averageRating: 4.5,
      totalRatings: 28,
    },
  });
  console.log('Doctor 1:', doctor1.id);

  const doctor2 = await prisma.doctor.upsert({
    where: { userId: doctorUser2.id },
    update: {},
    create: {
      userId: doctorUser2.id,
      firstName: 'Marie-Claire',
      lastName: 'Essomba',
      title: 'Dr.',
      specialty: 'Cardiologist',
      licenseNumber: 'CAM-MD-2024-002',
      yearsOfExperience: 15,
      consultationFee: 50000,
      bio: 'Senior cardiologist specializing in cardiovascular diseases and hypertension management.',
      isVerified: true,
      city: 'Douala',
      region: 'Littoral',
      languages: ['French', 'English', 'German'],
      averageRating: 4.8,
      totalRatings: 42,
    },
  });
  console.log('Doctor 2:', doctor2.id);

  const doctor3 = await prisma.doctor.upsert({
    where: { userId: doctorUser3.id },
    update: {},
    create: {
      userId: doctorUser3.id,
      firstName: 'Paul',
      lastName: 'Biyé',
      title: 'Dr.',
      specialty: 'Pediatrician',
      licenseNumber: 'CAM-MD-2024-003',
      yearsOfExperience: 8,
      consultationFee: 30000,
      bio: 'Passionate pediatrician dedicated to children\'s health and development.',
      isVerified: true,
      city: 'Yaoundé',
      region: 'Centre',
      languages: ['French', 'English'],
      averageRating: 4.6,
      totalRatings: 35,
    },
  });
  console.log('Doctor 3:', doctor3.id);

  const existingInst1 = await prisma.institution.findFirst({ where: { name: 'Tosumo Central Hospital' } });
  const inst1 = existingInst1 || await prisma.institution.create({
    data: {
      name: 'Tosumo Central Hospital',
      type: 'HOSPITAL',
      address: '123 Boulevard de la République',
      city: 'Yaoundé',
      region: 'Centre',
      phone: '+237233000001',
      email: 'contact@tosumohospital.cm',
      isVerified: true,
    },
  });

  const existingInst2 = await prisma.institution.findFirst({ where: { name: 'Douala Cardiology Center' } });
  const inst2 = existingInst2 || await prisma.institution.create({
    data: {
      name: 'Douala Cardiology Center',
      type: 'CLINIC',
      address: '45 Avenue Kennedy',
      city: 'Douala',
      region: 'Littoral',
      phone: '+237233000002',
      email: 'info@doulacardio.cm',
      isVerified: true,
    },
  });
  console.log('Institutions created');

  const di1 = await prisma.doctorInstitution.findFirst({ where: { doctorId: doctor1.id, institutionId: inst1.id } });
  if (!di1) await prisma.doctorInstitution.create({ data: { doctorId: doctor1.id, institutionId: inst1.id, isPrimary: true } });

  const di2 = await prisma.doctorInstitution.findFirst({ where: { doctorId: doctor2.id, institutionId: inst2.id } });
  if (!di2) await prisma.doctorInstitution.create({ data: { doctorId: doctor2.id, institutionId: inst2.id, isPrimary: true } });

  const di3 = await prisma.doctorInstitution.findFirst({ where: { doctorId: doctor3.id, institutionId: inst1.id } });
  if (!di3) await prisma.doctorInstitution.create({ data: { doctorId: doctor3.id, institutionId: inst1.id, isPrimary: true } });

  const doctors = [doctor1, doctor2, doctor3];
  for (const doc of doctors) {
    for (let day = 1; day <= 5; day++) {
      const existing = await prisma.doctorAvailability.findFirst({ where: { doctorId: doc.id, dayOfWeek: day } });
      if (!existing) {
        await prisma.doctorAvailability.create({
          data: { doctorId: doc.id, dayOfWeek: day, startTime: '08:00', endTime: '17:00', isAvailable: true, slotDuration: 30 },
        });
      }
    }
  }
  console.log('Availability created');

  const tomorrow = new Date(Date.now() + 86400000);
  for (const doc of doctors) {
    const existing = await prisma.workingHours.findFirst({ where: { doctorId: doc.id, date: tomorrow } });
    if (!existing) {
      await prisma.workingHours.create({
        data: { doctorId: doc.id, date: tomorrow, startTime: '08:00', endTime: '17:00', isAvailable: true },
      });
    }
  }

  const card = await prisma.medicalCard.upsert({
    where: { patientId: patient.id },
    update: {},
    create: {
      patientId: patient.id,
      cardNumber: 'TOS-CARD-2024-00001',
      issueDate: new Date(),
      isActive: true,
    },
  });
  console.log('Medical card:', card.id);

  await prisma.emergencyInfo.create({
    data: {
      patientId: patient.id,
      fullName: 'Pierre Nkeng',
      phone: '+237677000002',
      relationship: 'spouse',
      isPrimary: true,
    },
  });
  console.log('Emergency info created');

  const appointment = await prisma.appointment.create({
    data: {
      patientId: patient.id,
      doctorId: doctor1.id,
      institutionId: inst1.id,
      appointmentDate: tomorrow,
      startTime: '09:00',
      endTime: '09:30',
      durationMinutes: 30,
      type: 'consultation',
      status: 'confirmed',
      reason: 'Annual checkup and asthma follow-up',
      notes: 'Patient has mild asthma. Check lung function.',
    },
  });
  console.log('Appointment:', appointment.id);

  const pastDate = new Date(Date.now() - 7 * 86400000);
  const visit = await prisma.visit.create({
    data: {
      medicalCardId: card.id,
      appointmentId: appointment.id,
      institutionId: inst1.id,
      visitDate: pastDate,
      diagnosis: 'Mild allergic rhinitis. Patient responding well to antihistamine treatment.',
      symptoms: ['Sneezing', 'Runny nose', 'Itchy eyes'],
      notes: 'Patient reported sneezing and runny nose for past 3 days. No fever. Prescribed Loratadine 10mg daily for 2 weeks.',
    },
  });
  console.log('Visit:', visit.id);

  await prisma.consultation.create({
    data: {
      patientId: patient.id,
      doctorId: doctor1.id,
      appointmentId: appointment.id,
      chiefComplaint: 'Persistent sneezing and runny nose',
      historyOfPresentIllness: 'Symptoms started 3 days ago. Patient reports sneezing, runny nose, and itchy eyes. No fever or body aches.',
      diagnosis: 'J30.1 - Allergic rhinitis due to pollen',
      symptoms: ['Sneezing', 'Runny nose', 'Itchy eyes'],
      assessment: 'Mild allergic rhinitis. Likely triggered by seasonal pollen exposure.',
      plan: 'Continue Loratadine 10mg daily. Avoid outdoor activities during high pollen count. Follow up if symptoms persist.',
      notes: 'Patient advised on allergen avoidance strategies.',
      consultationDate: pastDate,
    },
  });
  console.log('Consultation created');

  await prisma.labResult.create({
    data: {
      patientId: patient.id,
      doctorId: doctor1.id,
      testName: 'Complete Blood Count',
      testCategory: 'blood',
      orderedDate: pastDate,
      resultDate: new Date(pastDate.getTime() + 86400000),
      resultData: {
        wbc: 6.5,
        rbc: 4.8,
        hemoglobin: 14.2,
        platelets: 250,
      },
      laboratoryName: 'Central Lab Yaoundé',
      status: 'completed',
      notes: 'All values within normal range.',
    },
  });
  console.log('Lab result created');

  await prisma.prescription.create({
    data: {
      patientId: patient.id,
      doctorId: doctor1.id,
      medicationName: 'Loratadine 10mg',
      dosage: '1 tablet',
      frequency: 'daily',
      duration: '14 days',
      route: 'oral',
      instructions: 'Take one tablet daily in the morning.',
      prescribedDate: pastDate,
      startDate: pastDate,
      endDate: new Date(pastDate.getTime() + 14 * 86400000),
      isActive: true,
    },
  });
  console.log('Prescription created');

  await prisma.accessManagement.create({
    data: {
      patientId: patient.id,
      grantedToId: doctorUser1.id,
      grantedById: patientUser.id,
      accessLevel: 'full',
      accessType: 'permanent',
      isActive: true,
      isApproved: true,
    },
  });
  console.log('Access management created');

  const chat = await prisma.chat.create({
    data: { isGroup: false },
  });

  await prisma.chatParticipant.createMany({
    data: [
      { chatId: chat.id, patientId: patient.id },
      { chatId: chat.id, doctorId: doctor1.id },
    ],
  });

  await prisma.chatMessage.create({
    data: {
      chatId: chat.id,
      senderId: doctorUser1.id,
      senderRole: 'doctor',
      content: 'Bonjour Alice, I have reviewed your test results. Everything looks good. Let me know if you have any concerns.',
      messageType: 'text',
      createdAt: new Date(pastDate.getTime() + 3600000),
    },
  });

  await prisma.chatMessage.create({
    data: {
      chatId: chat.id,
      senderId: patientUser.id,
      senderRole: 'patient',
      content: 'Thank you doctor! I feel much better now. The medication is working well.',
      messageType: 'text',
      createdAt: new Date(pastDate.getTime() + 7200000),
    },
  });
  console.log('Chat created');

  await prisma.notification.create({
    data: {
      userId: patientUser.id,
      title: 'Appointment Reminder',
      body: 'You have an appointment with Dr. Mbarga tomorrow at 09:00.',
      type: 'appointment',
      data: { appointmentId: appointment.id },
      isRead: false,
    },
  });
  console.log('Notification created');

  await prisma.journeyEntry.create({
    data: {
      patientId: patient.id,
      title: 'First consultation at Tosumo Central',
      description: 'Initial visit for general checkup and asthma evaluation.',
      entryType: 'consultation',
      referenceId: appointment.id,
      hospitalName: 'Tosumo Central Hospital',
      doctorName: 'Dr. Jean-Pierre Mbarga',
      entryDate: pastDate,
    },
  });
  console.log('Journey entry created');

  console.log('Seed complete.');
}

main()
  .catch((e) => {
    console.error('Seed error:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
