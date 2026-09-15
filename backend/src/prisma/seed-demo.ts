import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import dotenv from 'dotenv';
import { IDS, oid } from './demo-ids';

dotenv.config();

// The backend resolves the DB URL from MONGODB_URI (config/index.ts), so the demo
// data must land in the exact same MongoDB the API serves.
const databaseUrl =
  process.env.MONGODB_URI || process.env.DATABASE_URL || 'mongodb://localhost:27017/tosumo';

const prisma = new PrismaClient({
  datasources: { db: { url: databaseUrl } },
});

// Mirror the app's shared client (src/shared/database/prisma.ts): the API
// filters records by `deletedAt: null`, so every created demo row must carry
// an explicit `deletedAt: null` or the repositories will hide the data.
const MODELS_WITH_SOFT_DELETE = [
  'User', 'Patient', 'Doctor', 'Appointment', 'Institution', 'Consultation',
  'LabResult', 'ImagingResult', 'Prescription', 'MedicalCard', 'MedicalBooklet',
  'EmergencyInfo', 'JourneyEntry', 'Chat', 'ChatMessage', 'AccessManagement',
  'Notification',
];
prisma.$use(async (params, next) => {
  if (params.action === 'create') {
    if (MODELS_WITH_SOFT_DELETE.includes(String(params.model))) {
      if (params.args.data !== undefined) {
        params.args.data.deletedAt = params.args.data.deletedAt ?? null;
      }
    }
  }
  return next(params);
});

const DEMO_PHONE = process.env.DEMO_PATIENT_PHONE || '+237691234567';
const DEMO_PASSWORD = process.env.DEMO_PATIENT_PASSWORD || 'Demo@1234';
const DEMO_EMAIL = process.env.DEMO_PATIENT_EMAIL || 'demo@tosumo.cm';
const DEMO_NIN = process.env.DEMO_PATIENT_NIN || 'NIN-DEMO-1985-0314-001';

const DAYS = 24 * 60 * 60 * 1000;
const now = Date.now();

const daysAgo = (n: number, hour = 9) => new Date(now - n * DAYS).setHours(hour, 0, 0, 0);

async function main() {
  console.log('Seeding DEMO patient account...');
  const demoPasswordHash = await bcrypt.hash(DEMO_PASSWORD, 12);
  const doctorPasswordHash = await bcrypt.hash('Demo@1234', 12);

  // ---------------------------------------------------------------
  // 1. USERS
  // ---------------------------------------------------------------
  let patientUser = await prisma.user.findFirst({ where: { id: IDS.userPatient } });
  if (patientUser) {
    patientUser = await prisma.user.update({
      where: { id: IDS.userPatient },
      data: {
        phone: DEMO_PHONE,
        email: DEMO_EMAIL,
        passwordHash: demoPasswordHash,
        role: 'patient',
        isActive: true,
        isDemoAccount: true,
        deletedAt: null,
      },
    });
  } else {
    const existing = await prisma.user.findUnique({ where: { phone: DEMO_PHONE } });
    if (existing) {
      patientUser = await prisma.user.update({
        where: { phone: DEMO_PHONE },
        data: {
          email: DEMO_EMAIL,
          passwordHash: demoPasswordHash,
          role: 'patient',
          isActive: true,
          isDemoAccount: true,
          deletedAt: null,
        },
      });
    } else {
      patientUser = await prisma.user.create({
        data: {
          id: IDS.userPatient,
          email: DEMO_EMAIL,
          phone: DEMO_PHONE,
          passwordHash: demoPasswordHash,
          role: 'patient',
          isActive: true,
        },
      });
    }
  }

  const doctorUsers: Array<{ id: string; phone: string; email: string }> = [
    { id: IDS.gpUser, phone: '+237691000101', email: 'demo.gp@tosumo.cm' },
    { id: IDS.cardioUser, phone: '+237691000102', email: 'demo.cardio@tosumo.cm' },
    { id: IDS.pedsUser, phone: '+237691000103', email: 'demo.peds@tosumo.cm' },
    { id: IDS.dermUser, phone: '+237691000104', email: 'demo.derm@tosumo.cm' },
    { id: IDS.gynoUser, phone: '+237691000105', email: 'demo.gyno@tosumo.cm' },
    { id: IDS.neuroUser, phone: '+237691000106', email: 'demo.neuro@tosumo.cm' },
    { id: IDS.entUser, phone: '+237691000107', email: 'demo.ent@tosumo.cm' },
    { id: IDS.ophtaUser, phone: '+237691000108', email: 'demo.ophta@tosumo.cm' },
    { id: IDS.dentUser, phone: '+237691000109', email: 'demo.dent@tosumo.cm' },
    { id: IDS.psychUser, phone: '+237691000110', email: 'demo.psych@tosumo.cm' },
  ];
  const doctorUserIds: Record<string, string> = {};
  for (const du of doctorUsers) {
    const u = await prisma.user.upsert({
      where: { phone: du.phone },
      update: { isDemoAccount: true },
      create: {
        id: du.id,
        phone: du.phone,
        email: du.email,
        passwordHash: doctorPasswordHash,
        role: 'doctor',
        isActive: true,
      },
    });
    doctorUserIds[du.id] = u.id;
  }

  // ---------------------------------------------------------------
  // 2. PATIENT PROFILE
  // ---------------------------------------------------------------
  const patient = await prisma.patient.upsert({
    where: { userId: patientUser.id },
    update: { deletedAt: null },
    create: {
      id: IDS.patient,
      userId: patientUser.id,
      nin: DEMO_NIN,
      firstName: 'Jean-Pierre',
      lastName: 'Mballa',
      deletedAt: null,
      dateOfBirth: new Date('1985-03-14'),
      gender: 'Male',
      bloodType: 'O+',
      heightCm: 178,
      weightKg: 82,
      allergies: ['Pénicilline', 'Arachides'],
      chronicDiseases: ['Hypertension', 'Diabète de type 2'],
      emergencyContactName: 'Clarisse Mballa',
      emergencyContactPhone: '+237699222333',
      address: 'Quartier Bastos, Rue 1.865',
      city: 'Yaoundé',
      region: 'Centre',
      isOnboarded: true,
      onboardingStep: 0,
    },
  });
  console.log('Patient ready:', patient.id);

  // ---------------------------------------------------------------
  // 2b. ADDITIONAL DEMO PATIENTS (directory / filtering)
  // ---------------------------------------------------------------
  const extraPatientDefs = [
    { key: 'P2', user: IDS.userP2, pat: IDS.patientP2, card: IDS.cardP2, phone: '+237691000201', email: 'demo.patient2@tosumo.cm', nin: 'NIN-DEMO-1992-0722-002', first: 'Amina', last: 'Fofé', gender: 'Female', blood: 'A+', dob: '1992-07-22', height: 165, weight: 60, allergies: ['Latex'], conditions: ['Asthme'], city: 'Douala', region: 'Littoral' },
    { key: 'P3', user: IDS.userP3, pat: IDS.patientP3, card: IDS.cardP3, phone: '+237691000202', email: 'demo.patient3@tosumo.cm', nin: 'NIN-DEMO-1978-1103-003', first: 'Luc', last: 'Ngono', gender: 'Male', blood: 'B+', dob: '1978-11-03', height: 172, weight: 76, allergies: [] as string[], conditions: ['Diabète de type 2'], city: 'Yaoundé', region: 'Centre' },
    { key: 'P4', user: IDS.userP4, pat: IDS.patientP4, card: IDS.cardP4, phone: '+237691000203', email: 'demo.patient4@tosumo.cm', nin: 'NIN-DEMO-1995-0115-004', first: 'Sandra', last: 'Atangana', gender: 'Female', blood: 'AB-', dob: '1995-01-15', height: 160, weight: 55, allergies: ['Iode'], conditions: ['Drepanocytose'], city: 'Bafoussam', region: 'Ouest' },
    { key: 'P5', user: IDS.userP5, pat: IDS.patientP5, card: IDS.cardP5, phone: '+237691000204', email: 'demo.patient5@tosumo.cm', nin: 'NIN-DEMO-2000-0930-005', first: 'Brice', last: 'Mengue', gender: 'Male', blood: 'O-', dob: '2000-09-30', height: 180, weight: 70, allergies: ['Fruits de mer'], conditions: ['Asthme', 'Allergie alimentaire'], city: 'Douala', region: 'Littoral' },
    { key: 'P6', user: IDS.userP6, pat: IDS.patientP6, card: IDS.cardP6, phone: '+237691000205', email: 'demo.patient6@tosumo.cm', nin: 'NIN-DEMO-1988-0419-006', first: 'Éstelle', last: 'Ndongo', gender: 'Female', blood: 'B-', dob: '1988-04-19', height: 168, weight: 64, allergies: [] as string[], conditions: ['Hypothyroïdie'], city: 'Yaoundé', region: 'Centre' },
  ];
  const allPatientIds: string[] = [patient.id];
  for (const d of extraPatientDefs) {
    await prisma.user.upsert({
      where: { phone: d.phone },
      update: { isDemoAccount: true },
      create: { id: d.user, phone: d.phone, email: d.email, passwordHash: demoPasswordHash, role: 'patient', isActive: true },
    });
    const p = await prisma.patient.upsert({
      where: { id: d.pat },
      update: { deletedAt: null },
      create: {
        id: d.pat,
        userId: d.user,
        nin: d.nin,
        firstName: d.first,
        lastName: d.last,
        dateOfBirth: new Date(d.dob),
        gender: d.gender,
        bloodType: d.blood,
        heightCm: d.height,
        weightKg: d.weight,
        allergies: d.allergies,
        chronicDiseases: d.conditions,
        address: `Quartier ${d.city}`,
        city: d.city,
        region: d.region,
        isOnboarded: true,
        onboardingStep: 0,
        deletedAt: null,
      },
    });
    await prisma.medicalCard.upsert({
      where: { patientId: p.id },
      update: { isActive: true, deletedAt: null },
      create: {
        id: d.card,
        patientId: p.id,
        cardNumber: `TOS-CARD-DEMO-${d.key}`,
        issueDate: new Date(daysAgo(180)),
        expiryDate: new Date(now + 185 * DAYS),
        isActive: true,
        qrCodeHash: `DEMO-QR-${d.key}`,
        deletedAt: null,
      },
    });
    allPatientIds.push(p.id);
  }
  console.log('Extra demo patients ready:', allPatientIds.length);

  // ---------------------------------------------------------------
  // 3. MEDICAL CARD + EMERGENCY INFO
  // ---------------------------------------------------------------
  await prisma.medicalCard.upsert({
    where: { patientId: patient.id },
    update: { isActive: true, deletedAt: null },
    create: {
      id: IDS.card,
      patientId: patient.id,
      cardNumber: 'TOS-CARD-DEMO-0001',
      issueDate: new Date(daysAgo(180)),
      expiryDate: new Date(now + 185 * DAYS),
      isActive: true,
      qrCodeHash: 'DEMO-QR-0001-MBALLA',
      deletedAt: null,
    },
  });

  const emergencyDefs = [
    { id: oid('demo.emergency.spouse'), fullName: 'Clarisse Mballa', phone: '+237699222333', relationship: 'spouse', isPrimary: true },
    { id: oid('demo.emergency.sibling'), fullName: 'Éric Mballa', phone: '+237677888999', relationship: 'sibling', isPrimary: false },
  ];
  for (const e of emergencyDefs) {
    if (!(await prisma.emergencyInfo.findFirst({ where: { id: e.id } }))) {
      await prisma.emergencyInfo.create({
        data: {
          id: e.id,
          patientId: patient.id,
          fullName: e.fullName,
          phone: e.phone,
          relationship: e.relationship,
          isPrimary: e.isPrimary,
        },
      });
    }
  }

  // ---------------------------------------------------------------
  // 4. INSTITUTIONS
  // ---------------------------------------------------------------
  const instYaounde =
    (await prisma.institution.findFirst({ where: { id: IDS.institutionYaounde } })) ||
    (await prisma.institution.create({
      data: {
        id: IDS.institutionYaounde,
        name: "Centre Médical de l'Estuaire",
        type: 'HOSPITAL',
        phone: '+237233445566',
        email: 'contact@estuaire.sante.cm',
        address: 'Av. du Général-Leclerc',
        city: 'Yaoundé',
        region: 'Centre',
        isVerified: true,
      },
    }));
  const instDouala =
    (await prisma.institution.findFirst({ where: { id: IDS.institutionDouala } })) ||
    (await prisma.institution.create({
      data: {
        id: IDS.institutionDouala,
        name: 'Polyclinique Bonanjo',
        type: 'CLINIC',
        phone: '+237 233 42 85 10',
        email: 'accueil@bonanjo.clinic.cm',
        address: 'Rue Joss',
        city: 'Douala',
        region: 'Littoral',
        isVerified: true,
      },
    }));
  const instBafoussam =
    (await prisma.institution.findFirst({ where: { id: IDS.institutionBafoussam } })) ||
    (await prisma.institution.create({
      data: {
        id: IDS.institutionBafoussam,
        name: 'Hôpital Régional de Bafoussam',
        type: 'HOSPITAL',
        phone: '+237 233 44 12 34',
        email: 'contact@hrb.sante.cm',
        address: 'Quartier Tamdja',
        city: 'Bafoussam',
        region: 'Ouest',
        isVerified: true,
      },
    }));
  const instLab =
    (await prisma.institution.findFirst({ where: { id: IDS.institutionLab } })) ||
    (await prisma.institution.create({
      data: {
        id: IDS.institutionLab,
        name: "Laboratoire d'Analyses Médicales du Centre",
        type: 'LAB',
        phone: '+237 220 201 010',
        address: 'Rue de la Poste',
        city: 'Yaoundé',
        region: 'Centre',
        isVerified: true,
      },
    }));

  // ---------------------------------------------------------------
  // 5. DOCTORS
  // ---------------------------------------------------------------
  const doctorDefs = [
    {
      id: IDS.gp, userKey: IDS.gpUser, firstName: 'Théodore', lastName: 'Nkoulou',
      specialty: 'General Practitioner', licenseNumber: 'CAM-MD-2015-104', yearsOfExperience: 11,
      consultationFee: 25000, bio: 'Médecin généraliste, soins primaires et suivi des maladies chroniques.',
      city: 'Yaoundé', region: 'Centre', averageRating: 4.8, totalRatings: 36, institutionId: instYaounde.id,
      education: { degree: 'Doctorat en Médecine', school: 'Université de Yaoundé I' },
      certifications: ['Ordre National des Médecins du Cameroun'],
      languages: ['français', 'anglais'],
    },
    {
      id: IDS.cardio, userKey: IDS.cardioUser, firstName: 'Emilienne', lastName: 'Tchoua',
      specialty: 'Cardiologist', licenseNumber: 'CAM-MD-2016-211', yearsOfExperience: 12,
      consultationFee: 40000, bio: 'Cardiologue, spécialiste de l\'hypertension et de l\'insuffisance cardiaque.',
      city: 'Douala', region: 'Littoral', averageRating: 4.8, totalRatings: 52, institutionId: instDouala.id,
      languages: ['français', 'anglais'],
    },
    {
      id: IDS.peds, userKey: IDS.pedsUser, firstName: 'Blandine', lastName: 'Kamga',
      specialty: 'Pediatrician', licenseNumber: 'CAM-MD-2018-562', yearsOfExperience: 9,
      consultationFee: 30000, bio: 'Pédiatre dévouée à la santé de l\'enfant et à la prévention.',
      city: 'Yaoundé', region: 'Centre', averageRating: 4.7, totalRatings: 41, institutionId: instYaounde.id,
      languages: ['français', 'anglais'],
    },
    {
      id: IDS.derm, userKey: IDS.dermUser, firstName: 'Serge', lastName: 'Mbarga',
      specialty: 'Dermatologist', licenseNumber: 'CAM-MD-2019-331', yearsOfExperience: 8,
      consultationFee: 28000, bio: 'Dermatologue, expert en dermatoses tropicales et médecine esthétique.',
      city: 'Douala', region: 'Littoral', averageRating: 4.7, totalRatings: 29, institutionId: instDouala.id,
      languages: ['français', 'anglais'],
    },
    {
      id: IDS.gyno, userKey: IDS.gynoUser, firstName: 'Aline', lastName: 'Wandji',
      specialty: 'Gynecologist', licenseNumber: 'CAM-MD-2014-779', yearsOfExperience: 14,
      consultationFee: 35000, bio: 'Gynécologue-obstétricienne, suivi de la grossesse et de la santé de la femme.',
      city: 'Yaoundé', region: 'Centre', averageRating: 4.9, totalRatings: 47, institutionId: instYaounde.id,
      languages: ['français', 'anglais', 'ewondo'],
    },
    {
      id: IDS.neuro, userKey: IDS.neuroUser, firstName: 'Célestin', lastName: 'Nganou',
      specialty: 'Neurologist', licenseNumber: 'CAM-MD-2012-401', yearsOfExperience: 16,
      consultationFee: 45000, bio: 'Neurologue, spécialiste des affections du système nerveux et migraines.',
      city: 'Bafoussam', region: 'Ouest', averageRating: 4.9, totalRatings: 38, institutionId: instBafoussam.id,
      languages: ['français', 'anglais'],
    },
    {
      id: IDS.ent, userKey: IDS.entUser, firstName: 'Marc', lastName: 'Etoa',
      specialty: 'ENT Specialist', licenseNumber: 'CAM-MD-2017-882', yearsOfExperience: 10,
      consultationFee: 32000, bio: 'Spécialiste ORL, traitement des pathologies oreille, nez et gorge.',
      city: 'Yaoundé', region: 'Centre', averageRating: 4.6, totalRatings: 31, institutionId: instYaounde.id,
      languages: ['français', 'anglais'],
    },
    {
      id: IDS.ophta, userKey: IDS.ophtaUser, firstName: 'Hélène', lastName: 'Mebenga',
      specialty: 'Ophthalmologist', licenseNumber: 'CAM-MD-2015-623', yearsOfExperience: 13,
      consultationFee: 35000, bio: 'Ophtalmologue, spécialiste de la vision et de la chirurgie oculaire.',
      city: 'Douala', region: 'Littoral', averageRating: 4.8, totalRatings: 44, institutionId: instDouala.id,
      languages: ['français', 'anglais'],
    },
    {
      id: IDS.dent, userKey: IDS.dentUser, firstName: 'Patrick', lastName: 'Fosso',
      specialty: 'Dentist', licenseNumber: 'CAM-MD-2020-112', yearsOfExperience: 7,
      consultationFee: 25000, bio: 'Chirurgien-dentiste, soins dentaires préventifs et esthétique dentaire.',
      city: 'Bafoussam', region: 'Ouest', averageRating: 4.7, totalRatings: 25, institutionId: instBafoussam.id,
      languages: ['français', 'anglais'],
    },
    {
      id: IDS.psych, userKey: IDS.psychUser, firstName: 'Chantal', lastName: 'Ndzana',
      specialty: 'Psychiatrist', licenseNumber: 'CAM-MD-2013-905', yearsOfExperience: 15,
      consultationFee: 40000, bio: 'Psychiatre, prise en charge des troubles anxieux et de la santé mentale.',
      city: 'Yaoundé', region: 'Centre', averageRating: 4.9, totalRatings: 50, institutionId: instYaounde.id,
      languages: ['français', 'anglais'],
    },
  ];

  for (const d of doctorDefs) {
    const docExists = await prisma.doctor.findFirst({
      where: { OR: [{ userId: d.userKey }, { licenseNumber: d.licenseNumber }] },
    });
    const doc =
      docExists ||
      (await prisma.doctor.create({
        data: {
          id: d.id,
          userId: d.userKey,
          title: 'Dr.',
          firstName: d.firstName,
          lastName: d.lastName,
          specialty: d.specialty,
          licenseNumber: d.licenseNumber,
          yearsOfExperience: d.yearsOfExperience,
          consultationFee: d.consultationFee,
          bio: d.bio,
          isVerified: true,
          city: d.city,
          region: d.region,
          languages: d.languages,
          education: (d.education as any) ?? null,
          certifications: (d.certifications as any) ?? null,
          submittedAt: new Date(daysAgo(400)),
          verifiedAt: new Date(daysAgo(390)),
          averageRating: d.averageRating,
          totalRatings: d.totalRatings,
        },
      }));

    const link = await prisma.doctorInstitution.findFirst({ where: { doctorId: doc.id, institutionId: d.institutionId } });
    if (!link) {
      await prisma.doctorInstitution.create({
        data: { doctorId: doc.id, institutionId: d.institutionId, role: 'attending', isPrimary: true },
      });
    }
    for (let day = 0; day <= 6; day++) {
      const existing = await prisma.doctorAvailability.findFirst({ where: { doctorId: doc.id, dayOfWeek: day } });
      if (!existing) {
        await prisma.doctorAvailability.create({
          data: { doctorId: doc.id, dayOfWeek: day, startTime: '08:00', endTime: '17:00', isAvailable: true, slotDuration: 30 },
        });
      }
    }
    for (let dayOffset = 0; dayOffset <= 14; dayOffset++) {
      const dDate = new Date(now + dayOffset * DAYS);
      dDate.setHours(0, 0, 0, 0);
      const existingHours = await prisma.workingHours.findFirst({ where: { doctorId: doc.id, date: dDate } });
      if (!existingHours) {
        await prisma.workingHours.create({
          data: { doctorId: doc.id, date: dDate, startTime: '08:00', endTime: '17:00', isAvailable: true },
        });
      }
    }
  }
  console.log('Doctors ready');

  // ---------------------------------------------------------------
  // 6. CONSULTATIONS / LABS / IMAGING / PRESCRIPTIONS
  // ---------------------------------------------------------------
  const consultDefs = [
    {
      id: oid('demo.consult.gp'), doctorId: IDS.gp, daysAgo: 90,
      chiefComplaint: 'Suivi annuel de santé',
      diagnosis: 'Suivi médical de routine',
      notes: 'Suivi hypertension et diabète.',
      vitalSigns: { bp: '135/85', heartRate: 78, temp: 36.6, weight: 82 },
    },
    {
      id: oid('demo.consult.cardio'), doctorId: IDS.cardio, daysAgo: 60,
      chiefComplaint: 'Contrôle cardiologique après examens',
      diagnosis: 'I10 Hypertension essentielle',
      notes: 'Bilan lipidique à surveiller.',
      vitalSigns: { bp: '128/82', heartRate: 72 },
    },
    {
      id: oid('demo.consult.derm'), doctorId: IDS.derm, daysAgo: 30,
      chiefComplaint: 'Eczéma des mains',
      diagnosis: 'L20 Atlas Dermatitis',
      notes: 'Éviction des agents irritants.',
    },
    {
      id: oid('demo.consult.peds'), doctorId: IDS.peds, daysAgo: 15,
      chiefComplaint: 'Suivi vaccination de l\'enfant',
      diagnosis: 'Z23 Encounters pour vaccination',
    },
  ];
  for (const c of consultDefs) {
    if (!(await prisma.consultation.findFirst({ where: { id: c.id } }))) {
      await prisma.consultation.create({
        data: {
          id: c.id,
          patientId: patient.id,
          doctorId: c.doctorId,
          chiefComplaint: c.chiefComplaint,
          diagnosis: c.diagnosis,
          notes: c.notes ?? null,
          vitalSigns: c.vitalSigns ?? null,
          consultationDate: new Date(daysAgo(c.daysAgo)),
        },
      });
      const entry = await prisma.journeyEntry.findFirst({ where: { referenceId: c.id } });
      if (!entry) {
        await prisma.journeyEntry.create({
          data: {
            patientId: patient.id,
            title: c.chiefComplaint,
            entryType: 'consultation',
            referenceId: c.id,
            entryDate: new Date(daysAgo(c.daysAgo)),
          },
        });
      }
    }
  }

  const labDefs = [
    { id: oid('demo-lab-glycemie'), doctorId: IDS.gp, testName: 'Glycémie à jeun', category: 'blood', daysAgo: 30, laboratoryName: instLab.name, resultData: { value: 0.92, unit: 'g/L' }, isAbnormal: false },
    { id: oid('demo-lab-cbc'), doctorId: IDS.gp, testName: 'Numération formule sanguine', category: 'blood', daysAgo: 60, laboratoryName: instLab.name, resultData: { hemoglobin: 14.2, hematocrit: 43, leucemie: 6.5 }, isAbnormal: false },
    { id: oid('demo-lab-palu'), doctorId: IDS.gp, testName: 'Goutte épaisse (paludisme)', category: 'blood', daysAgo: 45, laboratoryName: instLab.name, resultData: { result: 'Négatif' }, isAbnormal: false },
    { id: oid('demo-lab-lipides'), doctorId: IDS.cardio, testName: 'Bilan lipidique', category: 'blood', daysAgo: 50, laboratoryName: instLab.name, resultData: { ldl: 1.6, hdl: 1.1, trigly: 1.4 }, isAbnormal: true, notes: 'LDL légèrement élevé' },
  ];
  for (const l of labDefs) {
    if (!(await prisma.labResult.findFirst({ where: { id: l.id } }))) {
      await prisma.labResult.create({
        data: {
          id: l.id,
          patientId: patient.id,
          doctorId: l.doctorId,
          testName: l.testName,
          testCategory: l.category,
          resultData: l.resultData as any,
          laboratoryName: (l as any).laboratoryName ?? null,
          orderedDate: new Date(daysAgo(l.daysAgo)),
          resultDate: new Date(daysAgo(l.daysAgo - 1)),
          status: 'completed',
          isAbnormal: l.isAbnormal,
          notes: (l as any).notes ?? null,
        },
      });
    }
  }

  const rxDefs = [
    { id: oid('demo-rx-amlodipine'), doctorId: IDS.cardio, med: 'Amlodipine 5mg', dosage: '1 comprimé/jour', freq: 'daily', duration: '3 mois', route: 'oral', instr: 'Un comprimé le matin.' },
    { id: oid('demo-rx-metformine'), doctorId: IDS.gp, med: 'Metformine 500mg', dosage: '2 comprimés/jour', freq: 'daily', duration: '3 mois', route: 'oral', instr: 'Aux repas.' },
    { id: oid('demo-rx-crème'), doctorId: IDS.derm, med: 'Hydrocortisone 1%', dosage: 'Appliquer 1x/jour', freq: 'daily', duration: '10 jours', route: 'topical', instr: 'Sur les lésions avant le coucher.' },
  ];
  for (const r of rxDefs) {
    if (!(await prisma.prescription.findFirst({ where: { id: r.id } }))) {
      await prisma.prescription.create({
        data: {
          id: r.id,
          patientId: patient.id,
          doctorId: r.doctorId,
          medicationName: r.med,
          dosage: r.dosage,
          frequency: r.freq,
          duration: r.duration,
          route: r.route,
          instructions: r.instr,
          isActive: true,
          prescribedDate: new Date(daysAgo(20)),
        },
      });
    }
  }

  // Medical booklets referencing the medical history above
  const bookletDefs = [
    { id: oid('demo-booklet-1'), title: 'Bilan annuel — médecin généraliste', type: 'consultation', hospitalName: instYaounde.name, doctorName: 'Dr. Théodore Nkoulou', date: now - 90 * DAYS },
    { id: oid('demo-booklet-2'), title: 'Résultats — glycémie à jeun', type: 'lab', hospitalName: instLab.name, doctorName: 'Laboratoire du Centre', date: now - 30 * DAYS },
    { id: oid('demo-booklet-3'), title: 'Bilan lipidique — cardiologie', type: 'lab', hospitalName: instLab.name, doctorName: 'Dr. Emilienne Tchoua', date: now - 50 * DAYS },
    { id: oid('demo-booklet-4'), title: 'Ordonnance — Amlodipine 5mg', type: 'prescription', hospitalName: instDouala.name, doctorName: 'Dr. Emilienne Tchoua', date: now - 20 * DAYS },
    { id: oid('demo-booklet-5'), title: 'Consultation dermatologie', type: 'consultation', hospitalName: instDouala.name, doctorName: 'Dr. Serge Mbarga', date: now - 30 * DAYS },
  ];
  for (const b of bookletDefs) {
    if (await prisma.medicalBooklet.findFirst({ where: { id: b.id } })) continue;
    await prisma.medicalBooklet.create({
      data: { id: b.id, patientId: patient.id, title: b.title, bookletType: b.type, hospitalName: b.hospitalName, doctorName: b.doctorName, recordDate: new Date(b.date) },
    });
  }

  // ---------------------------------------------------------------
  // 7. APPOINTMENTS
  // ---------------------------------------------------------------
  const apptDefs = [
    { id: IDS.appointmentUpcoming, doctorId: IDS.cardio, institutionId: instDouala.id, offset: 2, start: '09:00', end: '09:30', type: 'followup', status: 'confirmed', reason: 'Suivi cardiologique trimestriel' },
    { id: oid('demo-appt-past'), doctorId: IDS.gp, institutionId: instYaounde.id, offset: -60, start: '10:00', end: '10:30', type: 'consultation', status: 'completed', reason: 'Bilan annuel' },
    { id: oid('demo-appt-cancelled'), doctorId: IDS.derm, institutionId: instDouala.id, offset: -90, start: '14:00', end: '14:30', type: 'consultation', status: 'cancelled', reason: 'Consultation dermatologie' },
    { id: oid('demo-appt-rescheduled'), doctorId: IDS.peds, institutionId: instYaounde.id, offset: -120, start: '15:00', end: '15:30', type: 'checkup', status: 'rescheduled', reason: 'Vaccination de rappel' },
  ];
  for (const a of apptDefs) {
    if (!(await prisma.appointment.findFirst({ where: { id: a.id } }))) {
      await prisma.appointment.create({
        data: {
          id: a.id,
          patientId: patient.id,
          doctorId: a.doctorId,
          institutionId: a.institutionId,
          appointmentDate: new Date(now + a.offset * DAYS),
          startTime: a.start,
          endTime: a.end,
          durationMinutes: 30,
          type: a.type,
          status: a.status,
          reason: a.reason,
          isPaid: a.status === 'completed',
          amount: a.status === 'completed' ? 25000 : 0,
        },
      });
    }
  }
  const upcoming = await prisma.appointment.findUniqueOrThrow({ where: { id: IDS.appointmentUpcoming } });

  // Link every demo doctor to every demo patient so each doctor's directory is
  // populated (the patient list is derived from a doctor's appointments).
  const allDoctorIds = [
    IDS.gp, IDS.cardio, IDS.peds, IDS.derm, IDS.gyno,
    IDS.neuro, IDS.ent, IDS.ophta, IDS.dent, IDS.psych,
  ];
  for (const docId of allDoctorIds) {
    for (const patId of allPatientIds) {
      const aid = oid(`demo.appt.${docId}.${patId}`);
      if (await prisma.appointment.findFirst({ where: { id: aid } })) continue;
      const offset = 5 + allDoctorIds.indexOf(docId) * 7 + allPatientIds.indexOf(patId) * 3;
      await prisma.appointment.create({
        data: {
          id: aid,
          patientId: patId,
          doctorId: docId,
          institutionId: instYaounde.id,
          appointmentDate: new Date(daysAgo(offset)),
          startTime: '10:00',
          endTime: '10:30',
          durationMinutes: 30,
          type: 'consultation',
          status: 'completed',
          reason: 'Consultation de routine',
          isPaid: true,
          amount: 25000,
        },
      });
    }
  }
  console.log('Doctor -> patient appointment links created.');

  // ---------------------------------------------------------------
  // 8. CHAT
  // ---------------------------------------------------------------
  const chatDefs = [
    {
      chatId: IDS.chatCardio, doctorUserId: IDS.cardioUser, doctorId: IDS.cardio,
      messages: [
        { text: 'Bonjour Monsieur Mballa, je viens de recevoir vos analyses lipidiques.', from: 'doctor', daysAgo: 12 },
        { text: 'Bonjour Docteur, les résultats sont-ils bons ?', from: 'patient', daysAgo: 12 },
        { text: 'Le LDL est légèrement élevé, nous allons ajuster votre traitement à votre prochain rendez-vous.', from: 'doctor', daysAgo: 11 },
        { text: 'D\'accord, merci pour le suivi.', from: 'patient', daysAgo: 11 },
      ],
    },
    {
      chatId: IDS.chatGp, doctorUserId: IDS.gpUser, doctorId: IDS.gp,
      messages: [
        { text: 'Bonjour Jean-Pierre, votre glycémie est tout à fait correcte ce mois-ci.', from: 'doctor', daysAgo: 22 },
        { text: 'Excellent, je continue l\'alimentation équilibrée. Merci Docteur.', from: 'patient', daysAgo: 22 },
        { text: 'N\'oubliez pas le prochain contrôle dans 3 mois.', from: 'doctor', daysAgo: 21 },
      ],
    },
    {
      chatId: IDS.chatPeds, doctorUserId: IDS.pedsUser, doctorId: IDS.peds,
      messages: [
        { text: 'Bonjour Docteur, pour la vaccination de mon enfant (rappel DTC), on confirme ?', from: 'patient', daysAgo: 5 },
        { text: 'Oui, mercredi 14h au centre Médical, pensez à apporter le carnet de vaccination.', 'from': 'doctor', daysAgo: 4 },
        { text: 'Parfait, à mercredi !', from: 'patient', daysAgo: 4 },
      ],
    },
  ];
  for (const def of chatDefs) {
    const existingChat = await prisma.chat.findFirst({ where: { id: def.chatId } });
    const chat =
      existingChat ||
      (await prisma.chat.create({
        data: { id: def.chatId, isGroup: false },
      }));
    const hasParticipant = await prisma.chatParticipant.findFirst({ where: { chatId: chat.id, patientId: patient.id } });
    if (!hasParticipant) {
      await prisma.chatParticipant.create({
        data: { chatId: chat.id, patientId: patient.id },
      });
    }
    const doctorParticipant = await prisma.chatParticipant.findFirst({ where: { chatId: chat.id, doctorId: def.doctorId } });
    if (!doctorParticipant) {
      await prisma.chatParticipant.create({
        data: { chatId: chat.id, doctorId: def.doctorId },
      });
    }
    let idx = 0;
    for (const m of def.messages) {
      const msgId = oid(`demo.msg.${def.chatId}.${idx}`);
      const existingMsg = await prisma.chatMessage.findFirst({ where: { id: msgId } });
      if (!existingMsg) {
        await prisma.chatMessage.create({
          data: {
            id: msgId,
            chatId: chat.id,
            senderId: m.from === 'doctor' ? def.doctorUserId : patientUser.id,
            senderRole: m.from === 'doctor' ? 'doctor' : 'patient',
            content: m.text,
            messageType: 'text',
            isRead: idx < def.messages.length - 1,
            createdAt: new Date(daysAgo(m.daysAgo, 10 + idx)),
          },
        });
      }
      idx++;
    }
  }

  // ---------------------------------------------------------------
  // 9. NOTIFICATIONS
  // ---------------------------------------------------------------
  const notifDefs = [
    { title: 'Rendez-vous confirmé', body: 'Votre rendez-vous avec le Dr Emilienne Tchoua est confirmé.', type: 'appointment', data: { appointmentId: upcoming.id } },
    { title: 'Résultat disponible', body: 'Votre résultat de glycémie à jeun est disponible.', type: 'medical', data: {} },
    { title: 'Message reçu', body: 'Vous avez un nouveau message du Dr Nkoulo.', type: 'message', data: { chatId: IDS.chatCardio } },
    { title: 'Ordonnance prescrite', body: 'Une nouvelle ordonnance vous a été prescrite.', type: 'medical', data: {} },
    { title: 'Nouvel accès', body: 'Le Dr Mbarga souhaite accéder à vos données.', type: 'access', data: {} },
  ];
  for (let i = 0; i < notifDefs.length; i++) {
    const n = notifDefs[i];
    const nid = oid(`demo.notif.${i}`);
    if (await prisma.notification.findFirst({ where: { id: nid } })) continue;
    await prisma.notification.create({
      data: { id: nid, userId: patientUser.id, title: n.title, body: n.body, type: n.type, data: n.data, isRead: false },
    });
  }

  // ---------------------------------------------------------------
  // 10. ACCESS CONTROL + AUDIT
  // ---------------------------------------------------------------
  const accessSeeds = [
    { id: oid('demo-access-1'), grantedToId: doctorUsers[1].id, accessLevel: 'read', accessType: 'permanent', isActive: true },
    { id: oid('demo-access-2'), grantedToId: doctorUsers[2].id, accessLevel: 'full', accessType: 'temporary', isActive: true, startDate: new Date(daysAgo(10)), endDate: new Date(now + 20 * DAYS) },
    { id: oid('demo-access-3'), grantedToId: doctorUsers[4].id, accessLevel: 'read', accessType: 'temporary', isActive: false, startDate: new Date(daysAgo(120)), endDate: new Date(daysAgo(60)) },
  ];
  for (const a of accessSeeds) {
    if (await prisma.accessManagement.findFirst({ where: { id: a.id } })) continue;
    await prisma.accessManagement.create({
      data: {
        id: a.id,
        patientId: patient.id,
        grantedById: patientUser.id,
        grantedToId: a.grantedToId,
        accessLevel: a.accessLevel,
        accessType: a.accessType,
        isActive: a.isActive,
        startDate: (a as any).startDate ?? new Date(),
        endDate: (a as any).endDate ?? null,
      },
    });
  }
  if (!(await prisma.auditLog.findFirst({ where: { id: oid('demo-audit-1') } }))) {
    await prisma.auditLog.create({
      data: { id: oid('demo-audit-1'), userId: patientUser.id, action: 'login', entity: 'auth', description: 'Connexion de démonstration' },
    });
  }

  console.log(`Damo patient ready: phone=${DEMO_PHONE} id=${patientUser.id}`);
  console.log('Demo seed complete.');
}

main()
  .catch((e) => {
    console.error('Demo seed error:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());