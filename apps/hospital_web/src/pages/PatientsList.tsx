import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { Users, ChevronDown } from 'lucide-react'
import { patientsApi, trackingApi, type Patient } from '../services/api'
import {
  PageHeader,
  PageLoader,
  ErrorBanner,
  Avatar,
  Badge,
  SearchInput,
  EmptyState,
  VerifiedBadge,
  formatDate,
} from '../components/ui'

interface PatientRow extends Patient {
  treatingDoctorName?: string
  treatingDoctorId?: string
  treatingDoctorSpecialty?: string
  lastAppointmentDate?: string
  appointmentCount?: number
}

export default function PatientsList() {
  const [rows, setRows] = useState<PatientRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [filterVerified, setFilterVerified] = useState('')
  const [filterDoctor, setFilterDoctor] = useState('')

  useEffect(() => {
    ;(async () => {
      try {
        const [patients, tracking] = await Promise.all([
          patientsApi.list({ limit: 500 }),
          trackingApi.getAll(),
        ])

        // For each patient, pick their "main" doctor (most appointments)
        const doctorForPatient = new Map<string, {
          doctorId: string
          doctorName: string
          doctorSpecialty: string
          lastDate?: string
          count: number
        }>()

        tracking.forEach((e) => {
          const existing = doctorForPatient.get(e.patient.id)
          if (!existing || e.appointmentCount > existing.count) {
            doctorForPatient.set(e.patient.id, {
              doctorId: e.doctor.id,
              doctorName: e.doctor.fullName,
              doctorSpecialty: e.doctor.specialty,
              lastDate: e.lastAppointmentDate,
              count: e.appointmentCount,
            })
          }
        })

        setRows(
          patients.map((p) => {
            const d = doctorForPatient.get(p.id)
            return {
              ...p,
              treatingDoctorName: d?.doctorName,
              treatingDoctorId: d?.doctorId,
              treatingDoctorSpecialty: d?.doctorSpecialty,
              lastAppointmentDate: d?.lastDate,
              appointmentCount: d?.count,
            }
          }),
        )
      } catch {
        setError('Impossible de charger la liste des patients.')
      } finally {
        setLoading(false)
      }
    })()
  }, [])

  const doctorOptions = useMemo(() => {
    const map = new Map<string, string>()
    rows.forEach((r) => {
      if (r.treatingDoctorId && r.treatingDoctorName) {
        map.set(r.treatingDoctorId, `Dr ${r.treatingDoctorName}`)
      }
    })
    return Array.from(map.entries()).sort((a, b) => a[1].localeCompare(b[1]))
  }, [rows])

  const filtered = useMemo(() => {
    let list = rows
    if (search) {
      const q = search.toLowerCase()
      list = list.filter(
        (r) =>
          r.fullName.toLowerCase().includes(q) ||
          (r.nin ?? '').toLowerCase().includes(q) ||
          (r.treatingDoctorName ?? '').toLowerCase().includes(q),
      )
    }
    if (filterVerified === 'yes') list = list.filter((r) => r.isVerified)
    if (filterVerified === 'no') list = list.filter((r) => !r.isVerified)
    if (filterDoctor) list = list.filter((r) => r.treatingDoctorId === filterDoctor)
    return list
  }, [rows, search, filterVerified, filterDoctor])

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <PageHeader
        title="Patients"
        subtitle={`${filtered.length} patient${filtered.length !== 1 ? 's' : ''}`}
      />

      {error && <div className="mb-4"><ErrorBanner message={error} /></div>}

      {/* Filters */}
      <div className="card p-4 mb-5 flex flex-wrap gap-3 items-center">
        <SearchInput value={search} onChange={setSearch} placeholder="Nom, NIN, médecin…" />

        <div className="relative">
          <select
            value={filterVerified}
            onChange={(e) => setFilterVerified(e.target.value)}
            className="input pr-8 appearance-none cursor-pointer"
          >
            <option value="">Tous</option>
            <option value="yes">Vérifiés</option>
            <option value="no">Non vérifiés</option>
          </select>
          <ChevronDown size={14} className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none" />
        </div>

        <div className="relative">
          <select
            value={filterDoctor}
            onChange={(e) => setFilterDoctor(e.target.value)}
            className="input pr-8 appearance-none cursor-pointer"
          >
            <option value="">Tous les médecins</option>
            {doctorOptions.map(([id, name]) => (
              <option key={id} value={id}>{name}</option>
            ))}
          </select>
          <ChevronDown size={14} className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none" />
        </div>
      </div>

      {/* Table */}
      <div className="card overflow-hidden">
        {loading ? (
          <div className="py-12"><PageLoader /></div>
        ) : filtered.length === 0 ? (
          <EmptyState icon={Users} title="Aucun patient trouvé" />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-xs text-slate-500 bg-slate-50 border-b border-slate-200">
                  <th className="px-5 py-3 font-medium">Patient</th>
                  <th className="px-5 py-3 font-medium">Âge / Sexe</th>
                  <th className="px-5 py-3 font-medium">Statut</th>
                  <th className="px-5 py-3 font-medium">Médecin traitant</th>
                  <th className="px-5 py-3 font-medium">Spécialité</th>
                  <th className="px-5 py-3 font-medium">Dernier RDV</th>
                  <th className="px-5 py-3 font-medium text-center">RDV</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filtered.map((p) => (
                  <tr key={p.id} className="hover:bg-slate-50/70 transition-colors">
                    <td className="px-5 py-3.5">
                      <Link to={`/patients/${p.id}`} className="flex items-center gap-3 group">
                        <Avatar src={p.profilePhotoUrl} name={p.fullName} size="sm" />
                        <div>
                          <p className="font-semibold text-slate-900 group-hover:text-primary-600 transition-colors">
                            {p.fullName}
                          </p>
                          {p.nin && <p className="text-xs text-slate-400">{p.nin}</p>}
                        </div>
                      </Link>
                    </td>
                    <td className="px-5 py-3.5 text-slate-500">
                      {p.age ? `${p.age} ans` : '—'}
                      {p.gender ? ` · ${p.gender}` : ''}
                    </td>
                    <td className="px-5 py-3.5">
                      <VerifiedBadge verified={p.isVerified} />
                    </td>
                    <td className="px-5 py-3.5">
                      {p.treatingDoctorId ? (
                        <Link
                          to={`/medecins/${p.treatingDoctorId}`}
                          className="font-medium text-slate-700 hover:text-primary-600 transition-colors"
                        >
                          Dr {p.treatingDoctorName}
                        </Link>
                      ) : (
                        <span className="text-slate-400 text-xs">Non assigné</span>
                      )}
                    </td>
                    <td className="px-5 py-3.5">
                      {p.treatingDoctorSpecialty ? (
                        <Badge variant="blue">{p.treatingDoctorSpecialty}</Badge>
                      ) : '—'}
                    </td>
                    <td className="px-5 py-3.5 text-slate-500">{formatDate(p.lastAppointmentDate)}</td>
                    <td className="px-5 py-3.5 text-center">
                      {p.appointmentCount != null ? (
                        <Badge variant={p.appointmentCount >= 3 ? 'green' : 'gray'}>
                          {p.appointmentCount}
                        </Badge>
                      ) : '—'}
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
