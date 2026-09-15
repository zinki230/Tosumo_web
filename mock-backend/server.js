const express = require('express');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  path: '/ws',
  cors: { origin: '*', credentials: true },
  pingInterval: 10000,
  pingTimeout: 5000,
});

app.use(cors({ origin: '*', credentials: true }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

const JWT_ACCESS_SECRET = 'tosumo-mock-access-secret-2024';
const JWT_REFRESH_SECRET = 'tosumo-mock-refresh-secret-2024';
const ACCESS_EXPIRY = '15m';
const REFRESH_EXPIRY = '7d';

const now = () => new Date().toISOString();
const addDays = (d, n) => { const r = new Date(d); r.setDate(r.getDate() + n); return r.toISOString(); };
const addHours = (d, n) => { const r = new Date(d); r.setHours(r.getHours() + n); return r.toISOString(); };

// ===== IN-MEMORY STORE =====
const DB = {
  users: new Map(),
  patients: new Map(),
  doctors: new Map(),
  medicalCards: new Map(),
  medicalBooklets: new Map(),
  emergencyInfos: new Map(),
  journeyEntries: new Map(),
  appointments: new Map(),
  consultations: new Map(),
  labResults: new Map(),
  imagingResults: new Map(),
  prescriptions: new Map(),
  chats: new Map(),
  chatParticipants: new Map(),
  chatMessages: new Map(),
  notifications: new Map(),
  accessGrants: new Map(),
  auditLogs: new Map(),
  institutions: new Map(),
  paymentTransactions: new Map(),
  otpStore: new Map(),
};

function genId() { return uuidv4(); }

// ===== HELPERS =====
function formatResponse(data) {
  return { success: true, data };
}

function verifyToken(token) {
  try { return jwt.verify(token, JWT_ACCESS_SECRET); } catch (_) { return null; }
}

function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, message: 'Unauthorized' });
  }
  const token = authHeader.split(' ')[1];
  const decoded = verifyToken(token);
  if (!decoded) {
    return res.status(401).json({ success: false, message: 'Invalid or expired token' });
  }
  req.user = decoded;
  next();
}

function optionalAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const decoded = verifyToken(authHeader.split(' ')[1]);
    if (decoded) req.user = decoded;
  }
  next();
}

function getUserById(id) {
  return DB.users.get(id) || null;
}

function getPatientByUserId(userId) {
  for (const p of DB.patients.values()) {
    if (p.userId === userId) return p;
  }
  return null;
}

function getDoctorByUserId(userId) {
  for (const d of DB.doctors.values()) {
    if (d.userId === userId) return d;
  }
  return null;
}

function generateTokens(payload) {
  const accessToken = jwt.sign(payload, JWT_ACCESS_SECRET, { expiresIn: ACCESS_EXPIRY });
  const refreshToken = jwt.sign(payload, JWT_REFRESH_SECRET, { expiresIn: REFRESH_EXPIRY });
  return { accessToken, refreshToken };
}

function createAuditLog(userId, action, entity, entityId, description) {
  const log = {
    id: genId(), userId, action, entity, entityId, description,
    ipAddress: '127.0.0.1', userAgent: 'TOSUMO-Mock',
    createdAt: now(),
  };
  DB.auditLogs.set(log.id, log);
  return log;
}

function createNotification(userId, type, title, body) {
  const notif = {
    id: genId(), userId, title, body, type, isRead: false,
    data: {}, readAt: null, imageUrl: null, actionUrl: null,
    createdAt: now(), updatedAt: now(),
  };
  DB.notifications.set(notif.id, notif);
  const user = getUserById(userId);
  if (user) {
    io.to(`user:${userId}`).emit('notification:new', notif);
  }
  return notif;
}

function sendSocketEvent(userId, event, data) {
  io.to(`user:${userId}`).emit(event, data);
}

// ===== SOCKET.IO =====
io.use((socket, next) => {
  const token = socket.handshake.auth?.token || socket.handshake.query?.token;
  if (!token) return next(new Error('Authentication required'));
  const decoded = verifyToken(token);
  if (!decoded) return next(new Error('Invalid token'));
  socket.userId = decoded.userId;
  socket.userRole = decoded.role;
  next();
});

io.on('connection', (socket) => {
  socket.join(`user:${socket.userId}`);
  socket.on('join:chat', (chatId) => { socket.join(`chat:${chatId}`); });
  socket.on('leave:chat', (chatId) => { socket.leave(`chat:${chatId}`); });
  socket.on('typing:start', (data) => { socket.to(`chat:${data.chatId}`).emit('typing:start', data); });
  socket.on('typing:stop', (data) => { socket.to(`chat:${data.chatId}`).emit('typing:stop', data); });
  socket.on('disconnect', () => {});
});

// ===== SEED DATA =====
function toFlutterPatient(data) {
  const name = data.name || (data.email ? data.email.split('@')[0] : 'Patient');
  const email = data.email || '';
  const phone = data.phone || '+237000000000';
  return {
    id: data.id || data.userId || genId(),
    name: name,
    dateOfBirth: data.dateOfBirth || '1990-01-01T00:00:00Z',
    nationalId: data.nin || data.nationalId || 'MID-CM-0000-0000',
    contactInfo: { phone: data.emergencyContactPhone || phone, email: email },
    bloodType: data.bloodType || 'O+',
    allergies: data.allergies || [],
    chronicConditions: data.chronicDiseases || [],
    currentMeds: [],
    emergencyContact: {
      name: data.emergencyContactName || '',
      relationship: '',
      phone: data.emergencyContactPhone || '',
    },
    status: data.isOnboarded ? 'ACTIVE' : 'PENDING',
    gender: data.gender || null,
    photoUrl: data.profilePhotoUrl || null,
    city: data.city || null,
  };
}

function seedData() {
  if (DB.users.size > 0) return;

  const patientUserId = genId();
  const doctorUserId = genId();

  const patientUser = {
    id: patientUserId, email: 'russel@tosumo.cm', phone: '+237691234567',
    passwordHash: bcrypt.hashSync('Password123', 10),
    role: 'patient', isActive: true, isEmailVerified: true, isPhoneVerified: true,
    refreshToken: null, fcmToken: null,
    createdAt: '2026-01-15T08:00:00Z', updatedAt: now(),
  };
  DB.users.set(patientUser.id, patientUser);

  const patient = {
    id: genId(), userId: patientUserId,
    nin: 'MID-CM-9988-7766-5544',
    dateOfBirth: '1992-06-15T00:00:00Z', gender: 'Male',
    bloodType: 'O+', heightCm: 178, weightKg: 82,
    allergies: ['Penicillin', 'Peanuts', 'Ibuprofen'],
    chronicDiseases: ['Mild Hypertension', 'Seasonal Asthma'],
    emergencyContactName: 'Marie Tsague', emergencyContactPhone: '+237699876543',
    address: '123 Rue de la Sante', city: 'Yaounde', region: 'Centre',
    profilePhotoUrl: null, isOnboarded: true, onboardingStep: 6,
    createdAt: '2026-01-15T08:05:00Z', updatedAt: now(),
  };
  DB.patients.set(patient.id, patient);

  const medCard = {
    id: genId(), patientId: patient.id,
    cardNumber: `MC-CM-${Math.floor(1000+Math.random()*9000)}-${Math.floor(1000+Math.random()*9000)}-${Math.floor(1000+Math.random()*9000)}`,
    issueDate: '2026-01-15T08:10:00Z',
    expiryDate: '2028-01-15T08:10:00Z',
    isActive: true, qrCodeHash: `qr_${genId()}`, nfcUid: `nfc_${genId()}`,
    createdAt: '2026-01-15T08:10:00Z', updatedAt: now(),
  };
  DB.medicalCards.set(medCard.id, medCard);

  const institutions = [
    { id: genId(), name: 'Hopital Central de Yaounde', type: 'hospital', phone: '+237222234000', email: 'contact@hcy.cm', address: 'Avenue Henry Dunant', city: 'Yaounde', region: 'Centre', latitude: 3.8667, longitude: 11.5167, isVerified: true },
    { id: genId(), name: 'Clinique de la CNPS', type: 'clinic', phone: '+237222231010', email: 'info@cnps.cm', address: 'Boulevard de la Republique', city: 'Yaounde', region: 'Centre', latitude: 3.8721, longitude: 11.5214, isVerified: true },
    { id: genId(), name: 'Hopital General de Douala', type: 'hospital', phone: '+237233428000', email: 'contact@hgd.cm', address: 'Rue de l\'Hopital', city: 'Douala', region: 'Littoral', latitude: 4.0511, longitude: 9.7679, isVerified: true },
  ];
  institutions.forEach(inst => DB.institutions.set(inst.id, inst));

  const doctorUser = {
    id: doctorUserId, email: 'dr.mbarga@tosumo.cm', phone: '+237699000111',
    passwordHash: bcrypt.hashSync('Password123', 10),
    role: 'doctor', isActive: true, isEmailVerified: true, isPhoneVerified: true,
    refreshToken: null, fcmToken: null,
    createdAt: '2026-01-10T08:00:00Z', updatedAt: now(),
  };
  DB.users.set(doctorUser.id, doctorUser);

  const doctor = {
    id: genId(), userId: doctorUserId,
    title: 'Dr.', firstName: 'Jean', lastName: 'Mbarga',
    specialty: 'Cardiologie', licenseNumber: 'MD-CM-2020-0042',
    yearsOfExperience: 15, consultationFee: 25000,
    bio: 'Cardiologue interventionnel avec une expertise en cardiologie preventive et clinique. Forme a l\'Universite de Yaounde I et au CHU de Lyon.',
    isVerified: true, isAvailable: true,
    averageRating: 4.8, totalRatings: 124,
    languages: ['Francais', 'Anglais', 'Ewondo'],
    education: JSON.stringify([{ degree: 'Doctorat en Medecine', school: 'Universite de Yaounde I', year: 2008 }, { degree: 'Specialisation en Cardiologie', school: 'CHU Lyon', year: 2014 }]),
    certifications: JSON.stringify([{ name: 'Board Certifie - Cardiologie', year: 2015 }]),
    city: 'Yaounde', region: 'Centre',
    createdAt: '2026-01-10T08:05:00Z', updatedAt: now(),
  };
  DB.doctors.set(doctor.id, doctor);

  const doc2User = genId();
  DB.users.set(doc2User, {
    id: doc2User, email: 'dr.ngo@tosumo.cm', phone: '+237699000222',
    passwordHash: bcrypt.hashSync('Password123', 10),
    role: 'doctor', isActive: true, isEmailVerified: true, isPhoneVerified: true,
    fcmToken: null, createdAt: '2026-01-12T08:00:00Z', updatedAt: now(),
  });
  const doctor2 = {
    id: genId(), userId: doc2User,
    title: 'Dr.', firstName: 'Sarah', lastName: 'Ngo',
    specialty: 'Medecine Generale', licenseNumber: 'MD-CM-2021-0089',
    yearsOfExperience: 8, consultationFee: 15000,
    bio: 'Medecin generaliste avec une approche holistique de la sante.',
    isVerified: true, isAvailable: true,
    averageRating: 4.6, totalRatings: 89,
    languages: ['Francais', 'Anglais', 'Duala'],
    city: 'Yaounde', region: 'Centre',
    createdAt: '2026-01-12T08:05:00Z', updatedAt: now(),
  };
  DB.doctors.set(doctor2.id, doctor2);

  // Emergency contacts
  const ec = {
    id: genId(), patientId: patient.id,
    fullName: 'Marie Tsague', phone: '+237699876543', relationship: 'spouse', isPrimary: true,
    createdAt: '2026-01-15T08:15:00Z', updatedAt: now(),
  };
  DB.emergencyInfos.set(ec.id, ec);

  // Medical booklets
  const bookletEntries = [
    { patientId: patient.id, title: 'Consultation Cardiologie', description: 'Consultation de routine - controle tension arterielle', bookletType: 'consultation', hospitalName: 'Hopital Central de Yaounde', doctorName: 'Dr. Jean Mbarga', recordDate: addDays(now(), -7), metadata: { diagnosis: 'Hypertension controlee - Stade 1', prescription: 'Maintien du traitement actuel. Reevaluation dans 3 mois.', symptoms: 'Leger mal de tete occasionnel', doctorNotes: 'Patient adhere bien au traitement.' } },
    { patientId: patient.id, title: 'Consultation Urgence - Asthme', description: 'Crise d\'asthme legere apres exposition a la poussiere', bookletType: 'consultation', hospitalName: 'Clinique de la CNPS', doctorName: 'Dr. Sarah Ngo', recordDate: addDays(now(), -45), metadata: { diagnosis: 'Crise d\'asthme legere - allergie aux acariens', prescription: 'Ventolin Inhaler 100mcg, 2 bouffees si besoin', symptoms: 'Essoufflement, sifflements respiratoires, toux seche', doctorNotes: 'Patient stabilise apres administration de Ventolin.' } },
    { patientId: patient.id, title: 'Bilan Sanguin Annuel', description: 'Bilan complet: NFS, glycemie a jeun, bilan lipidique, fonction renale', bookletType: 'lab', hospitalName: 'Hopital General de Douala', doctorName: 'Dr. Tchinda', recordDate: addDays(now(), -90), metadata: { diagnosis: 'Bilan dans les normes - leger exces de cholesterol', prescription: 'Conseils dietetiques. Reduction graisses saturees.' } },
  ];
  bookletEntries.forEach(be => {
    const entry = { id: genId(), ...be, createdAt: now(), updatedAt: now() };
    DB.medicalBooklets.set(entry.id, entry);
  });

  // Journey entries
  const journeyEntries = [
    { patientId: patient.id, title: 'Consultation Cardiologie', description: 'Consultation de routine avec le Dr. Mbarga. TA: 130/85 mmHg.', entryType: 'consultation', referenceId: null, hospitalName: 'Hopital Central de Yaounde', doctorName: 'Dr. Jean Mbarga', entryDate: addDays(now(), -7) },
    { patientId: patient.id, title: 'Prise de sang', description: 'Bilan sanguin complet au Laboratoire Central.', entryType: 'lab', referenceId: null, hospitalName: 'Laboratoire Central', doctorName: null, entryDate: addDays(now(), -14) },
    { patientId: patient.id, title: 'Consultation Urgence', description: 'Consultation pour gene respiratoire. Diagnostic: crise d\'asthme legere.', entryType: 'emergency', referenceId: null, hospitalName: 'Clinique de la CNPS', doctorName: 'Dr. Sarah Ngo', entryDate: addDays(now(), -45) },
  ];
  journeyEntries.forEach(je => {
    const entry = { id: genId(), ...je, createdAt: now(), updatedAt: now() };
    DB.journeyEntries.set(entry.id, entry);
  });

  // Consultations
  const consultations = [
    { patientId: patient.id, doctorId: doctor.id, appointmentId: null, chiefComplaint: 'Controle de routine', historyOfPresentIllness: 'Patient suivi pour hypertension depuis 2 ans', diagnosis: 'Hypertension controlee - Stade 1', symptoms: ['Leger mal de tete occasionnel'], vitalSigns: { bloodPressureSystolic: 130, bloodPressureDiastolic: 85, heartRate: 72, temperature: 36.8, respiratoryRate: 16, oxygenSaturation: 98, weight: 82, height: 178 }, assessment: 'Patient stable', plan: 'Continuer traitement actuel. Prochain controle dans 3 mois.', notes: 'Patient adhere bien au traitement.', consultationDate: addDays(now(), -7) },
    { patientId: patient.id, doctorId: doctor2.id, appointmentId: null, chiefComplaint: 'Gene respiratoire', historyOfPresentIllness: 'Apparition brutale apres exposition a la poussiere', diagnosis: 'Crise d\'asthme legere - allergie aux acariens', symptoms: ['Essoufflement', 'Sifflements respiratoires', 'Toux seche'], vitalSigns: { bloodPressureSystolic: 118, bloodPressureDiastolic: 76, heartRate: 88, temperature: 37.0, respiratoryRate: 22, oxygenSaturation: 95, weight: 81, height: 178 }, assessment: 'Crise d\'asthme legere', plan: 'Ventolin Inhaler 100mcg, 2 bouffees si besoin. Eviter exposition a la poussiere.', notes: 'Patient stabilise apres administration de Ventolin.', consultationDate: addDays(now(), -45) },
  ];
  consultations.forEach(c => {
    const entry = { id: genId(), ...c, createdAt: now(), updatedAt: now() };
    DB.consultations.set(entry.id, entry);
  });

  // Prescriptions
  const prescriptions = [
    { patientId: patient.id, doctorId: doctor.id, medicationName: 'Lisinopril', dosage: '10mg', frequency: 'daily', duration: '90 days', route: 'oral', instructions: '1 comprime par jour, le matin', refills: 2, isActive: true, prescribedDate: addDays(now(), -90), startDate: addDays(now(), -90), endDate: addDays(now(), 0), pharmacyName: 'Pharmacie de la Sante', isFulfilled: true, fulfilledAt: addDays(now(), -88) },
    { patientId: patient.id, doctorId: doctor.id, medicationName: 'Ventolin', dosage: '100mcg', frequency: 'as_needed', duration: '30 days', route: 'inhalation', instructions: '2 bouffees en cas de gene respiratoire', refills: 3, isActive: true, prescribedDate: addDays(now(), -45), startDate: addDays(now(), -45), endDate: addDays(now(), -15), pharmacyName: 'Pharmacie Centrale', isFulfilled: true, fulfilledAt: addDays(now(), -44) },
  ];
  prescriptions.forEach(p => {
    const entry = { id: genId(), ...p, createdAt: now(), updatedAt: now() };
    DB.prescriptions.set(entry.id, entry);
  });

  // Appointments
  const appointments = [
    { patientId: patient.id, doctorId: doctor.id, institutionId: institutions[0].id, appointmentDate: addDays(now(), 1), startTime: '09:00', endTime: '09:30', durationMinutes: 30, type: 'followup', status: 'approved', reason: 'Controle de routine - suivi hypertension', notes: null, isPaid: false, amount: 25000 },
    { patientId: patient.id, doctorId: doctor2.id, institutionId: institutions[1].id, appointmentDate: addDays(now(), -7), startTime: '14:00', endTime: '14:30', durationMinutes: 30, type: 'consultation', status: 'completed', reason: 'Controle de la tension', notes: 'Patient en bonne sante', isPaid: true, amount: 15000, },
    { patientId: patient.id, doctorId: doctor.id, institutionId: institutions[0].id, appointmentDate: addDays(now(), -45), startTime: '10:00', endTime: '10:30', durationMinutes: 30, type: 'emergency', status: 'completed', reason: 'Crise d\'asthme', notes: 'Urgence traitee avec succes', isPaid: true, amount: 0 },
  ];
  appointments.forEach(a => {
    const entry = { id: genId(), ...a, createdAt: now(), updatedAt: now() };
    DB.appointments.set(entry.id, entry);
  });

  // Chat
  const chatId = genId();
  DB.chats.set(chatId, { id: chatId, isGroup: false, name: null, createdAt: addDays(now(), -30), updatedAt: now() });
  DB.chatParticipants.set(genId(), { chatId, doctorId: doctor.id, patientId: patient.id, lastReadAt: now(), isMuted: false, joinedAt: addDays(now(), -30) });

  const messages = [
    { chatId, senderId: doctorUserId, senderRole: 'doctor', content: 'Bonjour, vos resultats d\'analyse sont prets. Vous pouvez passer au cabinet quand vous voulez.', messageType: 'text', isRead: true, readAt: addHours(now(), -2), createdAt: addHours(now(), -3) },
    { chatId, senderId: patientUserId, senderRole: 'patient', content: 'Parfait docteur, je passe demain matin. Merci!', messageType: 'text', isRead: true, readAt: addHours(now(), -1), createdAt: addHours(now(), -2) },
    { chatId, senderId: doctorUserId, senderRole: 'doctor', content: 'Tres bien. N\'oubliez pas d\'etre a jeun pour les analyses.', messageType: 'text', isRead: false, readAt: null, createdAt: addHours(now(), -1) },
  ];
  messages.forEach(m => {
    DB.chatMessages.set(genId(), { id: genId(), ...m, fileUrl: null, fileSize: null, mimeType: null, isEdited: false, replyToId: null, updatedAt: m.createdAt });
  });

  // Notifications
  const notifications = [
    { userId: patientUserId, type: 'appointment', title: 'Rappel de rendez-vous', body: 'Vous avez un rendez-vous avec Dr. Mbarga demain a 09:00.', isRead: false },
    { userId: patientUserId, type: 'card_update', title: 'Carte medicale activee', body: 'Votre identite medicale TOSUMO a ete activee avec succes.', isRead: true },
    { userId: patientUserId, type: 'message', title: 'Nouveau message', body: 'Dr. Mbarga vous a envoye un message.', isRead: false },
    { userId: patientUserId, type: 'medical', title: 'Resultats disponibles', body: 'Vos resultats d\'analyses sont disponibles dans votre carnet medical.', isRead: false },
    { userId: patientUserId, type: 'system', title: 'Mise a jour disponible', body: 'Une nouvelle version de l\'application TOSUMO est disponible.', isRead: true },
  ];
  notifications.forEach((n, i) => {
    DB.notifications.set(genId(), {
      id: genId(), ...n, data: {}, readAt: n.isRead ? addDays(now(), -1) : null,
      imageUrl: null, actionUrl: null,
      createdAt: addDays(now(), -i), updatedAt: addDays(now(), -i),
    });
  });

  // Access grants
  DB.accessGrants.set(genId(), {
    id: genId(), patientId: patient.id, grantedToId: doctorUserId, grantedById: patientUserId,
    accessLevel: 'read', accessType: 'permanent', startDate: addDays(now(), -60),
    endDate: null, isActive: true, isApproved: true, reason: 'Suivi cardiologique',
    isEmergency: false, createdAt: addDays(now(), -60), updatedAt: now(),
  });

  // Lab results
  DB.labResults.set(genId(), {
    id: genId(), patientId: patient.id, doctorId: doctor.id,
    testName: 'Glycemie a jeun', testCategory: 'blood',
    resultData: { value: 5.2, unit: 'mmol/L', referenceRange: '3.9 - 6.1' },
    laboratoryName: 'Laboratoire Central', status: 'completed',
    orderedDate: addDays(now(), -14), resultDate: addDays(now(), -12),
    isAbnormal: false, notes: 'Dans les normes',
  });
  DB.labResults.set(genId(), {
    id: genId(), patientId: patient.id, doctorId: doctor.id,
    testName: 'Cholesterol Total', testCategory: 'blood',
    resultData: { value: 5.8, unit: 'mmol/L', referenceRange: '< 5.2' },
    laboratoryName: 'Laboratoire Central', status: 'completed',
    orderedDate: addDays(now(), -14), resultDate: addDays(now(), -12),
    isAbnormal: true, notes: 'Legerement eleve - conseils dietetiques',
  });
}

seedData();

// ===== AUTH ROUTES =====
app.post('/api/v1/auth/register', async (req, res) => {
  try {
    const { name, email, password, role, gender, dateOfBirth, city } = req.body;
    for (const u of DB.users.values()) {
      if (u.email === email) return res.status(409).json({ success: false, message: 'Email already registered' });
    }
    const userId = genId();
    const hashedPassword = await bcrypt.hash(password, 10);
    const user = {
      id: userId, email, phone: '+237000000000',
      passwordHash: hashedPassword, role: role || 'patient',
      isActive: true, isEmailVerified: true, isPhoneVerified: true,
      refreshToken: null, fcmToken: null,
      createdAt: now(), updatedAt: now(),
    };
    DB.users.set(userId, user);

    if (role === 'doctor') {
      const doc = {
        id: genId(), userId, title: 'Dr.', firstName: name.split(' ')[0] || name,
        lastName: name.split(' ').slice(1).join(' ') || '', specialty: 'Medecine Generale',
        licenseNumber: `MD-CM-${new Date().getFullYear()}-${Math.floor(1000 + Math.random() * 9000)}`,
        yearsOfExperience: 0, consultationFee: 0, isVerified: false, isAvailable: true,
        averageRating: 0, totalRatings: 0, languages: ['Francais'],
        bio: '', city: city || 'Yaounde', region: 'Centre',
        createdAt: now(), updatedAt: now(),
      };
      DB.doctors.set(doc.id, doc);
    } else {
      const patient = {
        id: genId(), userId, nin: `MID-CM-${Math.floor(1000+Math.random()*9000)}-${Math.floor(1000+Math.random()*9000)}-${Math.floor(1000+Math.random()*9000)}`,
        dateOfBirth: dateOfBirth ? new Date(dateOfBirth).toISOString() : null,
        gender: gender || null, bloodType: 'O+',
        allergies: [], chronicDiseases: [],
        emergencyContactName: null, emergencyContactPhone: null,
        address: null, city: city || 'Yaounde', region: 'Centre',
        isOnboarded: false, onboardingStep: 0,
        createdAt: now(), updatedAt: now(),
      };
      DB.patients.set(patient.id, patient);
    }

    const tokens = generateTokens({ userId, email, role: role || 'patient' });
    const userObj = { ...user };
    delete userObj.passwordHash;
    let patientResult = null;
    if (role !== 'doctor') {
      const rawPatient = getPatientByUserId(userId);
      patientResult = toFlutterPatient({ ...rawPatient, email: user.email, phone: user.phone });
    }
    return res.json(formatResponse({
      accessToken: tokens.accessToken, refreshToken: tokens.refreshToken,
      user: userObj, role: role || 'patient',
      patient: patientResult,
    }));
  } catch (e) {
    return res.status(500).json({ success: false, message: e.message });
  }
});

app.post('/api/v1/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    let foundUser = null;
    for (const u of DB.users.values()) {
      if (u.email === email) { foundUser = u; break; }
    }
    if (!foundUser) return res.status(401).json({ success: false, message: 'Invalid credentials' });
    const valid = await bcrypt.compare(password, foundUser.passwordHash);
    if (!valid) return res.status(401).json({ success: false, message: 'Invalid credentials' });
    if (!foundUser.isActive) return res.status(403).json({ success: false, message: 'Account deactivated' });

    const tokens = generateTokens({ userId: foundUser.id, email: foundUser.email, role: foundUser.role });
    foundUser.refreshToken = tokens.refreshToken;
    foundUser.lastLoginAt = now();

    const userObj = { ...foundUser };
    delete userObj.passwordHash;

    let patient = null;
    let doctor = null;
    if (foundUser.role === 'patient') {
      const rawPatient = getPatientByUserId(foundUser.id);
      patient = toFlutterPatient({ ...rawPatient, email: foundUser.email, phone: foundUser.phone });
    }
    if (foundUser.role === 'doctor') doctor = getDoctorByUserId(foundUser.id);

    return res.json(formatResponse({
      accessToken: tokens.accessToken, refreshToken: tokens.refreshToken,
      user: userObj, role: foundUser.role,
      patient, doctor,
    }));
  } catch (e) {
    return res.status(500).json({ success: false, message: e.message });
  }
});

app.post('/api/v1/auth/refresh', async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) return res.status(400).json({ success: false, message: 'Refresh token required' });
  try {
    const decoded = jwt.verify(refreshToken, JWT_REFRESH_SECRET);
    const user = getUserById(decoded.userId);
    if (!user) return res.status(401).json({ success: false, message: 'User not found' });
    const tokens = generateTokens({ userId: user.id, email: user.email, role: user.role });
    let patient = null;
    if (user.role === 'patient') {
      const rawPatient = getPatientByUserId(user.id);
      patient = toFlutterPatient({ ...rawPatient, email: user.email, phone: user.phone });
    }
    return res.json(formatResponse({
      accessToken: tokens.accessToken, refreshToken: tokens.refreshToken,
      patient, role: user.role,
    }));
  } catch (_) {
    return res.status(401).json({ success: false, message: 'Invalid refresh token' });
  }
});

app.post('/api/v1/auth/logout', authMiddleware, (req, res) => {
  const user = getUserById(req.user.userId);
  if (user) user.refreshToken = null;
  return res.json(formatResponse({ message: 'Logged out successfully' }));
});

app.get('/api/v1/auth/profile', authMiddleware, (req, res) => {
  const user = getUserById(req.user.userId);
  if (!user) return res.status(404).json({ success: false, message: 'User not found' });
  const { passwordHash, ...userObj } = user;
  let patient = null, doctor = null;
  if (user.role === 'patient') patient = getPatientByUserId(user.id);
  if (user.role === 'doctor') doctor = getDoctorByUserId(user.id);
  return res.json(formatResponse({ user: userObj, patient, doctor }));
});

app.put('/api/v1/auth/change-password', authMiddleware, async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  const user = getUserById(req.user.userId);
  if (!user) return res.status(404).json({ success: false, message: 'User not found' });
  const valid = await bcrypt.compare(currentPassword, user.passwordHash);
  if (!valid) return res.status(400).json({ success: false, message: 'Current password is incorrect' });
  user.passwordHash = await bcrypt.hash(newPassword, 10);
  return res.json(formatResponse({ message: 'Password changed successfully' }));
});

app.put('/api/v1/auth/fcm-token', authMiddleware, (req, res) => {
  const user = getUserById(req.user.userId);
  if (user) user.fcmToken = req.body.fcmToken;
  return res.json(formatResponse({ message: 'FCM token updated' }));
});

app.post('/api/v1/auth/send-otp', (req, res) => {
  const code = Math.floor(100000 + Math.random() * 900000).toString();
  const phone = req.body.phone;
  DB.otpStore.set(phone || 'default', { code, expiresAt: Date.now() + 600000 });
  return res.json(formatResponse({ message: 'OTP sent', debug: code }));
});

app.post('/api/v1/auth/verify-otp', (req, res) => {
  const { phone, code } = req.body;
  const stored = DB.otpStore.get(phone || 'default');
  if (!stored) return res.status(400).json({ success: false, message: 'No OTP found' });
  if (Date.now() > stored.expiresAt) return res.status(400).json({ success: false, message: 'OTP expired' });
  if (stored.code !== code) return res.status(400).json({ success: false, message: 'Invalid OTP' });
  DB.otpStore.delete(phone || 'default');
  return res.json(formatResponse({ message: 'Phone verified successfully', verified: true }));
});

// ===== PATIENT ROUTES =====
app.get('/api/v1/patients/profile', authMiddleware, (req, res) => {
  const patient = getPatientByUserId(req.user.userId);
  if (!patient) return res.status(404).json({ success: false, message: 'Patient not found' });
  const user = getUserById(req.user.userId);
  return res.json(formatResponse(toFlutterPatient({ ...patient, email: user.email, phone: user.phone })));
});

app.put('/api/v1/patients/profile', authMiddleware, (req, res) => {
  const patient = getPatientByUserId(req.user.userId);
  if (!patient) return res.status(404).json({ success: false, message: 'Patient not found' });
  const { bloodType, allergies, chronicDiseases, emergencyContactName, emergencyContactPhone, city, address } = req.body;
  if (bloodType !== undefined) patient.bloodType = bloodType;
  if (allergies !== undefined) patient.allergies = allergies;
  if (chronicDiseases !== undefined) patient.chronicDiseases = chronicDiseases;
  if (emergencyContactName !== undefined) patient.emergencyContactName = emergencyContactName;
  if (emergencyContactPhone !== undefined) patient.emergencyContactPhone = emergencyContactPhone;
  if (city !== undefined) patient.city = city;
  if (address !== undefined) patient.address = address;
  patient.updatedAt = now();
  return res.json(formatResponse({ message: 'Profile updated' }));
});

app.post('/api/v1/patients/onboard', authMiddleware, (req, res) => {
  const patient = getPatientByUserId(req.user.userId);
  if (!patient) return res.status(404).json({ success: false, message: 'Patient not found' });
  patient.isOnboarded = true;
  patient.onboardingStep = 6;
  return res.json(formatResponse({ message: 'Onboarding complete' }));
});

app.get('/api/v1/patients/medical-card', authMiddleware, (req, res) => {
  const patient = getPatientByUserId(req.user.userId);
  if (!patient) return res.status(404).json({ success: false, message: 'Patient not found' });
  for (const card of DB.medicalCards.values()) {
    if (card.patientId === patient.id) {
      return res.json(formatResponse({
        id: card.id, patientId: card.patientId,
        token: card.cardNumber, status: card.isActive ? 'ACTIVE' : 'INACTIVE',
        issuedAt: card.issueDate, expiresAt: card.expiryDate,
      }));
    }
  }
  return res.status(404).json({ success: false, message: 'No medical card found' });
});

app.get('/api/v1/patients/emergency-contacts', authMiddleware, (req, res) => {
  const patient = getPatientByUserId(req.user.userId);
  if (!patient) return res.json(formatResponse([]));
  const contacts = [];
  for (const ec of DB.emergencyInfos.values()) {
    if (ec.patientId === patient.id) contacts.push(ec);
  }
  return res.json(formatResponse(contacts));
});

app.post('/api/v1/patients/emergency-contacts', authMiddleware, (req, res) => {
  const patient = getPatientByUserId(req.user.userId);
  if (!patient) return res.status(404).json({ success: false, message: 'Patient not found' });
  const ec = { id: genId(), patientId: patient.id, ...req.body, createdAt: now(), updatedAt: now() };
  DB.emergencyInfos.set(ec.id, ec);
  return res.json(formatResponse(ec));
});

app.get('/api/v1/patients/medical-booklets', authMiddleware, (req, res) => {
  const patient = getPatientByUserId(req.user.userId);
  if (!patient) return res.json(formatResponse([]));
  const entries = [];
  for (const be of DB.medicalBooklets.values()) {
    if (be.patientId === patient.id) entries.push(be);
  }
  return res.json(formatResponse(entries.map(e => ({
    id: e.id, patientId: e.patientId,
    visitDate: e.recordDate, facility: e.hospitalName,
    summary: e.title, details: e.description,
    doctorName: e.doctorName, diagnosis: e.metadata?.diagnosis || '',
    prescription: e.metadata?.prescription || '',
    consultationType: e.bookletType, status: 'completed',
    symptoms: e.metadata?.symptoms || '', doctorNotes: e.metadata?.doctorNotes || '',
    doctorSpecialty: '', attachments: [],
  }))));
});

app.get('/api/v1/patients/journey', authMiddleware, (req, res) => {
  const patient = getPatientByUserId(req.user.userId);
  if (!patient) return res.json(formatResponse([]));
  const entries = [];
  for (const je of DB.journeyEntries.values()) {
    if (je.patientId === patient.id) entries.push(je);
  }
  return res.json(formatResponse(entries.map(e => ({
    id: e.id, patientId: e.patientId,
    date: e.entryDate, title: e.title,
    subtitle: e.hospitalName || '', description: e.description,
    category: e.entryType, icon: e.entryType === 'consultation' ? 'stethoscope' : e.entryType === 'lab' ? 'flask' : 'ambulance',
    status: 'completed', institution: e.hospitalName, doctorName: e.doctorName,
  }))));
});

app.get('/api/v1/patients/appointments', authMiddleware, (req, res) => {
  const patient = getPatientByUserId(req.user.userId);
  if (!patient) return res.json(formatResponse([]));
  const entries = [];
  for (const a of DB.appointments.values()) {
    if (a.patientId === patient.id) {
      const doc = DB.doctors.get(a.doctorId);
      const inst = DB.institutions.get(a.institutionId);
      entries.push({ ...a, doctorName: doc ? `Dr. ${doc.firstName} ${doc.lastName}` : 'Unknown', doctorSpecialty: doc?.specialty || '', hospitalName: inst?.name || '' });
    }
  }
  return res.json(formatResponse(entries));
});

app.get('/api/v1/patients/medical-records', authMiddleware, (req, res) => {
  const patient = getPatientByUserId(req.user.userId);
  if (!patient) return res.json(formatResponse({ consultations: [], labResults: [], imagingResults: [], prescriptions: [] }));
  const cons = [], labs = [], images = [], prescs = [];
  for (const c of DB.consultations.values()) if (c.patientId === patient.id) cons.push(c);
  for (const l of DB.labResults.values()) if (l.patientId === patient.id) labs.push(l);
  for (const im of DB.imagingResults.values()) if (im.patientId === patient.id) images.push(im);
  for (const p of DB.prescriptions.values()) if (p.patientId === patient.id) prescs.push(p);
  return res.json(formatResponse({ consultations: cons, labResults: labs, imagingResults: images, prescriptions: prescs }));
});

// ===== DOCTOR ROUTES =====
app.get('/api/v1/doctors', authMiddleware, (req, res) => {
  const doctors = [];
  for (const d of DB.doctors.values()) {
    if (d.isVerified) {
      const user = getUserById(d.userId);
      doctors.push({
        id: d.id, name: `${d.title || ''} ${d.firstName} ${d.lastName}`.trim(),
        specialty: d.specialty, rating: d.averageRating, reviewCount: d.totalRatings,
        yearsExperience: d.yearsOfExperience, bio: d.bio, languages: d.languages,
        hospital: d.city || '', hospitalLocation: `${d.city || ''}, ${d.region || ''}`,
        consultationFee: d.consultationFee, availableToday: d.isAvailable,
        nextAvailableSlot: addDays(now(), 1),
        reviews: [], credentials: [], expertise: [],
      });
    }
  }
  return res.json(formatResponse(doctors));
});

app.get('/api/v1/doctors/:id', authMiddleware, (req, res) => {
  const d = DB.doctors.get(req.params.id);
  if (!d) return res.status(404).json({ success: false, message: 'Doctor not found' });
  const user = getUserById(d.userId);
  return res.json(formatResponse({
    id: d.id, name: `${d.title || ''} ${d.firstName} ${d.lastName}`.trim(),
    specialty: d.specialty, rating: d.averageRating, reviewCount: d.totalRatings,
    yearsExperience: d.yearsOfExperience, patientCount: d.totalRatings * 15,
    bio: d.bio, languages: d.languages,
    hospital: d.city || '', hospitalLocation: `${d.city || ''}, ${d.region || ''}`,
    consultationFee: d.consultationFee,
    consultationTypes: ['Urgence', 'Routine', 'Suivi'],
    nextAvailableSlot: addDays(now(), 1), availableToday: d.isAvailable,
    reviews: [], credentials: [], expertise: [],
    email: user?.email || '', phone: user?.phone || '',
  }));
});

app.get('/api/v1/doctors/profile', authMiddleware, (req, res) => {
  const doctor = getDoctorByUserId(req.user.userId);
  if (!doctor) return res.status(404).json({ success: false, message: 'Doctor not found' });
  return res.json(formatResponse(doctor));
});

// ===== APPOINTMENT ROUTES =====
app.get('/api/v1/appointments/upcoming', authMiddleware, (req, res) => {
  const patient = getPatientByUserId(req.user.userId);
  if (!patient) return res.json(formatResponse([]));
  const upcoming = [];
  for (const a of DB.appointments.values()) {
    if (a.patientId === patient.id && ['pending', 'approved', 'confirmed'].includes(a.status)) {
      const doc = DB.doctors.get(a.doctorId);
      const inst = DB.institutions.get(a.institutionId);
      upcoming.push({ ...a, doctorName: doc ? `Dr. ${doc.firstName} ${doc.lastName}` : 'Unknown', doctorSpecialty: doc?.specialty || '', hospitalName: inst?.name || '' });
    }
  }
  return res.json(formatResponse(upcoming));
});

app.post('/api/v1/appointments', authMiddleware, (req, res) => {
  const patient = getPatientByUserId(req.user.userId);
  if (!patient) return res.status(404).json({ success: false, message: 'Patient not found' });
  const { doctorId, date, startTime, reason, type, doctorName, specialty, location } = req.body;
  const a = {
    id: genId(), patientId: patient.id, doctorId: doctorId || 'unknown',
    appointmentDate: date || addDays(now(), 1),
    startTime: startTime || '09:00', endTime: '09:30',
    durationMinutes: 30, type: type || 'consultation',
    status: 'approved', reason: reason || 'Consultation',
    institutionId: null, notes: null, isPaid: false, amount: 0,
    createdAt: now(), updatedAt: now(),
  };
  DB.appointments.set(a.id, a);

  const doc = DB.doctors.get(doctorId);
  if (doc) {
    sendSocketEvent(doc.userId, 'appointment:new', { ...a, doctorName: `Dr. ${doc.firstName} ${doc.lastName}` });
  }
  createNotification(req.user.userId, 'appointment', 'Rendez-vous confirme', `Votre rendez-vous avec ${doctorName || 'le medecin'} a ete confirme pour le ${date}.`);

  return res.json(formatResponse({
    id: a.id, doctorName: doctorName || 'Medecin assigne',
    specialty: specialty || 'Consultation', location: location || '',
    date: a.appointmentDate, doctorId: a.doctorId, status: 'confirmed',
  }));
});

app.get('/api/v1/appointments/:id', authMiddleware, (req, res) => {
  const a = DB.appointments.get(req.params.id);
  if (!a) return res.status(404).json({ success: false, message: 'Appointment not found' });
  return res.json(formatResponse(a));
});

app.put('/api/v1/appointments/:id/cancel', authMiddleware, (req, res) => {
  const a = DB.appointments.get(req.params.id);
  if (!a) return res.status(404).json({ success: false, message: 'Appointment not found' });
  a.status = 'cancelled';
  a.cancellationReason = req.body.reason || 'Cancelled by patient';
  a.updatedAt = now();
  const doc = DB.doctors.get(a.doctorId);
  if (doc) sendSocketEvent(doc.userId, 'appointment:cancelled', a);
  return res.json(formatResponse(a));
});

app.put('/api/v1/appointments/:id/complete', authMiddleware, (req, res) => {
  const a = DB.appointments.get(req.params.id);
  if (!a) return res.status(404).json({ success: false, message: 'Appointment not found' });
  a.status = 'completed';
  a.updatedAt = now();
  return res.json(formatResponse(a));
});

// ===== MEDICAL RECORDS ROUTES =====
app.get('/api/v1/medical-records/consultations', authMiddleware, (req, res) => {
  const patient = getPatientByUserId(req.user.userId);
  if (!patient) return res.json(formatResponse([]));
  const entries = [];
  for (const c of DB.consultations.values()) if (c.patientId === patient.id) entries.push(c);
  return res.json(formatResponse(entries));
});

app.get('/api/v1/medical-records/prescriptions', authMiddleware, (req, res) => {
  const patient = getPatientByUserId(req.user.userId);
  if (!patient) return res.json(formatResponse([]));
  const entries = [];
  for (const p of DB.prescriptions.values()) if (p.patientId === patient.id) entries.push(p);
  return res.json(formatResponse(entries));
});

app.get('/api/v1/medical-records/lab-results', authMiddleware, (req, res) => {
  const patient = getPatientByUserId(req.user.userId);
  if (!patient) return res.json(formatResponse([]));
  const entries = [];
  for (const l of DB.labResults.values()) if (l.patientId === patient.id) entries.push(l);
  return res.json(formatResponse(entries));
});

// ===== CHAT ROUTES =====
app.get('/api/v1/chat', authMiddleware, (req, res) => {
  const patient = getPatientByUserId(req.user.userId);
  const result = [];
  for (const c of DB.chats.values()) {
    for (const p of DB.chatParticipants.values()) {
      if (p.chatId === c.id && p.patientId === patient?.id) {
        const doc = DB.doctors.get(p.doctorId);
        const msgs = [];
        for (const m of DB.chatMessages.values()) if (m.chatId === c.id) msgs.push(m);
        msgs.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
        const lastMsg = msgs[0];
        const unread = msgs.filter(m => m.senderRole === 'doctor' && !m.isRead).length;
        result.push({
          id: c.id,
          participantName: doc ? `Dr. ${doc.firstName} ${doc.lastName}` : 'Medecin',
          participantRole: doc?.specialty || 'Medecin',
          participantInitials: doc ? `${doc.firstName[0]}${doc.lastName[0]}` : 'DR',
          lastMessage: lastMsg?.content || '',
          lastMessageDate: lastMsg?.createdAt || c.createdAt,
          unread,
          online: true,
          messages: msgs.reverse(),
        });
      }
    }
  }
  return res.json(formatResponse(result));
});

app.get('/api/v1/chat/unread', authMiddleware, (req, res) => {
  const patient = getPatientByUserId(req.user.userId);
  let count = 0;
  for (const p of DB.chatParticipants.values()) {
    if (p.patientId !== patient?.id) continue;
    for (const m of DB.chatMessages.values()) {
      if (m.chatId === p.chatId && m.senderRole === 'doctor' && !m.isRead) count++;
    }
  }
  return res.json(formatResponse({ count }));
});

app.post('/api/v1/chat/with/:doctorId', authMiddleware, (req, res) => {
  return res.json(formatResponse({ id: 'chat-1' }));
});

app.get('/api/v1/chat/:chatId/messages', authMiddleware, (req, res) => {
  const msgs = [];
  for (const m of DB.chatMessages.values()) {
    if (m.chatId === req.params.chatId) msgs.push(m);
  }
  msgs.sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());
  return res.json(formatResponse(msgs));
});

app.post('/api/v1/chat/:chatId/messages', authMiddleware, (req, res) => {
  const msg = {
    id: genId(), chatId: req.params.chatId,
    senderId: req.user.userId, senderRole: req.user.role,
    content: req.body.content || '',
    messageType: req.body.messageType || 'text',
    fileUrl: null, fileSize: null, mimeType: null,
    isRead: false, readAt: null, isEdited: false,
    replyToId: null, createdAt: now(), updatedAt: now(),
  };
  DB.chatMessages.set(msg.id, msg);
  io.to(`chat:${req.params.chatId}`).emit('message:new', msg);
  return res.json(formatResponse(msg));
});

app.put('/api/v1/chat/:chatId/read', authMiddleware, (req, res) => {
  for (const m of DB.chatMessages.values()) {
    if (m.chatId === req.params.chatId && m.senderRole !== req.user.role) {
      m.isRead = true;
      m.readAt = now();
    }
  }
  return res.json(formatResponse({ message: 'Messages marked as read' }));
});

// ===== NOTIFICATION ROUTES =====
app.get('/api/v1/notifications', authMiddleware, (req, res) => {
  const entries = [];
  for (const n of DB.notifications.values()) {
    if (n.userId === req.user.userId) {
      entries.push({
        id: n.id, type: n.type, title: n.title, message: n.body,
        time: n.createdAt, read: n.isRead,
      });
    }
  }
  entries.sort((a, b) => new Date(b.time).getTime() - new Date(a.time).getTime());
  return res.json(formatResponse(entries));
});

app.get('/api/v1/notifications/unread', authMiddleware, (req, res) => {
  const entries = [];
  for (const n of DB.notifications.values()) {
    if (n.userId === req.user.userId && !n.isRead) {
      entries.push({
        id: n.id, type: n.type, title: n.title, message: n.body,
        time: n.createdAt, read: false,
      });
    }
  }
  return res.json(formatResponse(entries));
});

app.get('/api/v1/notifications/unread/count', authMiddleware, (req, res) => {
  let count = 0;
  for (const n of DB.notifications.values()) {
    if (n.userId === req.user.userId && !n.isRead) count++;
  }
  return res.json(formatResponse({ count }));
});

app.put('/api/v1/notifications/:id/read', authMiddleware, (req, res) => {
  const n = DB.notifications.get(req.params.id);
  if (n && n.userId === req.user.userId) {
    n.isRead = true;
    n.readAt = now();
    sendSocketEvent(req.user.userId, 'notification:updated', { id: n.id, isRead: true });
  }
  return res.json(formatResponse({ message: 'Marked as read' }));
});

app.put('/api/v1/notifications/read-all', authMiddleware, (req, res) => {
  for (const n of DB.notifications.values()) {
    if (n.userId === req.user.userId && !n.isRead) {
      n.isRead = true;
      n.readAt = now();
    }
  }
  sendSocketEvent(req.user.userId, 'notifications:all-read', {});
  return res.json(formatResponse({ message: 'All marked as read' }));
});

// ===== ACCESS ROUTES =====
app.post('/api/v1/access/grant', authMiddleware, (req, res) => {
  const patient = getPatientByUserId(req.user.userId);
  if (!patient) return res.status(404).json({ success: false, message: 'Patient not found' });
  const grant = {
    id: genId(), patientId: patient.id,
    grantedToId: req.body.doctorId, grantedById: req.user.userId,
    accessLevel: req.body.accessLevel || 'read',
    accessType: req.body.accessType || 'temporary',
    startDate: now(), endDate: req.body.expiresAt || addDays(now(), 30),
    isActive: true, isApproved: true, reason: req.body.reason || '',
    isEmergency: false, createdAt: now(), updatedAt: now(),
  };
  DB.accessGrants.set(grant.id, grant);
  return res.json(formatResponse({
    id: grant.id, patientId: grant.patientId,
    institutionId: req.body.institutionId || '',
    institutionName: req.body.institutionName || 'Hopital',
    mode: 'MANUAL', scope: grant.accessLevel === 'full' ? 'Full access' : 'Read only',
    grantedAt: grant.startDate, expiresAt: grant.endDate, status: 'ACTIVE',
  }));
});

app.get('/api/v1/access/patient', authMiddleware, (req, res) => {
  const patient = getPatientByUserId(req.user.userId);
  if (!patient) return res.json(formatResponse([]));
  const grants = [];
  for (const g of DB.accessGrants.values()) {
    if (g.patientId === patient.id) {
      const user = getUserById(g.grantedToId);
      grants.push({
        id: g.id, patientId: g.patientId,
        institutionId: genId(), institutionName: user?.email?.split('@')[0] || 'Hopital',
        mode: 'MANUAL', scope: g.accessLevel === 'read' ? 'Read only' : 'Full access',
        grantedAt: g.startDate, expiresAt: g.endDate, status: g.isActive ? 'ACTIVE' : 'REVOKED',
      });
    }
  }
  return res.json(formatResponse(grants));
});

app.put('/api/v1/access/:id/approve', authMiddleware, (req, res) => {
  const g = DB.accessGrants.get(req.params.id);
  if (g) { g.isActive = true; g.updatedAt = now(); }
  return res.json(formatResponse({ ...g, status: 'ACTIVE' }));
});

app.put('/api/v1/access/:id/revoke', authMiddleware, (req, res) => {
  const g = DB.accessGrants.get(req.params.id);
  if (g) { g.isActive = false; g.revokedAt = now(); g.updatedAt = now(); }
  return res.json(formatResponse({ message: 'Access revoked' }));
});

// ===== EMERGENCY ROUTES =====
app.post('/api/v1/emergency/sos', authMiddleware, (req, res) => {
  const patient = getPatientByUserId(req.user.userId);
  const session = {
    id: genId(), patientId: patient?.id || req.user.userId,
    status: 'active', startedAt: now(),
    location: req.body.location || { lat: 3.8667, lng: 11.5167 },
    emergencyType: req.body.type || 'medical',
    doctorAssigned: null, hospitalAssigned: null,
    notes: req.body.notes || '',
  };
  io.emit('emergency:sos', { ...session, userId: req.user.userId });
  createNotification(req.user.userId, 'emergency', 'Alerte SOS envoyee', 'Les services d\'urgence ont ete notifies.');
  return res.json(formatResponse(session));
});

app.get('/api/v1/emergency/critical-info', authMiddleware, (req, res) => {
  const patient = getPatientByUserId(req.user.userId);
  if (!patient) return res.status(404).json({ success: false, message: 'Patient not found' });
  return res.json(formatResponse({
    name: req.user.email?.split('@')[0] || 'Patient',
    bloodType: patient.bloodType, allergies: patient.allergies,
    chronicConditions: patient.chronicDiseases,
    emergencyContact: patient.emergencyContactName,
    emergencyPhone: patient.emergencyContactPhone,
  }));
});

app.get('/api/v1/emergency/nearby-hospitals', authMiddleware, (req, res) => {
  const hospitals = [];
  for (const inst of DB.institutions.values()) {
    if (['hospital', 'clinic'].includes(inst.type)) {
      hospitals.push({
        id: inst.id, name: inst.name, address: inst.address,
        city: inst.city, phone: inst.phone, distance: '2.3 km',
        emergencyAvailable: true, openNow: true,
      });
    }
  }
  return res.json(formatResponse(hospitals));
});

// ===== INSTITUTION ROUTES =====
app.get('/api/v1/institutions', authMiddleware, (req, res) => {
  return res.json(formatResponse(Array.from(DB.institutions.values()).map(inst => ({
    id: inst.id, name: inst.name, distance: '2.3 km',
    address: inst.address || '', emergencyAvailable: true,
    digitalIdentityEnabled: true, laboratory: true, pharmacy: true,
    openNow: true, openHours: '24h/24 - 7j/7',
    averageWaitTime: '15-30 min',
    specialists: ['Cardiologue', 'Medecin generaliste'],
    acceptedInsurance: ['CNPS', 'MUTUELLE', 'PRIVE'],
    phone: inst.phone,
  }))));
});

// ===== UPLOAD ROUTE =====
app.post('/api/v1/upload', authMiddleware, (req, res) => {
  return res.json(formatResponse({ url: '/uploads/demo.pdf', filename: 'demo.pdf', mimeType: 'application/pdf', size: 1024 }));
});

// ===== SYNC ROUTE =====
app.post('/api/v1/sync', authMiddleware, (req, res) => {
  return res.json(formatResponse({ synced: true, syncTimestamp: now(), created: {}, updated: {}, deleted: {} }));
});

// ===== AUDIT LOG ROUTE =====
app.get('/api/v1/audit-logs', authMiddleware, (req, res) => {
  const logs = [];
  for (const l of DB.auditLogs.values()) {
    if (l.userId === req.user.userId) logs.push(l);
  }
  return res.json(formatResponse(logs.map(l => ({
    id: l.id, patientId: l.userId,
    accessorId: l.entity, accessorName: l.entity,
    timestamp: l.createdAt, mode: 'QR_SCAN',
    action: l.action.toUpperCase(), details: l.description,
    category: 'clinical', location: '',
    reason: '', doctorName: '', patientPresent: true,
  }))));
});

// ===== HEALTH CHECK =====
app.get('/api/v1/health', (req, res) => {
  res.json({ success: true, message: 'TOSUMO API is running', timestamp: now() });
});

// ===== START SERVER =====
const PORT = process.env.PORT || 3456;
const HOST = process.env.HOST || '0.0.0.0';

server.listen(PORT, HOST, () => {
  console.log(`\n  ╔══════════════════════════════════════════╗`);
  console.log(`  ║      TOSUMO Mock Backend v1.0.0         ║`);
  console.log(`  ╠══════════════════════════════════════════╣`);
  console.log(`  ║  Endpoint:  http://localhost:${PORT}            ║`);
  console.log(`  ║  Socket.IO: ws://localhost:${PORT}/ws           ║`);
  console.log(`  ║  Users:                                    ║`);
  console.log(`  ║    Patient:  russele@tosumo.cm             ║`);
  console.log(`  ║    Password: Password123                    ║`);
  console.log(`  ║    Doctor:   dr.mbarga@tosumo.cm            ║`);
  console.log(`  ║    Password: Password123                    ║`);
  console.log(`  ╚══════════════════════════════════════════╝\n`);
});
