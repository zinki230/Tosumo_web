import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { Stethoscope, Users, CalendarCheck, GitBranch, TrendingUp, Clock } from 'lucide-react'
import { trackingApi, type DashboardStats, type TrackingEntry } from '../services/api'
import {
  StatCard,
  PageHeader,
  PageLoader,
  ErrorBanner,
  Avatar,
  Badge,
  formatDate,
  AppointmentStatusBadge,
} from '../components/ui'

export default function Dashboard() {
  const [stats, setStats] = useState<DashboardStats | null>(null)
  const [recent, setRecent] = useState<TrackingEntry[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    ;(async () => {
      try {
        const [s, tracking] = await Promise.all([
          trackingApi.getDashboardStats(),
          trackingApi.getAll(),
        ])
        setStats(s)
        // 5 most-recently-seen relationships
        const sorted = [...tracking].sort((a, b) => {
          const da = a.lastAppointmentDate ? new Date(a.lastAppointmentDate).getTime() : 0
          const db = b.lastAppointmentDate ? new Date(b.lastAppointmentDate).getTime() : 0
          return db - da
        })
        setRecent(sorted.slice(0, 8))
      } catch (e) {
        setError('Impossible de charger les données. Vérifiez que le backend est démarré.')
        console.error(e)
      } finally {
        setLoading(false)
      }
    })()
  }, [])

  if (loading) return <div className="p-8"><PageLoader /></div>

  return (
    <div className="p-6 max-w-6xl mx-auto">
      <PageHeader
        title="Tableau de bord"
        subtitle={`Vue d'ensemble — ${new Date().toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}`}
      />

      {error && <div className="mb-6"><ErrorBanner message={error} /></div>}

      {/* Stats */}
      <div className="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4 mb-8">
        <StatCard label="Médecins" value={stats?.totalDoctors ?? '—'} icon={Stethoscope} color="blue" />
        <StatCard label="Patients" value={stats?.totalPatients ?? '—'} icon={Users} color="green" />
        <StatCard label="Rendez-vous" value={stats?.totalAppointments ?? '—'} icon={CalendarCheck} color="purple" />
        <StatCard label="Aujourd'hui" value={stats?.todayAppointments ?? '—'} icon={Clock} color="orange" sub="rendez-vous" />
        <StatCard label="Vérifiés" value={stats?.verifiedPatients ?? '—'} icon={TrendingUp} color="green" sub="patients" />
        <StatCard label="Suivis actifs" value={stats?.activeRelationships ?? '—'} icon={GitBranch} color="blue" sub="paires" />
      </div>

      {/* Recent tracking table */}
      <div className="card overflow-hidden">
        <div className="flex items-center justify-between px-5 py-4 border-b border-slate-100">
          <h2 className="text-sm font-semibold text-slate-700">Activité récente — Suivi patient</h2>
          <Link to="/suivi" className="text-xs text-primary-600 hover:underline font-medium">
            Voir tout →
          </Link>
        </div>

        {recent.length === 0 ? (
          <div className="py-12 text-center text-slate-400 text-sm">Aucune donnée disponible</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-xs text-slate-500 border-b border-slate-100">
                  <th className="px-5 py-3 font-medium">Patient</th>
                  <th className="px-5 py-3 font-medium">Médecin traitant</th>
                  <th className="px-5 py-3 font-medium">Spécialité</th>
                  <th className="px-5 py-3 font-medium">Dernier RDV</th>
                  <th className="px-5 py-3 font-medium">Statut</th>
                  <th className="px-5 py-3 font-medium">Total RDV</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-50">
                {recent.map((entry, i) => (
                  <tr key={i} className="hover:bg-slate-50/60 transition-colors">
                    <td className="px-5 py-3">
                      <Link to={`/patients/${entry.patient.id}`} className="flex items-center gap-2.5 group">
                        <Avatar src={entry.patient.profilePhotoUrl} name={entry.patient.fullName} size="sm" />
                        <div>
                          <p className="font-medium text-slate-900 group-hover:text-primary-600 transition-colors">
                            {entry.patient.fullName}
                          </p>
                          {entry.patient.nin && (
                            <p className="text-xs text-slate-400">{entry.patient.nin}</p>
                          )}
                        </div>
                      </Link>
                    </td>
                    <td className="px-5 py-3">
                      <Link to={`/medecins/${entry.doctor.id}`} className="flex items-center gap-2.5 group">
                        <Avatar src={entry.doctor.profilePhotoUrl} name={entry.doctor.fullName} size="sm" />
                        <span className="font-medium text-slate-700 group-hover:text-primary-600 transition-colors">
                          Dr {entry.doctor.fullName}
                        </span>
                      </Link>
                    </td>
                    <td className="px-5 py-3 text-slate-500">{entry.doctor.specialty || '—'}</td>
                    <td className="px-5 py-3 text-slate-500">{formatDate(entry.lastAppointmentDate)}</td>
                    <td className="px-5 py-3">
                      <AppointmentStatusBadge status={entry.lastStatus} />
                    </td>
                    <td className="px-5 py-3">
                      <Badge variant="blue">{entry.appointmentCount}</Badge>
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
