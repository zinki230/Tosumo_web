import { useEffect, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import {
  ArrowLeft, Stethoscope, Phone, Mail, MapPin,
  Star, Shield, Calendar, Hash, Users,
} from 'lucide-react'
import { doctorsApi, trackingApi, type Doctor, type TrackingEntry } from '../services/api'
import {
  Avatar, Badge, PageLoader, ErrorBanner,
  VerifiedBadge, AppointmentStatusBadge,
  EmptyState, formatDate, formatAge,
} from '../components/ui'

export default function DoctorDetail() {
  const { id } = useParams<{ id: string }>()
  const [doctor, setDoctor] = useState<Doctor | null>(null)
  const [patients, setPatients] = useState<TrackingEntry[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    if (!id) return
    ;(async () => {
      try {
        const [doc, tracking] = await Promise.all([
          doctorsApi.getById(id),
          trackingApi.getAll(),
        ])
        setDoctor(doc)
        // Filter tracking entries for this doctor, dedup by patient
        const seen = new Set<string>()
        const entries = tracking
          .filter((e) => e.doctor.id === id)
          .filter((e) => {
            if (seen.has(e.patient.id)) return false
            seen.add(e.patient.id)
            return true
          })
          .sort((a, b) => {
            const da = a.lastAppointmentDate ? new Date(a.lastAppointmentDate).getTime() : 0
            const db = b.lastAppointmentDate ? new Date(b.lastAppointmentDate).getTime() : 0
            return db - da
          })
        setPatients(entries)
      } catch {
        setError('Impossible de charger les données du médecin.')
      } finally {
        setLoading(false)
      }
    })()
  }, [id])

  if (loading) return <div className="p-8"><PageLoader /></div>
  if (error) return <div className="p-8"><ErrorBanner message={error} /></div>
  if (!doctor) return null

  return (
    <div className="p-6 max-w-5xl mx-auto">
      {/* Back */}
      <Link to="/medecins" className="inline-flex items-center gap-1.5 text-sm text-slate-500 hover:text-primary-600 mb-5 transition-colors">
        <ArrowLeft size={15} /> Retour aux médecins
      </Link>

      {/* Profile card */}
      <div className="card p-6 mb-6">
        <div className="flex flex-col sm:flex-row items-start gap-6">
          <Avatar src={doctor.profilePhotoUrl} name={doctor.fullName} size="xl" />
          <div className="flex-1 min-w-0">
            <div className="flex flex-wrap items-start gap-3 justify-between">
              <div>
                <h1 className="text-2xl font-bold text-slate-900">Dr {doctor.fullName}</h1>
                <p className="text-slate-500 mt-0.5">{doctor.specialty || 'Médecin généraliste'}</p>
              </div>
              <VerifiedBadge verified={doctor.isVerified} />
            </div>

            <div className="grid sm:grid-cols-2 gap-x-8 gap-y-3 mt-5">
              {doctor.licenseNumber && (
                <InfoLine icon={Hash} label="Numéro de licence" value={doctor.licenseNumber} />
              )}
              {doctor.phone && (
                <InfoLine icon={Phone} label="Téléphone" value={doctor.phone} />
              )}
              {doctor.email && (
                <InfoLine icon={Mail} label="Email" value={doctor.email} />
              )}
              {doctor.city && (
                <InfoLine icon={MapPin} label="Ville" value={doctor.city} />
              )}
              {doctor.institution && (
                <InfoLine icon={Shield} label="Établissement" value={doctor.institution} />
              )}
              {doctor.averageRating > 0 && (
                <InfoLine
                  icon={Star}
                  label="Note"
                  value={`${doctor.averageRating.toFixed(1)} / 5 (${doctor.totalRatings} avis)`}
                />
              )}
            </div>

            <div className="flex flex-wrap gap-2 mt-5">
              <Badge variant={doctor.isAvailable ? 'green' : 'red'}>
                {doctor.isAvailable ? 'Disponible' : 'Indisponible'}
              </Badge>
              <Badge variant="blue">
                <Users size={11} />
                {patients.length} patient{patients.length !== 1 ? 's' : ''} suivi{patients.length !== 1 ? 's' : ''}
              </Badge>
            </div>
          </div>
        </div>
      </div>

      {/* Patients table */}
      <div className="card overflow-hidden">
        <div className="flex items-center gap-3 px-5 py-4 border-b border-slate-100">
          <Stethoscope size={16} className="text-primary-600" />
          <h2 className="text-sm font-semibold text-slate-700">
            Patients suivis — {patients.length}
          </h2>
        </div>

        {patients.length === 0 ? (
          <EmptyState
            icon={Users}
            title="Aucun patient suivi"
            subtitle="Ce médecin n'a pas encore de rendez-vous enregistrés."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-xs text-slate-500 bg-slate-50 border-b border-slate-200">
                  <th className="px-5 py-3 font-medium">Patient</th>
                  <th className="px-5 py-3 font-medium">Âge / Sexe</th>
                  <th className="px-5 py-3 font-medium">Groupe sanguin</th>
                  <th className="px-5 py-3 font-medium">Dernier RDV</th>
                  <th className="px-5 py-3 font-medium">Prochain RDV</th>
                  <th className="px-5 py-3 font-medium">Statut</th>
                  <th className="px-5 py-3 font-medium text-center">RDV</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {patients.map((e) => (
                  <tr key={e.patient.id} className="hover:bg-slate-50/70 transition-colors">
                    <td className="px-5 py-3.5">
                      <Link to={`/patients/${e.patient.id}`} className="flex items-center gap-3 group">
                        <Avatar src={e.patient.profilePhotoUrl} name={e.patient.fullName} size="sm" />
                        <div>
                          <p className="font-semibold text-slate-900 group-hover:text-primary-600 transition-colors">
                            {e.patient.fullName}
                          </p>
                          {e.patient.nin && <p className="text-xs text-slate-400">{e.patient.nin}</p>}
                        </div>
                      </Link>
                    </td>
                    <td className="px-5 py-3.5 text-slate-500">
                      {e.patient.dateOfBirth ? formatAge(e.patient.dateOfBirth) : '—'}
                      {e.patient.gender ? ` · ${e.patient.gender}` : ''}
                    </td>
                    <td className="px-5 py-3.5">
                      {e.patient.bloodType
                        ? <Badge variant="blue">{e.patient.bloodType}</Badge>
                        : <span className="text-slate-400">—</span>}
                    </td>
                    <td className="px-5 py-3.5">
                      <span className="flex items-center gap-1.5 text-slate-500">
                        <Calendar size={13} className="text-slate-400 shrink-0" />
                        {formatDate(e.lastAppointmentDate)}
                      </span>
                    </td>
                    <td className="px-5 py-3.5">
                      {e.nextAppointmentDate ? (
                        <span className="flex items-center gap-1.5 text-emerald-600 font-medium">
                          <Calendar size={13} className="shrink-0" />
                          {formatDate(e.nextAppointmentDate)}
                        </span>
                      ) : (
                        <span className="text-slate-400 text-xs">—</span>
                      )}
                    </td>
                    <td className="px-5 py-3.5">
                      <AppointmentStatusBadge status={e.lastStatus} />
                    </td>
                    <td className="px-5 py-3.5 text-center">
                      <Badge variant={e.appointmentCount >= 5 ? 'green' : 'gray'}>
                        {e.appointmentCount}
                      </Badge>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
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
    <div className="flex items-center gap-2 text-sm">
      <Icon size={14} className="text-slate-400 shrink-0" />
      <span className="text-slate-500 shrink-0">{label} :</span>
      <span className="text-slate-800 font-medium truncate">{value}</span>
    </div>
  )
}
