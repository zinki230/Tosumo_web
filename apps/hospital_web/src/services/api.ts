import axios from 'axios'

// ── Base client ──────────────────────────────────────────────────────────────
const client = axios.create({
  baseURL: '/api/v1',
  headers: { 'Content-Type': 'application/json' },
  timeout: 10_000,
})

client.interceptors.request.use((config) => {
  const token = localStorage.getItem('tosumo_token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

client.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401) {
      localStorage.removeItem('tosumo_token')
      window.location.href = '/login'
    }
    return Promise.reject(err)
  },
)

// ── Types ────────────────────────────────────────────────────────────────────
export interface Doctor {
  id: string
  firstName: string
  lastName: string
  fullName: string
  specialty: string
  licenseNumber: string
  phone: string
  email: string
  profilePhotoUrl?: string
  isVerified: boolean
  isAvailable: boolean
  averageRating: number
  totalRatings: number
  city?: string
  institution?: string
  patientCount?: number
}

export interface Patient {
  id: string
  firstName: string
  lastName: string
  fullName: string
  nin?: string
  dateOfBirth?: string
  age?: number
  gender?: string
  bloodType?: string
  phone?: string
  email?: string
  city?: string
  profilePhotoUrl?: string
  isVerified: boolean
  chronicConditions: string[]
  allergies: string[]
  treatingDoctorId?: string
  treatingDoctor?: Doctor
  lastVisit?: string
  lastAppointment?: Appointment
}

export interface Appointment {
  id: string
  patientId: string
  doctorId: string
  patientName?: string
  doctorName?: string
  appointmentDate: string
  startTime: string
  endTime: string
  type: string
  status: string
  reason?: string
}

export interface TrackingEntry {
  patient: Patient
  doctor: Doctor
  lastAppointmentDate?: string
  nextAppointmentDate?: string
  appointmentCount: number
  lastStatus: string
}

export interface DashboardStats {
  totalDoctors: number
  totalPatients: number
  totalAppointments: number
  todayAppointments: number
  verifiedPatients: number
  activeRelationships: number
}

// ── Auth ─────────────────────────────────────────────────────────────────────
export const authApi = {
  login: async (phone: string, password: string) => {
    const res = await client.post('/auth/login', { phone, password })
    const token = res.data?.data?.accessToken ?? res.data?.accessToken
    if (token) localStorage.setItem('tosumo_token', token)
    return res.data
  },
  logout: () => {
    localStorage.removeItem('tosumo_token')
  },
  isAuthenticated: () => !!localStorage.getItem('tosumo_token'),
}

// ── Doctors ──────────────────────────────────────────────────────────────────
export const doctorsApi = {
  list: async (params?: { search?: string; specialty?: string; page?: number; limit?: number }) => {
    const res = await client.get('/doctors', { params: { ...params, limit: params?.limit ?? 50 } })
    const raw: unknown[] = res.data?.data?.doctors ?? res.data?.data ?? res.data ?? []
    return raw.map(mapDoctor)
  },

  getById: async (id: string): Promise<Doctor> => {
    const res = await client.get(`/doctors/${id}`)
    return mapDoctor(res.data?.data ?? res.data)
  },

  /** All patients who had at least one appointment with this doctor */
  getPatients: async (doctorId: string): Promise<Patient[]> => {
    const res = await client.get(`/doctors/${doctorId}/patients`).catch(async () => {
      // Fallback: query appointments and extract distinct patients
      const apptRes = await client.get('/appointments', {
        params: { doctorId, limit: 200 },
      })
      return apptRes
    })
    const raw: unknown[] = res.data?.data?.patients ?? res.data?.data ?? res.data ?? []
    return raw.map(mapPatient)
  },
}

// ── Patients ─────────────────────────────────────────────────────────────────
export const patientsApi = {
  list: async (params?: { search?: string; verified?: boolean; page?: number; limit?: number }) => {
    const res = await client.get('/patients', { params: { ...params, limit: params?.limit ?? 100 } })
    const raw: unknown[] = res.data?.data?.patients ?? res.data?.data ?? res.data ?? []
    return raw.map(mapPatient)
  },

  getById: async (id: string): Promise<Patient> => {
    const res = await client.get(`/patients/${id}`)
    return mapPatient(res.data?.data ?? res.data)
  },

  getAppointments: async (patientId: string): Promise<Appointment[]> => {
    const res = await client.get('/appointments', { params: { patientId, limit: 50 } })
    const raw: unknown[] = res.data?.data?.appointments ?? res.data?.data ?? res.data ?? []
    return raw.map(mapAppointment)
  },
}

// ── Appointments ──────────────────────────────────────────────────────────────
export const appointmentsApi = {
  list: async (params?: {
    doctorId?: string
    patientId?: string
    status?: string
    startDate?: string
    endDate?: string
    limit?: number
  }) => {
    const res = await client.get('/appointments', { params: { ...params, limit: params?.limit ?? 200 } })
    const raw: unknown[] = res.data?.data?.appointments ?? res.data?.data ?? res.data ?? []
    return raw.map(mapAppointment)
  },
}

// ── Tracking ──────────────────────────────────────────────────────────────────
/**
 * Build the doctor→patient tracking table by joining appointments.
 * The "treating doctor" for a patient is the one with the most appointments.
 */
export const trackingApi = {
  getAll: async (): Promise<TrackingEntry[]> => {
    const [appointments, doctors, patients] = await Promise.all([
      appointmentsApi.list({ limit: 500 }),
      doctorsApi.list({ limit: 200 }),
      patientsApi.list({ limit: 500 }),
    ])

    const doctorMap = new Map<string, Doctor>(doctors.map((d) => [d.id, d]))
    const patientMap = new Map<string, Patient>(patients.map((p) => [p.id, p]))

    // Group appointments by (doctorId, patientId)
    type Key = string
    const groups = new Map<Key, Appointment[]>()
    for (const appt of appointments) {
      const key = `${appt.doctorId}::${appt.patientId}`
      const arr = groups.get(key) ?? []
      arr.push(appt)
      groups.set(key, arr)
    }

    const entries: TrackingEntry[] = []
    for (const [key, appts] of groups.entries()) {
      const [doctorId, patientId] = key.split('::')
      const doctor = doctorMap.get(doctorId)
      const patient = patientMap.get(patientId)
      if (!doctor || !patient) continue

      const sorted = [...appts].sort(
        (a, b) => new Date(b.appointmentDate).getTime() - new Date(a.appointmentDate).getTime(),
      )
      const last = sorted[0]
      const upcoming = sorted.filter(
        (a) => new Date(a.appointmentDate) > new Date() && a.status !== 'cancelled',
      )[0]

      entries.push({
        patient,
        doctor,
        lastAppointmentDate: last?.appointmentDate,
        nextAppointmentDate: upcoming?.appointmentDate,
        appointmentCount: appts.length,
        lastStatus: last?.status ?? 'unknown',
      })
    }

    return entries
  },

  getDashboardStats: async (): Promise<DashboardStats> => {
    // Try admin stats endpoint first, fall back to counting manually
    try {
      const res = await client.get('/admin/stats')
      const d = res.data?.data ?? res.data
      return {
        totalDoctors: d.totalDoctors ?? 0,
        totalPatients: d.totalPatients ?? 0,
        totalAppointments: d.totalAppointments ?? 0,
        todayAppointments: d.todayAppointments ?? 0,
        verifiedPatients: d.verifiedPatients ?? 0,
        activeRelationships: d.activeRelationships ?? 0,
      }
    } catch {
      const [doctors, patients, appointments] = await Promise.all([
        doctorsApi.list(),
        patientsApi.list(),
        appointmentsApi.list({ limit: 500 }),
      ])
      const today = new Date().toISOString().split('T')[0]
      return {
        totalDoctors: doctors.length,
        totalPatients: patients.length,
        totalAppointments: appointments.length,
        todayAppointments: appointments.filter((a) => a.appointmentDate.startsWith(today)).length,
        verifiedPatients: patients.filter((p) => p.isVerified).length,
        activeRelationships: new Set(appointments.map((a) => `${a.doctorId}::${a.patientId}`)).size,
      }
    }
  },
}

// ── Mappers ──────────────────────────────────────────────────────────────────
function mapDoctor(raw: unknown): Doctor {
  const r = raw as Record<string, unknown>
  const user = r['user'] as Record<string, unknown> | undefined
  const firstName =
    (r['firstName'] as string) ?? (user?.['firstName'] as string) ?? ''
  const lastName =
    (r['lastName'] as string) ?? (user?.['lastName'] as string) ?? ''
  const institutions = r['institutions'] as Array<{ institution?: { name?: string } }> | undefined
  const institution =
    institutions?.find((i) => i.institution?.name)?.institution?.name ?? undefined

  return {
    id: (r['id'] as string) ?? '',
    firstName,
    lastName,
    fullName: `${firstName} ${lastName}`.trim() || 'Médecin',
    specialty: (r['specialty'] as string) ?? '',
    licenseNumber: (r['licenseNumber'] as string) ?? '',
    phone: (user?.['phone'] as string) ?? (r['phone'] as string) ?? '',
    email: (user?.['email'] as string) ?? (r['email'] as string) ?? '',
    profilePhotoUrl: (r['profilePhotoUrl'] as string) ?? undefined,
    isVerified: (r['isVerified'] as boolean) ?? false,
    isAvailable: (r['isAvailable'] as boolean) ?? true,
    averageRating: Number(r['averageRating'] ?? 0),
    totalRatings: Number(r['totalRatings'] ?? 0),
    city: (r['city'] as string) ?? undefined,
    institution,
  }
}

function mapPatient(raw: unknown): Patient {
  const r = raw as Record<string, unknown>
  const user = r['user'] as Record<string, unknown> | undefined
  const firstName =
    (r['firstName'] as string) ?? (user?.['firstName'] as string) ?? ''
  const lastName =
    (r['lastName'] as string) ?? (user?.['lastName'] as string) ?? ''
  const dob = (r['dateOfBirth'] as string) ?? undefined
  const age = dob ? Math.floor((Date.now() - new Date(dob).getTime()) / 3.156e10) : undefined

  return {
    id: (r['id'] as string) ?? '',
    firstName,
    lastName,
    fullName: `${firstName} ${lastName}`.trim() || 'Patient',
    nin: (r['nin'] as string) ?? undefined,
    dateOfBirth: dob,
    age,
    gender: (r['gender'] as string) ?? undefined,
    bloodType: (r['bloodType'] as string) ?? undefined,
    phone: (user?.['phone'] as string) ?? (r['phone'] as string) ?? undefined,
    email: (user?.['email'] as string) ?? (r['email'] as string) ?? undefined,
    city: (r['city'] as string) ?? undefined,
    profilePhotoUrl: (r['profilePhotoUrl'] as string) ?? undefined,
    isVerified: (r['isVerified'] as boolean) ?? false,
    chronicConditions:
      ((r['chronicConditions'] as string[]) ?? (r['chronicDiseases'] as string[]) ?? []),
    allergies: (r['allergies'] as string[]) ?? [],
    lastVisit: (r['lastVisit'] as string) ?? undefined,
  }
}

function mapAppointment(raw: unknown): Appointment {
  const r = raw as Record<string, unknown>
  const patient = r['patient'] as Record<string, unknown> | undefined
  const patientUser = patient?.['user'] as Record<string, unknown> | undefined
  const doctor = r['doctor'] as Record<string, unknown> | undefined
  const doctorUser = doctor?.['user'] as Record<string, unknown> | undefined

  const pFirst = (patient?.['firstName'] as string) ?? (patientUser?.['firstName'] as string) ?? ''
  const pLast = (patient?.['lastName'] as string) ?? (patientUser?.['lastName'] as string) ?? ''
  const dFirst = (doctor?.['firstName'] as string) ?? (doctorUser?.['firstName'] as string) ?? ''
  const dLast = (doctor?.['lastName'] as string) ?? (doctorUser?.['lastName'] as string) ?? ''

  return {
    id: (r['id'] as string) ?? '',
    patientId: (r['patientId'] as string) ?? '',
    doctorId: (r['doctorId'] as string) ?? '',
    patientName: `${pFirst} ${pLast}`.trim() || undefined,
    doctorName: `${dFirst} ${dLast}`.trim() || undefined,
    appointmentDate:
      (r['appointmentDate'] as string) ?? (r['date'] as string) ?? new Date().toISOString(),
    startTime: (r['startTime'] as string) ?? '',
    endTime: (r['endTime'] as string) ?? '',
    type: (r['type'] as string) ?? 'consultation',
    status: (r['status'] as string) ?? 'pending',
    reason: (r['reason'] as string) ?? undefined,
  }
}

export default client
