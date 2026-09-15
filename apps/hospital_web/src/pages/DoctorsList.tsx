import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { Stethoscope, Star, ChevronDown } from 'lucide-react'
import { doctorsApi, trackingApi, type Doctor } from '../services/api'
import {
  PageHeader,
  PageLoader,
  ErrorBanner,
  Avatar,
  Badge,
  SearchInput,
  EmptyState,
  VerifiedBadge,
} from '../components/ui'

interface DoctorRow extends Doctor {
  patientCount: number
}

export default function DoctorsList() {
  const [rows, setRows] = useState<DoctorRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [filterSpecialty, setFilterSpecialty] = useState('')

  useEffect(() => {
    ;(async () => {
      try {
        const [doctors, tracking] = await Promise.all([
          doctorsApi.list({ limit: 200 }),
          trackingApi.getAll(),
        ])
        // count unique patients per doctor
        const countMap = new Map<string, Set<string>>()
        tracking.forEach((e) => {
          const s = countMap.get(e.doctor.id) ?? new Set()
          s.add(e.patient.id)
          countMap.set(e.doctor.id, s)
        })
        setRows(
          doctors.map((d) => ({ ...d, patientCount: countMap.get(d.id)?.size ?? 0 })),
        )
      } catch {
        setError('Impossible de charger la liste des médecins.')
      } finally {
        setLoading(false)
      }
    })()
  }, [])

  const specialties = useMemo(
    () => [...new Set(rows.map((r) => r.specialty).filter(Boolean))].sort(),
    [rows],
  )

  const filtered = useMemo(() => {
    let list = rows
    if (search) {
      const q = search.toLowerCase()
      list = list.filter(
        (r) =>
          r.fullName.toLowerCase().includes(q) ||
          r.specialty.toLowerCase().includes(q) ||
          r.licenseNumber.toLowerCase().includes(q),
      )
    }
    if (filterSpecialty) list = list.filter((r) => r.specialty === filterSpecialty)
    return list
  }, [rows, search, filterSpecialty])

  return (
    <div className="p-6 max-w-6xl mx-auto">
      <PageHeader
        title="Médecins"
        subtitle={`${filtered.length} médecin${filtered.length !== 1 ? 's' : ''} enregistré${filtered.length !== 1 ? 's' : ''}`}
      />

      {error && <div className="mb-4"><ErrorBanner message={error} /></div>}

      {/* Filters */}
      <div className="card p-4 mb-5 flex flex-wrap gap-3 items-center">
        <SearchInput value={search} onChange={setSearch} placeholder="Nom, spécialité, licence…" />
        <div className="relative">
          <select
            value={filterSpecialty}
            onChange={(e) => setFilterSpecialty(e.target.value)}
            className="input pr-8 appearance-none cursor-pointer"
          >
            <option value="">Toutes spécialités</option>
            {specialties.map((s) => (
              <option key={s} value={s}>{s}</option>
            ))}
          </select>
          <ChevronDown size={14} className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none" />
        </div>
      </div>

      {/* Grid */}
      {loading ? (
        <PageLoader />
      ) : filtered.length === 0 ? (
        <EmptyState icon={Stethoscope} title="Aucun médecin trouvé" subtitle="Modifiez vos critères de recherche." />
      ) : (
        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {filtered.map((doc) => (
            <Link
              key={doc.id}
              to={`/medecins/${doc.id}`}
              className="card p-5 hover:shadow-md hover:border-primary-200 transition-all group"
            >
              <div className="flex items-start gap-4">
                <Avatar src={doc.profilePhotoUrl} name={doc.fullName} size="lg" />
                <div className="min-w-0 flex-1">
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <p className="font-semibold text-slate-900 group-hover:text-primary-700 transition-colors leading-tight">
                        Dr {doc.fullName}
                      </p>
                      <p className="text-xs text-slate-500 mt-0.5">{doc.specialty || 'Généraliste'}</p>
                    </div>
                    <VerifiedBadge verified={doc.isVerified} />
                  </div>

                  <div className="mt-3 flex flex-wrap gap-2">
                    <Badge variant="blue">
                      {doc.patientCount} patient{doc.patientCount !== 1 ? 's' : ''}
                    </Badge>
                    {doc.averageRating > 0 && (
                      <Badge variant="yellow">
                        <Star size={11} className="fill-current" />
                        {doc.averageRating.toFixed(1)}
                      </Badge>
                    )}
                    {doc.isAvailable ? (
                      <Badge variant="green">Disponible</Badge>
                    ) : (
                      <Badge variant="red">Indisponible</Badge>
                    )}
                  </div>

                  {doc.institution && (
                    <p className="text-xs text-slate-400 mt-2 truncate">{doc.institution}</p>
                  )}
                </div>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  )
}
