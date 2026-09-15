export type AccessMode = 'EMERGENCY' | 'CONSENTED' | 'STANDING';

export interface Patient {
  id: string;
  name: string;
  dateOfBirth: string;
  nationalId: string;
  contactInfo: {
    phone: string;
    email: string;
  };
  bloodType: string;
  allergies: string[];
  chronicConditions: string[];
  currentMeds: string[];
  emergencyContact: {
    name: string;
    relationship: string;
    phone: string;
  };
  status: 'PENDING_ACTIVATION' | 'ACTIVE' | 'REVOKED';
  gender?: string;
  photoUrl?: string;
}

export interface PatientSummary {
  id: string;
  name: string;
  photoUrl?: string;
  currentAccessStatus: 'NONE' | 'CONSENTED' | 'STANDING' | 'EMERGENCY';
}

export interface TestRequest {
  name: string;
  status: 'Pending' | 'Completed';
}

export interface LabResult {
  testName: string;
  resultValue: string;
  referenceRange: string;
  interpretation: 'Normal' | 'Abnormal';
  dateReceived: string;
}

export interface PrescribedMedication {
  drugName: string;
  dosage: string;
  frequency: string;
  duration: string;
  instructions: string;
}

export interface DoctorSignature {
  doctorName: string;
  licenseId: string;
  hospitalName: string;
  signedAt: string;
}

export interface BookletEntry {
  id: string;
  patientId: string;
  visitDate: string;
  facility: string;
  summary: string;
  details: string;
  doctorName?: string;
  doctorSpecialty?: string;
  diagnosis?: string;
  prescription?: string;
  attachments?: number;
  status?: 'completed' | 'ongoing' | 'follow-up';
  consultationType?: 'Urgence' | 'Routine' | 'Suivi';
  symptoms?: string;
  doctorNotes?: string;
  testsRequested?: TestRequest[];
  labResults?: LabResult[];
  prescriptions?: PrescribedMedication[];
  recommendations?: string;
  signature?: DoctorSignature;
}

export interface HealthJourneyEntry {
  id: string;
  patientId: string;
  date: string;
  title: string;
  subtitle: string;
  description: string;
  category: 'identity' | 'consultation' | 'prescription' | 'lab' | 'vaccination' | 'checkup' | 'emergency' | 'recovery' | 'insurance';
  icon: string;
  status: 'completed' | 'in-progress' | 'upcoming';
  institution: string;
  doctorName?: string;
}

export interface AccessGrant {
  id: string;
  patientId: string;
  institutionId: string;
  institutionName: string;
  mode: AccessMode;
  scope: string;
  grantedAt: string;
  expiresAt: string | null;
  status: 'PENDING' | 'ACTIVE' | 'REVOKED' | 'EXPIRED';
}

export interface AuditEvent {
  id: string;
  patientId: string;
  accessorId: string;
  accessorName: string;
  timestamp: string;
  mode: AccessMode;
  action: 'VIEW' | 'GRANT' | 'REVOKE' | 'REQUEST';
  details?: string;
  category?: string;
  location?: string;
  reason?: string;
  doctorName?: string;
  patientPresent?: boolean;
}

export interface EmergencyAccessSession {
  id: string;
  doctorId: string;
  patientId: string;
  timestamp: string;
  justification: string;
  active: boolean;
}

export interface Card {
  patientId: string;
  token: string;
  status: 'ACTIVE' | 'REVOKED';
  issuedAt: string;
}

export interface ChatMessage {
  id: string;
  senderId: string;
  senderName: string;
  text: string;
  timestamp: string;
  type: 'text' | 'image' | 'audio' | 'voice' | 'document' | 'appointment' | 'prescription' | 'lab_result';
  metadata?: {
    attachmentUrl?: string;
    duration?: string;
    fileName?: string;
    fileSize?: string;
    prescriptionName?: string;
    labType?: string;
  };
}

export interface ChatConversation {
  id: string;
  participantName: string;
  participantRole: string;
  participantInitials: string;
  lastMessage: string;
  lastMessageDate: string;
  unread: number;
  online: boolean;
  messages: ChatMessage[];
}

export interface DoctorProfile {
  id: string;
  name: string;
  specialty: string;
  photoUrl?: string;
  rating: number;
  reviewCount: number;
  yearsExperience: number;
  patientCount: number;
  bio: string;
  languages: string[];
  hospital: string;
  hospitalLocation: string;
  consultationTypes: string[];
  nextAvailableSlot: string;
  availableToday: boolean;
  reviews: { name: string; rating: number; text: string; date: string }[];
  credentials: string[];
  expertise: string[];
}

export interface HospitalInfo {
  id: string;
  name: string;
  distance: string;
  address: string;
  emergencyAvailable: boolean;
  digitalIdentityEnabled: boolean;
  laboratory: boolean;
  pharmacy: boolean;
  openNow: boolean;
  openHours: string;
  averageWaitTime: string;
  specialists: string[];
  acceptedInsurance: string[];
  phone: string;
}
