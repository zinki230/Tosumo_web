import { FormEvent, useCallback, useEffect, useState } from 'react'
import { Activity, ChevronLeft, ChevronRight, ClipboardList, RefreshCw, Search, ShieldCheck } from 'lucide-react'
import { adminApi, type AuditLog, type AuditLogResult } from '../services/api'
import { Badge, ErrorBanner, PageHeader, PageLoader } from '../components/ui'

const ACTION_LABELS: Record<string, string> = {
  activate: 'Réactivation de compte',
  deactivate: 'Suspension de compte',
  verify_doctor: 'Médecin validé',
  reject_doctor: 'Médecin refusé',
  create_doctor: 'Compte médecin créé',
  login: 'Connexion administrateur',
  logout: 'Déconnexion administrateur',
}

const ROLE_LABELS: Record<string, string> = {
  admin: 'Administrateur',
  superadmin: 'Super administrateur',
  institution_admin: 'Administrateur d’établissement',
}

const ENTITY_LABELS: Record<string, string> = {
  auth: 'Authentification',
  user: 'Compte utilisateur',
  doctor: 'Médecin',
  patient: 'Patient',
  appointment: 'Rendez-vous',
  institution: 'Établissement',
}

const defaultResult: AuditLogResult = {
  logs: [],
  pagination: { page: 1, limit: 50, total: 0, totalPages: 0 },
}

function formatTimestamp(value: string) {
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? 'Date inconnue' : date.toLocaleString('fr-FR', {
    day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit',
  })
}

function ActionBadge({ action }: { action: string }) {
  const variant = action === 'deactivate' || action === 'reject_doctor' ? 'red'
    : action === 'activate' || action === 'verify_doctor' ? 'green' : 'blue'
  return <Badge variant={variant}>{ACTION_LABELS[action] ?? action.replace(/_/g, ' ')}</Badge>
}

function LogDetails({ log }: { log: AuditLog }) {
  const metadata = log.metadata && Object.keys(log.metadata).length > 0 ? log.metadata : null
  if (!metadata && !log.ipAddress && !log.userAgent) return <span className="text-slate-400">—</span>
  return <details className="max-w-lg">
    <summary className="cursor-pointer text-sm font-medium text-primary-700 hover:text-primary-900">Voir les détails</summary>
    <div className="mt-2 space-y-2 rounded-lg border border-slate-200 bg-white p-3 text-xs text-slate-600 shadow-sm">
      {metadata && <pre className="max-h-40 overflow-auto whitespace-pre-wrap break-words font-sans">{JSON.stringify(metadata, null, 2)}</pre>}
      {log.ipAddress && <p><span className="font-semibold">Adresse IP :</span> {log.ipAddress}</p>}
      {log.userAgent && <p className="break-words"><span className="font-semibold">Appareil :</span> {log.userAgent}</p>}
    </div>
  </details>
}

export default function AuditLogs() {
  const [result, setResult] = useState(defaultResult)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [page, setPage] = useState(1)
  const [refreshKey, setRefreshKey] = useState(0)
  const [draft, setDraft] = useState({ search: '', entity: '', action: '', from: '', to: '' })
  const [filters, setFilters] = useState(draft)

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const data = await adminApi.auditLogs({
        search: filters.search.trim() || undefined,
        entity: filters.entity || undefined,
        action: filters.action || undefined,
        from: filters.from || undefined,
        to: filters.to || undefined,
        page,
        limit: 50,
      })
      setResult(data ?? defaultResult)
    } catch {
      setError('Le journal n’a pas pu être chargé. Cette vue est réservée aux administrateurs système.')
    } finally {
      setLoading(false)
    }
  }, [filters, page, refreshKey])

  useEffect(() => { void load() }, [load])

  function applyFilters(event: FormEvent) {
    event.preventDefault()
    setPage(1)
    setFilters({ ...draft })
  }

  function clearFilters() {
    const cleared = { search: '', entity: '', action: '', from: '', to: '' }
    setDraft(cleared)
    setFilters(cleared)
    setPage(1)
  }

  const pageCount = Math.max(1, result.pagination.totalPages)
  const firstResult = result.pagination.total === 0 ? 0 : (page - 1) * result.pagination.limit + 1
  const lastResult = Math.min(page * result.pagination.limit, result.pagination.total)

  return <div className="mx-auto max-w-7xl p-5 md:p-8">
    <PageHeader
      title="Journal d’audit"
      subtitle="Consultez les opérations administratives récentes de votre établissement."
      actions={<button onClick={() => setRefreshKey((current) => current + 1)} disabled={loading} className="btn-secondary"><RefreshCw size={16} className={loading ? 'animate-spin' : ''} />Actualiser</button>}
    />

    <div className="mb-5 grid grid-cols-1 gap-3 sm:grid-cols-3">
      <div className="card flex items-center gap-3 p-4"><div className="rounded-xl bg-primary-50 p-3 text-primary-700"><ClipboardList size={20} /></div><div><p className="text-xs text-slate-500">Événements correspondants</p><p className="mt-0.5 text-2xl font-bold text-slate-900">{result.pagination.total.toLocaleString('fr-FR')}</p></div></div>
      <div className="card flex items-center gap-3 p-4"><div className="rounded-xl bg-emerald-50 p-3 text-emerald-700"><ShieldCheck size={20} /></div><div><p className="text-xs text-slate-500">Journal sécurisé</p><p className="mt-0.5 font-semibold text-slate-900">Données de votre établissement</p></div></div>
      <div className="card flex items-center gap-3 p-4"><div className="rounded-xl bg-violet-50 p-3 text-violet-700"><Activity size={20} /></div><div><p className="text-xs text-slate-500">Affichage</p><p className="mt-0.5 font-semibold text-slate-900">50 événements par page</p></div></div>
    </div>

    {error && <div className="mb-4"><ErrorBanner message={error} /></div>}

    <section className="card overflow-hidden">
      <form onSubmit={applyFilters} className="grid grid-cols-1 gap-3 border-b border-slate-100 p-4 sm:grid-cols-2 xl:grid-cols-6 xl:items-end">
        <label className="sm:col-span-2 xl:col-span-2"><span className="mb-1 block text-xs font-medium text-slate-500">Recherche</span><span className="relative block"><Search size={16} className="absolute left-3 top-2.5 text-slate-400" /><input className="input pl-9" placeholder="Administrateur, action, identifiant…" value={draft.search} onChange={(event) => setDraft({ ...draft, search: event.target.value })} /></span></label>
        <label><span className="mb-1 block text-xs font-medium text-slate-500">Type d’action</span><select className="input" value={draft.action} onChange={(event) => setDraft({ ...draft, action: event.target.value })}><option value="">Toutes les actions</option>{Object.entries(ACTION_LABELS).map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select></label>
        <label><span className="mb-1 block text-xs font-medium text-slate-500">Élément concerné</span><select className="input" value={draft.entity} onChange={(event) => setDraft({ ...draft, entity: event.target.value })}><option value="">Tous les éléments</option>{Object.entries(ENTITY_LABELS).map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select></label>
        <label><span className="mb-1 block text-xs font-medium text-slate-500">Du</span><input className="input" type="date" value={draft.from} onChange={(event) => setDraft({ ...draft, from: event.target.value })} /></label>
        <label><span className="mb-1 block text-xs font-medium text-slate-500">Au</span><input className="input" type="date" value={draft.to} onChange={(event) => setDraft({ ...draft, to: event.target.value })} /></label>
        <div className="flex gap-2 sm:col-span-2 xl:col-span-6 xl:justify-end"><button type="button" onClick={clearFilters} className="btn-secondary justify-center">Effacer</button><button type="submit" className="btn-primary justify-center"><Search size={16} />Filtrer</button></div>
      </form>

      {loading ? <div className="p-10"><PageLoader /></div> : result.logs.length === 0 ? <div className="p-12 text-center text-sm text-slate-500"><ClipboardList size={28} className="mx-auto mb-2 text-slate-300" />Aucune opération ne correspond à ces critères.</div> : <div className="overflow-x-auto"><table className="w-full text-sm">
        <thead className="bg-slate-50 text-left text-xs text-slate-500"><tr><th className="px-5 py-3">Date et heure</th><th className="px-5 py-3">Administrateur</th><th className="px-5 py-3">Action</th><th className="px-5 py-3">Élément</th><th className="px-5 py-3">Description</th><th className="px-5 py-3">Contexte</th></tr></thead>
        <tbody className="divide-y divide-slate-100">{result.logs.map((log: AuditLog) => <tr key={log.id} className="align-top hover:bg-slate-50/70">
          <td className="whitespace-nowrap px-5 py-4 text-slate-600">{formatTimestamp(log.createdAt)}</td>
          <td className="px-5 py-4"><p className="font-medium text-slate-800">{log.user?.email || 'Compte administrateur'}</p><p className="text-xs text-slate-500">{ROLE_LABELS[log.user?.role ?? ''] ?? log.user?.role ?? ''}</p></td>
          <td className="px-5 py-4"><ActionBadge action={log.action} /></td>
          <td className="px-5 py-4 text-slate-600">{ENTITY_LABELS[log.entity] ?? log.entity}{log.entityId && <p className="mt-1 max-w-40 truncate font-mono text-[10px] text-slate-400" title={log.entityId}>{log.entityId}</p>}</td>
          <td className="max-w-lg px-5 py-4 text-slate-700">{log.description}</td>
          <td className="px-5 py-4"><LogDetails log={log} /></td>
        </tr>)}</tbody>
      </table></div>}

      <div className="flex flex-col gap-3 border-t border-slate-100 px-5 py-3 text-xs text-slate-500 sm:flex-row sm:items-center sm:justify-between">
        <span>{firstResult}–{lastResult} sur {result.pagination.total.toLocaleString('fr-FR')} événement{result.pagination.total === 1 ? '' : 's'}</span>
        <div className="flex items-center gap-2"><button onClick={() => setPage((current) => Math.max(1, current - 1))} disabled={loading || page <= 1} className="btn-secondary px-2" aria-label="Page précédente"><ChevronLeft size={16} /></button><span>Page {Math.min(page, pageCount)} sur {pageCount}</span><button onClick={() => setPage((current) => Math.min(pageCount, current + 1))} disabled={loading || page >= pageCount} className="btn-secondary px-2" aria-label="Page suivante"><ChevronRight size={16} /></button></div>
      </div>
    </section>
  </div>
}
