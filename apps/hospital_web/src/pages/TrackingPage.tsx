/**
 * Suivi Patient — la page principale.
 * Affiche une table de toutes les paires médecin/patient déduites des RDV,
 * avec filtres par médecin, par statut, et recherche textuelle.
 */
import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { GitBranch, ChevronDown, Calendar, RefreshCw } from 'lucide-react'
import { trackingApi, type TrackingEntry } from '../services/api'
import {
  PageHeader,
  PageLoader,
  ErrorBanner,
  Avatar,
  Badge,
  SearchInput,
  EmptyState,
  AppointmentStatusBadge,
  VerifiedBadge,
  formatDate,
} from '../components/ui'

export default function TrackingPage() {
  const [entries, setEntries] = useState<TrackingEntry[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [filterDoctor, setFilterDoctor] = useState('')
  const [filterStatus, setFilterStatus] = useState('')
  const [sortBy, setSortBy] = useState<'date' | 'name' | 'count'>('date')

  const load = async () => {
    setLoading(true)
    setError('')
    try {
      const data = await trackingApi.getAll()
      setEntries(data)
    } catch {
      setError('Impossible de charger les données de suivi.')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [])

  // Unique doctors for dropdown
  const doctors = useMemo(() => {
    const map = new Map<string, string>()
    entries.forEach((e) => map.set(e.doctor.id, `Dr ${e.doctor.fullName}`))
    return Array.from(map.entries()).sort((a, b) => a[1].localeCompare(b[1]))
  }, [entries])

  const filtered = useMemo(() => {
    let list = entries
    if (search) {
      const q = search.toLowerCase()
      list = list.filter(
        (e) =>
          e.patient.fullName.toLowerCase().includes(q) ||
          e.doctor.fullName.toLowerCase().includes(q) ||
          e.doctor.specialty.toLowerCase().includes(q) ||
          (e.patient.nin ?? '').toLowerCase().includes(q),
      )
    }
    if (filterDoctor) list = list.filter((e) => e.doctor.id === filterDoctor)
    if (filterStatus) list = list.filter((e) => e.lastStatus === filterStatus)

    list = [...list].sort((a, b) => {
      if (sortBy === 'date') {
        return (new Date(b.lastAppointmentDate ?? 0).getTime()) -
               (new Date(a.lastAppointmentDate ?? 0).getTime())
      }
      if (sortBy === 'count') return b.appointmentCount - a.appointmentCount
      return a.patient.fullName.localeCompare(b.patient.fullName)
    })
    return list
  }, [entries, search, filterDoctor, filterStatus, sortBy])

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <PageHeader
        title="Suivi Patient"
        subtitle={`Médecin → Patient — ${filtered.length} relation${filtered.length !== 1 ? 's' : ''}`}
        actions={
          <button onClick={load} className="btn-secondary text-xs" disabled={loading}>
            <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
            Actualiser
          </button>
        }
      />

      {error && <div className="mb-4"><ErrorBanner message={error} /></div>}

      {/* Filters */}
      <div className="card p-4 mb-5 flex flex-wrap gap-3 items-center">
        <SearchInput
          value={search}
          onChange={setSearch}
          placeholder="Rechercher patient, médecin…"
        />

        <div className="relative">
          <select
            value={filterDoctor}
            onChange={(e) => setFilterDoctor(e.target.value)}
            className="input pr-8 appearance-none cursor-pointer"
          >
            <option value="">Tous les médecins</option>
            {doctors.map(([id, name]) => (
              <option key={id} value={id}>{name}</option>
            ))}
          </select>
          <ChevronDown size={14} className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none" />
        </div>

        <div className="relative">
          <select
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value)}
            className="input pr-8 appearance-none cursor-pointer"
          >
            <option value="">Tous les statuts</option>
            <option value="completed">Terminé</option>
            <option value="confirmed">Confirmé</option>
            <option value="approved">Approuvé</option>
            <option value="pending">En attente</option>
            <option value="cancelled">Annulé</option>
          </select>
          <ChevronDown size={14} className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none" />
        </div>

        <div className="relative">
          <select
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value as typeof sortBy)}
            className="input pr-8 appearance-none cursor-pointer"
          >
            <option value="date">Trier : dernier RDV</option>
            <option value="count">Trier : nb de RDV</option>
            <option value="name">Trier : nom patient</option>
          </select>
          <ChevronDown size={14} className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none" />
        </div>
      </div>

      {/* Table */}
      <div className="card overflow-hidden">
        {loading ? (
          <div className="py-12"><PageLoader /></div>
        ) : filtered.length === 0 ? (
          <EmptyState icon={GitBranch} title="Aucun suivi trouvé" subtitle="Essayez d'ajuster les filtres." />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-xs text-slate-500 bg-slate-50 border-b border-slate-200">
                  <th className="px-5 py-3 font-medium">Patient</th>
                  <th className="px-5 py-3 font-medium">Statut patient</th>
                  <th className="px-5 py-3 font-medium">Médecin traitant</th>
                  <th className="px-5 py-3 font-medium">Spécialité</th>
                  <th className="px-5 py-3 font-medium">Dernier RDV</th>
                  <th className="px-5 py-3 font-medium">Prochain RDV</th>
                  <th className="px-5 py-3 font-medium">Statut RDV</th>
                  <th className="px-5 py-3 font-medium text-center">Nb RDV</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filtered.map((entry, i) => (
                  <tr key={i} className="hover:bg-slate-50/70 transition-colors">
                    {/* Patient */}
                    <td className="px-5 py-3.5">
                      <Link to={`/patients/${entry.patient.id}`} className="flex items-center gap-3 group">
                        <Avatar src={entry.patient.profilePhotoUrl} name={entry.patient.fullName} size="sm" />
                        <div>
                          <p className="font-semibold text-slate-900 group-hover:text-primary-600 transition-colors">
                            {entry.patient.fullName}
                          </p>
                          <p className="text-xs text-slate-400">
                            {entry.patient.gender ?? ''}{entry.patient.age ? ` · ${entry.patient.age} ans` : ''}
                            {entry.patient.bloodType ? ` · ${entry.patient.bloodType}` : ''}
                          </p>
                        </div>
                      </Link>
                    </td>

                    {/* Verified */}
                    <td className="px-5 py-3.5">
                      <VerifiedBadge verified={entry.patient.isVerified} />
                    </td>

                    {/* Doctor */}
                    <td className="px-5 py-3.5">
                      <Link to={`/medecins/${entry.doctor.id}`} className="flex items-center gap-3 group">
                        <Avatar src={entry.doctor.profilePhotoUrl} name={entry.doctor.fullName} size="sm" />
                        <div>
                          <p className="font-medium text-slate-800 group-hover:text-primary-600 transition-colors">
                            Dr {entry.doctor.fullName}
                          </p>
                          {entry.doctor.institution && (
                            <p className="text-xs text-slate-400">{entry.doctor.institution}</p>
                          )}
                        </div>
                      </Link>
                    </td>

                    {/* Specialty */}
                    <td className="px-5 py-3.5">
                      {entry.doctor.specialty ? (
                        <Badge variant="blue">{entry.doctor.specialty}</Badge>
                      ) : '—'}
                    </td>

                    {/* Last appt */}
                    <td className="px-5 py-3.5">
                      <span className="flex items-center gap-1.5 text-slate-500">
                        <Calendar size={13} className="shrink-0 text-slate-400" />
                        {formatDate(entry.lastAppointmentDate)}
                      </span>
                    </td>

                    {/* Next appt */}
                    <td className="px-5 py-3.5">
                      {entry.nextAppointmentDate ? (
                        <span className="flex items-center gap-1.5 text-emerald-600 font-medium">
                          <Calendar size={13} className="shrink-0" />
                          {formatDate(entry.nextAppointmentDate)}
                        </span>
                      ) : (
                        <span className="text-slate-400 text-xs">Aucun prévu</span>
                      )}
                    </td>

                    {/* Status */}
                    <td className="px-5 py-3.5">
                      <AppointmentStatusBadge status={entry.lastStatus} />
                    </td>

                    {/* Count */}
                    <td className="px-5 py-3.5 text-center">
                      <Badge variant={entry.appointmentCount >= 5 ? 'green' : 'gray'}>
                        {entry.appointmentCount}
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
