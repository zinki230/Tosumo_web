import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import {
  ArrowLeft, User, Phone, Mail, MapPin,
  Droplets, AlertTriangle, Pill, Heart,
  Calendar, Stethoscope, Activity,
} from 'lucide-react'
import {
  patientsApi, trackingApi, type Patient, type Appointment, type TrackingEntry,
} from '../services/api'
import {
  Avatar, Badge, PageLoader, ErrorBanner,
  VerifiedBadge, AppointmentStatusBadge,
  EmptyState, formatDate, formatAge,
} from '../components/ui'

export default function PatientDetail() {
  const { id } = useParams<{ id: string }>()
  const [patient, setPatient] = useState<Patient | null>(null)
  const [appointments, setAppointments] = useState<Appointment[]>([])
  const [treatingDoctors, setTreatingDoctors] = useState<TrackingEntry[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    if (!id) return
    ;(async () => {
      try {
        const [p, appts, tracking] = await Promise.all([
          patientsApi.getById(id),
          patientsApi.getAppointments(id).catch(() => [] as Appointment[]),
          trackingApi.getAll(),
        ])
        setPatient(p)
        setAppointments(
          [...appts].sort(
            (a, b) => new Date(b.appointmentDate).getTime() - new Date(a.appointmentDate).getTime(),
          ),
        )
        // Doctors who follow this patient (deduped by doctor)
        const seen = new Set<string>()
        const entries = tracking
          .filter((e) => e.patient.id === id)
          .filter((e) => {
            if (seen.has(e.doctor.id)) return false
            seen.add(e.doctor.id)
            return true
          })
          .sort((a, b) => b.appointmentCount - a.appointmentCount)
        setTreatingDoctors(entries)
      } catch {
        setError('Impossible de charger les données du patient.')
      } finally {
        setLoading(false)
      }
    })()
  }, [id])

  if (loading) return <div className="p-8"><PageLoader /></div>
  if (error) return <div className="p-8"><ErrorBanner message={error} /></div>
  if (!patient) return null

  const primaryDoctor = treatingDoctors[0]

  return (
    <div className="p-6 max-w-5xl mx-auto">
      {/* Back */}
      <Link to="/patients" className="inline-flex items-center gap-1.5 text-sm text-slate-500 hover:text-primary-600 mb-5 transition-colors">
        <ArrowLeft size={15} /> Retour aux patients
      </Link>

      <div className="grid lg:grid-cols-3 gap-6">
        {/* Left col */}
        <div className="lg:col-span-1 space-y-4">
          {/* Identity card */}
          <div className="card p-5">
            <div className="flex flex-col items-center text-center mb-4">
              <Avatar src={patient.profilePhotoUrl} name={patient.fullName} size="xl" />
              <h1 className="text-lg font-bold text-slate-900 mt-3">{patient.fullName}</h1>
              {patient.nin && <p className="text-xs text-slate-400 mt-0.5">NIN : {patient.nin}</p>}
              <div className="mt-2">
                <VerifiedBadge verified={patient.isVerified} />
              </div>
            </div>

            <div className="space-y-2.5 text-sm">
              {patient.dateOfBirth && (
                <InfoLine icon={User} label="Date de naissance" value={`${formatDate(patient.dateOfBirth)} (${formatAge(patient.dateOfBirth)})`} />
              )}
              {patient.gender && (
                <InfoLine icon={User} label="Sexe" value={patient.gender} />
              )}
              {patient.phone && (
                <InfoLine icon={Phone} label="Téléphone" value={patient.phone} />
              )}
              {patient.email && (
                <InfoLine icon={Mail} label="Email" value={patient.email} />
              )}
              {patient.city && (
                <InfoLine icon={MapPin} label="Ville" value={patient.city} />
              )}
            </div>
          </div>

          {/* Medical info */}
          <div className="card p-5">
            <h3 className="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-3">
              Informations médicales
            </h3>
            <div className="space-y-3">
              {patient.bloodType && (
                <div className="flex items-center gap-2">
                  <Droplets size={14} className="text-red-400" />
                  <span className="text-sm text-slate-600">Groupe sanguin :</span>
                  <Badge variant="red">{patient.bloodType}</Badge>
                </div>
              )}
              {patient.allergies.length > 0 && (
                <div>
                  <div className="flex items-center gap-2 mb-1.5">
                    <AlertTriangle size={14} className="text-amber-400" />
                    <span className="text-sm text-slate-600">Allergies</span>
                  </div>
                  <div className="flex flex-wrap gap-1.5 pl-5">
                    {patient.allergies.map((a) => (
                      <Badge key={a} variant="yellow">{a}</Badge>
                    ))}
                  </div>
                </div>
              )}
              {patient.chronicConditions.length > 0 && (
                <div>
                  <div className="flex items-center gap-2 mb-1.5">
                    <Activity size={14} className="text-primary-400" />
                    <span className="text-sm text-slate-600">Maladies chroniques</span>
                  </div>
                  <div className="flex flex-wrap gap-1.5 pl-5">
                    {patient.chronicConditions.map((c) => (
                      <Badge key={c} variant="blue">{c}</Badge>
                    ))}
                  </div>
                </div>
              )}
              {patient.allergies.length === 0 && patient.chronicConditions.length === 0 && !patient.bloodType && (
                <p className="text-sm text-slate-400">Aucune information médicale enregistrée.</p>
              )}
            </div>
          </div>

          {/* Primary doctor */}
          {primaryDoctor && (
            <div className="card p-5 border-primary-200 bg-primary-50/30">
              <h3 className="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-3">
                Médecin principal
              </h3>
              <Link to={`/medecins/${primaryDoctor.doctor.id}`} className="flex items-center gap-3 group">
                <Avatar src={primaryDoctor.doctor.profilePhotoUrl} name={primaryDoctor.doctor.fullName} size="md" />
                <div>
                  <p className="font-semibold text-slate-900 group-hover:text-primary-600 transition-colors">
                    Dr {primaryDoctor.doctor.fullName}
                  </p>
                  <p className="text-xs text-slate-500">{primaryDoctor.doctor.specialty || 'Généraliste'}</p>
                  <p className="text-xs text-slate-400 mt-0.5">
                    {primaryDoctor.appointmentCount} RDV · dernier {formatDate(primaryDoctor.lastAppointmentDate)}
                  </p>
                </div>
              </Link>
              {treatingDoctors.length > 1 && (
                <p className="text-xs text-slate-400 mt-3">
                  + {treatingDoctors.length - 1} autre{treatingDoctors.length - 1 > 1 ? 's' : ''} médecin{treatingDoctors.length - 1 > 1 ? 's' : ''} consultant{treatingDoctors.length - 1 > 1 ? 's' : ''}
                </p>
              )}
            </div>
          )}

          {!primaryDoctor && (
            <div className="card p-5">
              <h3 className="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-2">
                Médecin traitant
              </h3>
              <p className="text-sm text-slate-400">Aucun médecin assigné.</p>
            </div>
          )}
        </div>

        {/* Right col */}
        <div className="lg:col-span-2 space-y-5">
          {/* All doctors following this patient */}
          {treatingDoctors.length > 1 && (
            <div className="card overflow-hidden">
              <div className="flex items-center gap-3 px-5 py-4 border-b border-slate-100">
                <Stethoscope size={16} className="text-primary-600" />
                <h2 className="text-sm font-semibold text-slate-700">
                  Médecins consultés ({treatingDoctors.length})
                </h2>
              </div>
              <div className="divide-y divide-slate-100">
                {treatingDoctors.map((e) => (
                  <Link
                    key={e.doctor.id}
                    to={`/medecins/${e.doctor.id}`}
                    className="flex items-center gap-4 px-5 py-3 hover:bg-slate-50 transition-colors group"
                  >
                    <Avatar src={e.doctor.profilePhotoUrl} name={e.doctor.fullName} size="sm" />
                    <div className="flex-1 min-w-0">
                      <p className="font-medium text-slate-800 group-hover:text-primary-600 transition-colors">
                        Dr {e.doctor.fullName}
                      </p>
                      <p className="text-xs text-slate-400">{e.doctor.specialty}</p>
                    </div>
                    <div className="text-right shrink-0">
                      <Badge variant="blue">{e.appointmentCount} RDV</Badge>
                      <p className="text-xs text-slate-400 mt-1">{formatDate(e.lastAppointmentDate)}</p>
                    </div>
                  </Link>
                ))}
              </div>
            </div>
          )}

          {/* Appointments history */}
          <div className="card overflow-hidden">
            <div className="flex items-center gap-3 px-5 py-4 border-b border-slate-100">
              <Calendar size={16} className="text-primary-600" />
              <h2 className="text-sm font-semibold text-slate-700">
                Historique des rendez-vous ({appointments.length})
              </h2>
            </div>

            {appointments.length === 0 ? (
              <EmptyState icon={Calendar} title="Aucun rendez-vous" subtitle="Aucun rendez-vous enregistré pour ce patient." />
            ) : (
              <div className="divide-y divide-slate-100 max-h-[480px] overflow-y-auto">
                {appointments.map((appt) => (
                  <div key={appt.id} className="flex items-center gap-4 px-5 py-3.5 hover:bg-slate-50/70 transition-colors">
                    <div className="w-10 h-10 rounded-xl bg-primary-50 flex items-center justify-center shrink-0">
                      <Stethoscope size={16} className="text-primary-600" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <p className="text-sm font-medium text-slate-800">
                          {appt.doctorName ? `Dr ${appt.doctorName}` : 'Médecin inconnu'}
                        </p>
                        <Badge variant="gray">{appt.type}</Badge>
                      </div>
                      <p className="text-xs text-slate-400 mt-0.5">
                        {formatDate(appt.appointmentDate)}
                        {appt.startTime ? ` · ${appt.startTime}` : ''}
                        {appt.reason ? ` · ${appt.reason}` : ''}
                      </p>
                    </div>
                    <AppointmentStatusBadge status={appt.status} />
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

function InfoLine({
  icon: Icon,
  label,
  value,
}: {
  icon: React.ElementType
  label: string
  value: string
}) {
  return (
    <div className="flex items-start gap-2 text-sm">
      <Icon size={14} className="text-slate-400 shrink-0 mt-0.5" />
      <span className="text-slate-500 shrink-0">{label} :</span>
      <span className="text-slate-800 font-medium">{value}</span>
    </div>
  )
}
