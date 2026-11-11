import { useCallback, useEffect, useState } from 'react'
import { ClipboardList, RefreshCw } from 'lucide-react'
import { adminApi, type AuditLog } from '../services/api'
import { ErrorBanner, PageHeader, PageLoader, formatDate } from '../components/ui'

export default function AuditLogs() {
  const [logs, setLogs] = useState<AuditLog[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [entity, setEntity] = useState('')
  const [action, setAction] = useState('')
  const load = useCallback(async () => {
    setLoading(true); setError('')
    try { setLogs(await adminApi.auditLogs({ entity: entity || undefined, action: action || undefined })) }
    catch { setError('Le journal n’a pas pu être chargé. Cette vue est réservée aux administrateurs système.') }
    finally { setLoading(false) }
  }, [entity, action])
  useEffect(() => { void load() }, [load])
  return <div className="mx-auto max-w-7xl p-5 md:p-8">
    <PageHeader title="Journal d’audit" subtitle="Historique des opérations de gestion réalisées sur la plateforme." />
    {error && <div className="mb-4"><ErrorBanner message={error} /></div>}
    <section className="card overflow-hidden">
      <div className="flex flex-col gap-3 border-b border-slate-100 p-4 sm:flex-row">
        <label className="flex-1"><span className="mb-1 block text-xs text-slate-500">Type d’action</span><input className="input" placeholder="Ex. verify_doctor, deactivate" value={action} onChange={(e) => setAction(e.target.value)} /></label>
        <label className="flex-1"><span className="mb-1 block text-xs text-slate-500">Élément concerné</span><select className="input" value={entity} onChange={(e) => setEntity(e.target.value)}><option value="">Tous les éléments</option>{['user', 'doctor', 'patient', 'appointment', 'institution'].map((e) => <option key={e} value={e}>{e}</option>)}</select></label>
        <button onClick={() => void load()} className="btn-secondary self-end justify-center"><RefreshCw size={16} />Actualiser</button>
      </div>
      {loading ? <div className="p-10"><PageLoader /></div> : logs.length === 0 ? <div className="p-12 text-center text-sm text-slate-500"><ClipboardList size={28} className="mx-auto mb-2 text-slate-300" />Aucune opération enregistrée.</div> : <div className="overflow-x-auto"><table className="w-full text-sm"><thead className="bg-slate-50 text-left text-xs text-slate-500"><tr><th className="px-5 py-3">Date</th><th className="px-5 py-3">Administrateur</th><th className="px-5 py-3">Action</th><th className="px-5 py-3">Élément</th><th className="px-5 py-3">Détail</th></tr></thead><tbody className="divide-y divide-slate-100">{logs.map((log) => <tr key={log.id} className="align-top hover:bg-slate-50/70"><td className="whitespace-nowrap px-5 py-4 text-slate-600">{formatDate(log.createdAt)}</td><td className="px-5 py-4"><p className="font-medium text-slate-800">{log.user?.email || 'Compte administrateur'}</p><p className="text-xs text-slate-500">{log.user?.role ?? ''}</p></td><td className="px-5 py-4"><span className="rounded-md bg-primary-50 px-2 py-1 font-mono text-xs text-primary-800">{log.action}</span></td><td className="px-5 py-4 text-slate-600">{log.entity}{log.entityId ? <p className="font-mono text-[10px] text-slate-400">{log.entityId}</p> : null}</td><td className="max-w-xl px-5 py-4 text-slate-700">{log.description}</td></tr>)}</tbody></table></div>}
      {!loading && <div className="border-t border-slate-100 px-5 py-3 text-xs text-slate-500">Les 200 événements les plus récents sont disponibles.</div>}
    </section>
  </div>
}
