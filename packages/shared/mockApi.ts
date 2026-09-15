import type {
  Patient,
  BookletEntry,
  AccessGrant,
  AuditEvent,
  EmergencyAccessSession,
  PatientSummary,
  Card,
  AccessMode,
  HealthJourneyEntry,
  DoctorProfile,
  HospitalInfo,
  ChatConversation,
  ChatMessage
} from './types';

// Utility to read and write from localStorage with a prefix to avoid collision
const LS_KEY = (key: string) => `medicard_mock_${key}`;
const LS_ACTIVE_PATIENT = 'medicard_activePatientId';

const getLS = <T>(key: string, fallback: T): T => {
  const v = localStorage.getItem(LS_KEY(key));
  return v ? JSON.parse(v) : fallback;
};

const setLS = (key: string, value: any) => {
  localStorage.setItem(LS_KEY(key), JSON.stringify(value));
  // Emit event so other tabs/apps on same domain can sync if needed (though on same port this works)
  window.dispatchEvent(new Event('mockApiUpdate'));
};

function getActivePatientId(): string {
  return localStorage.getItem(LS_ACTIVE_PATIENT) || 'patient-123';
}

function getActivePatientName(): string | null {
  const pid = getActivePatientId();
  const patients = getLS<Patient[]>('patients', []);
  const p = patients.find(pat => pat.id === pid);
  return p?.name || null;
}

const PATIENT_SENDER_ID = 'patient-dynamic';

function personalizeChatMessages(messages: ChatMessage[], patientName: string): ChatMessage[] {
  const lastName = patientName.split(' ').slice(-1)[0] || patientName;
  const title = 'M';
  const patientId = getActivePatientId();
  return messages.map(msg => {
    let text = msg.text;
    text = text.replace(/Russel Tsague/g, patientName);
    text = text.replace(/Mme Tsague/g, `Mme ${lastName}`);
    text = text.replace(/M\. Tsague/g, `${title}. ${lastName}`);
    let senderName = msg.senderName;
    let senderId = msg.senderId;
    if (msg.senderId === PATIENT_SENDER_ID) {
      senderName = patientName;
      senderId = patientId;
    }
    return { ...msg, senderId, senderName, text };
  });
}

function personalizeLastMessage(text: string, patientName: string): string {
  const lastName = patientName.split(' ').slice(-1)[0] || patientName;
  text = text.replace(/Russel Tsague/g, patientName);
  text = text.replace(/Mme Tsague/g, `Mme ${lastName}`);
  text = text.replace(/M\. Tsague/g, `M. ${lastName}`);
  return text;
}

// Seed mock data if not exists
function seedMockData() {
  if (!localStorage.getItem(LS_KEY('patients'))) {
    const defaultPatient: Patient = {
      id: 'patient-123',
      name: 'Russel Tsague',
      dateOfBirth: '1985-04-12T00:00:00Z',
      nationalId: 'MID-CM-9988-7766-5544',
      contactInfo: { phone: '+237 691 234 567', email: 'russel.tsague@tosumo.cm' },
      bloodType: 'O+',
      allergies: ['Penicillin', 'Peanuts'],
      chronicConditions: ['Hypertension'],
      currentMeds: ['Lisinopril 10mg'],
      emergencyContact: {
        name: 'Marie Tsague',
        relationship: 'Spouse',
        phone: '+237 699 876 543'
      },
      gender: 'Male',
      status: 'ACTIVE'
    };

    const defaultCard: Card = {
      patientId: 'patient-123',
      token: 'mock-qr-token-xyz789',
      status: 'ACTIVE',
      issuedAt: new Date().toISOString()
    };
    
    // Some mock booklet entries
    const booklet: BookletEntry[] = [
      { id: 'b1', patientId: 'patient-123', visitDate: '2023-01-10T09:00:00Z', facility: 'Hôpital Central de Yaoundé', summary: 'Bilan annuel', details: 'TA normale. Prescription de Lisinopril.' },
      { id: 'b2', patientId: 'patient-123', visitDate: '2022-09-05T14:30:00Z', facility: 'Hôpital Général de Douala', summary: 'Entorse cheville', details: 'Radio normale. Repos et glace recommandés.' }
    ];

    setLS('patients', [defaultPatient]);
    setLS('cards', [defaultCard]);
    setLS('booklet', booklet);
    setLS('grants', []);
    setLS('audit', []);
    setLS('emergency', []);
  }
}

seedMockData();

// ----------------------------------------------------
// PATIENT APP API
// ----------------------------------------------------

export const patientApi = {
  addNotification,
  addJourneyEvent,
  getCard: async (patientId: string): Promise<Card | null> => {
    const cards = getLS<Card[]>('cards', []);
    const active = cards.find(c => c.patientId === patientId && c.status === 'ACTIVE');
    return active || cards.filter(c => c.patientId === patientId).sort((a, b) => new Date(b.issuedAt).getTime() - new Date(a.issuedAt).getTime())[0] || null;
  },

  getPatientProfile: async (patientId: string): Promise<Patient | null> => {
    const patients = getLS<Patient[]>('patients', []);
    return patients.find(p => p.id === patientId) || null;
  },

  getMedicalBooklet: async (patientId: string): Promise<BookletEntry[]> => {
    const booklet = getLS<BookletEntry[]>('booklet', []);
    return booklet.filter(b => b.patientId === patientId).sort((a,b) => new Date(b.visitDate).getTime() - new Date(a.visitDate).getTime());
  },

  getAccessGrants: async (patientId: string): Promise<AccessGrant[]> => {
    const grants = getLS<AccessGrant[]>('grants', []);
    return grants.filter(g => g.patientId === patientId);
  },

  getAuditLog: async (patientId: string): Promise<AuditEvent[]> => {
    const logs = getLS<AuditEvent[]>('audit', []);
    return logs.filter(l => l.patientId === patientId).sort((a,b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());
  },

  requestCardReissue: async (patientId: string): Promise<Card> => {
    const cards = getLS<Card[]>('cards', []);
    const oldCard = cards.find(c => c.patientId === patientId && c.status === 'ACTIVE');
    if (oldCard) oldCard.status = 'REVOKED';

    const newCard: Card = {
      patientId,
      token: `new-qr-${Date.now()}`,
      status: 'ACTIVE',
      issuedAt: new Date().toISOString()
    };
    cards.push(newCard);
    setLS('cards', cards);
    
    // Log action
    logAudit({patientId, accessorId: patientId, accessorName: 'Patient Initiated', mode: 'STANDING', action: 'VIEW', details: 'Réémission de carte demandée'});
    return newCard;
  },

  getHealthJourney: async (patientId: string): Promise<HealthJourneyEntry[]> => {
    const journey = getLS<HealthJourneyEntry[]>('journey', []);
    return journey.filter(j => j.patientId === patientId).sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
  },

  getDoctors: async (): Promise<DoctorProfile[]> => {
    return getLS<DoctorProfile[]>('doctors', []);
  },

  getDoctorById: async (doctorId: string): Promise<DoctorProfile | null> => {
    const doctors = getLS<DoctorProfile[]>('doctors', []);
    return doctors.find(d => d.id === doctorId) || null;
  },

  getHospitals: async (): Promise<HospitalInfo[]> => {
    return getLS<HospitalInfo[]>('hospitals', []);
  },

  getChats: async (_patientId: string): Promise<ChatConversation[]> => {
    const chats = getLS<ChatConversation[]>('chats', []);
    const patientName = getActivePatientName();
    if (!patientName) return chats;
    return chats.map(chat => ({
      ...chat,
      lastMessage: personalizeLastMessage(chat.lastMessage, patientName),
      messages: personalizeChatMessages(chat.messages, patientName),
    }));
  },

  getNotifications: async (_patientId: string): Promise<any[]> => {
    return getLS<any[]>('notifications', []);
  },

  getChatById: async (chatId: string): Promise<ChatConversation | null> => {
    const chats = getLS<ChatConversation[]>('chats', []);
    const chat = chats.find(c => c.id === chatId) || null;
    if (!chat) return null;
    const patientName = getActivePatientName();
    if (!patientName) return chat;
    return {
      ...chat,
      lastMessage: personalizeLastMessage(chat.lastMessage, patientName),
      messages: personalizeChatMessages(chat.messages, patientName),
    };
  },

  approveAccessRequest: async (grantId: string): Promise<AccessGrant> => {
    const grants = getLS<AccessGrant[]>('grants', []);
    const grant = grants.find(g => g.id === grantId);
    if (!grant) throw new Error('Grant not found');
    grant.status = 'ACTIVE';
    grant.grantedAt = new Date().toISOString();
    setLS('grants', grants);
    
    logAudit({patientId: grant.patientId, accessorId: grant.institutionId, accessorName: grant.institutionName, mode: grant.mode, action: 'GRANT', details: 'Accès approuvé par le patient'});
    return grant;
  },

  revokeAccess: async (grantId: string): Promise<void> => {
    const grants = getLS<AccessGrant[]>('grants', []);
    const grant = grants.find(g => g.id === grantId);
    if (!grant) return;
    grant.status = 'REVOKED';
    setLS('grants', grants);
    
    logAudit({patientId: grant.patientId, accessorId: grant.institutionId, accessorName: grant.institutionName, mode: grant.mode, action: 'REVOKE', details: 'Accès révoqué par le patient'});
  },

  bookAppointment: async (data: {
    doctorName: string; specialty: string; location: string;
    date: Date; doctorId: string;
  }): Promise<void> => {
    const appointments = getLS<any[]>('appointments', []);
    appointments.push({
      id: `appt-${Date.now()}`,
      doctorName: data.doctorName,
      specialty: data.specialty,
      location: data.location,
      date: data.date.toISOString(),
      doctorId: data.doctorId,
      status: 'confirmed',
    });
    setLS('appointments', appointments);

    const patientName = getActivePatientName() || 'Patient';

    addNotification({
      type: 'appointment',
      title: 'Rendez-vous confirmé',
      message: `Votre rendez-vous avec ${data.doctorName} (${data.specialty}) est confirmé pour le ${data.date.toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit' })} à ${data.location}.`,
    });

    addJourneyEvent({
      category: 'checkup',
      title: `Rendez-vous avec ${data.doctorName}`,
      subtitle: data.specialty,
      description: `${data.specialty} — ${data.location}`,
      institution: data.location,
    });

    logAudit({
      patientId: getActivePatientId(),
      accessorId: getActivePatientId(),
      accessorName: patientName,
      mode: 'CONSENTED',
      action: 'GRANT',
      details: `Rendez-vous réservé : ${data.doctorName} — ${data.specialty} le ${data.date.toLocaleDateString('fr-FR')}`,
      category: 'Appointment',
    });
  }
};

// ----------------------------------------------------
// INSTITUTION APP API
// ----------------------------------------------------

export const institutionApi = {
  lookupPatientByToken: async (qrToken: string, institutionId: string): Promise<PatientSummary | null> => {
    const cards = getLS<Card[]>('cards', []);
    const activeCard = cards.find(c => c.token === qrToken && c.status === 'ACTIVE');
    if (!activeCard) return null;

    const patients = getLS<Patient[]>('patients', []);
    const p = patients.find(pat => pat.id === activeCard.patientId);
    if (!p) return null;

    // determine access status for this institution
    const grants = getLS<AccessGrant[]>('grants', []);
    const activeGrant = grants.find(g => g.patientId === p.id && g.institutionId === institutionId && g.status === 'ACTIVE');
    
    let currentAccessStatus: PatientSummary['currentAccessStatus'] = 'NONE';
    if (activeGrant) {
      currentAccessStatus = activeGrant.mode;
    }

    return {
      id: p.id,
      name: p.name,
      photoUrl: p.photoUrl,
      currentAccessStatus
    };
  },

  getPatientFullRecordIfGranted: async (patientId: string, institutionId: string): Promise<{profile: Patient, booklet: BookletEntry[]} | null> => {
    // Only return if there is an active consent or standing access, OR an active emergency session
    const grants = getLS<AccessGrant[]>('grants', []);
    const activeGrant = grants.find(g => g.patientId === patientId && g.institutionId === institutionId && g.status === 'ACTIVE');
    
    const emergency = getLS<EmergencyAccessSession[]>('emergency', []);
    const activeEmerg = emergency.find(e => e.patientId === patientId && e.active);

    if (!activeGrant && !activeEmerg) return null;

    const patients = getLS<Patient[]>('patients', []);
    const p = patients.find(pat => pat.id === patientId);
    if (!p) return null;

    const booklet = getLS<BookletEntry[]>('booklet', []);
    const patientBooklet = booklet.filter(b => b.patientId === patientId);

    // If emergency, only critical subset is typically returned, but we return the full profile and the UI filters it.
    // However, to enforce it at API level:
    if (activeEmerg && !activeGrant) {
       logAudit({patientId, accessorId: institutionId, accessorName: activeEmerg.doctorId, mode: 'EMERGENCY', action: 'VIEW', details: 'Dossier d\'urgence consulté'});
       return { profile: p, booklet: [] }; // Don't return booklet for emergency, only profile criticals
    }

    logAudit({patientId, accessorId: institutionId, accessorName: 'Institution', mode: activeGrant!.mode, action: 'VIEW', details: 'Dossier complet consulté'});
    return { profile: p, booklet: patientBooklet };
  },

  requestAccess: async (institutionId: string, institutionName: string, patientId: string, scope: string, mode: AccessMode): Promise<AccessGrant> => {
    const grants = getLS<AccessGrant[]>('grants', []);
    
    const newGrant: AccessGrant = {
      id: `grant-${Date.now()}`,
      patientId,
      institutionId,
      institutionName,
      mode,
      scope,
      grantedAt: '',
      expiresAt: mode === 'STANDING' ? null : new Date(Date.now() + 24*60*60*1000).toISOString(),
      status: 'PENDING'
    };
    
    grants.push(newGrant);
    setLS('grants', grants);

    logAudit({patientId, accessorId: institutionId, accessorName: institutionName, mode, action: 'REQUEST', details: `Accès demandé : ${scope}`});
    return newGrant;
  },

  triggerEmergencyAccess: async (doctorId: string, _institutionId: string, patientId: string, justification: string): Promise<EmergencyAccessSession> => {
    const sessions = getLS<EmergencyAccessSession[]>('emergency', []);
    
    const newSession: EmergencyAccessSession = {
      id: `emerg-${Date.now()}`,
      doctorId,
      patientId,
      timestamp: new Date().toISOString(),
      justification,
      active: true
    };

    sessions.push(newSession);
    setLS('emergency', sessions);

    logAudit({patientId, accessorId: doctorId, accessorName: `Doctor ${doctorId}`, mode: 'EMERGENCY', action: 'VIEW', details: `ACCÈS D'URGENCE DÉCLENCHÉ. Justification : ${justification}`});
    return newSession;
  },

  getInstitutionAuditLog: async (institutionId: string): Promise<AuditEvent[]> => {
    // Return logs where this institution was the accessor OR part of the institution.
    // For simplicity, any log where accessorId = institutionId or accessorName has doctorId
    const logs = getLS<AuditEvent[]>('audit', []);
    return logs.filter(l => l.accessorId === institutionId || l.mode === 'EMERGENCY').sort((a,b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());
  }
};

function logAudit(eventBase: Omit<AuditEvent, 'id' | 'timestamp'>) {
    const logs = getLS<AuditEvent[]>('audit', []);
    logs.push({
      ...eventBase,
      id: `log-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      timestamp: new Date().toISOString()
    });
    setLS('audit', logs);
}

export function addNotification(notif: { type: string; title: string; message: string }) {
  const notifications = getLS<any[]>('notifications', []);
  notifications.unshift({
    id: `notif-${Date.now()}-${Math.random().toString(36).substr(2, 6)}`,
    ...notif,
    time: new Date().toISOString(),
    read: false,
  });
  setLS('notifications', notifications);
}

export function addJourneyEvent(event: { category: HealthJourneyEntry['category']; title: string; subtitle?: string; description?: string; icon?: string; institution?: string }) {
  const journey = getLS<HealthJourneyEntry[]>('journey', []);
  journey.unshift({
    id: `journey-${Date.now()}-${Math.random().toString(36).substr(2, 6)}`,
    patientId: getActivePatientId(),
    category: event.category,
    title: event.title,
    subtitle: event.subtitle || '',
    description: event.description || '',
    icon: event.icon || '',
    date: new Date().toISOString(),
    status: 'completed',
    institution: event.institution || '',
  });
  setLS('journey', journey);
}


