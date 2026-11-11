import { useCallback, useEffect, useState } from 'react'
import { Check, Search, ShieldCheck, X } from 'lucide-react'
import { adminApi, type AdminDoctor } from '../services/api'
import { Badge, ErrorBanner, PageHeader, PageLoader, formatDate } from '../components/ui'

export default function DoctorApprovals() {
  const [doctors, setDoctors] = useState<AdminDoctor[]>([])
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState<string | null>(null)
  const [error, setError] = useState('')
  const [filter, setFilter] = useState<'pending' | 'verified' | 'all'>('pending')
  const [search, setSearch] = useState('')
  const load = useCallback(async () => {
    setLoading(true); setError('')
    try { setDoctors(await adminApi.doctors()) }
    catch { setError('Les dossiers médecins n’ont pas pu être chargés. Cette vue est réservée aux administrateurs système.') }
    finally { setLoading(false) }
  }, [])
  useEffect(() => { void load() }, [load])
  async function verify(doctor: AdminDoctor, approved: boolean) {
    const enteredReason = approved ? null : window.prompt('Motif du refus (facultatif)')
    if (enteredReason === null) return
    const rejectionReason = approved ? undefined : enteredReason
    setBusy(doctor.id); setError('')
    try {
      await adminApi.verifyDoctor(doctor.id, approved, rejectionReason)
      setDoctors((current) => current.map((entry) => entry.id === doctor.id ? { ...entry, isVerified: approved } : entry))
    } catch { setError('La décision n’a pas pu être enregistrée. Réessayez.') }
    finally { setBusy(null) }
  }
  const visible = doctors.filter((doctor) => (filter === 'all' || doctor.isVerified === (filter === 'verified')) && `${doctor.firstName} ${doctor.lastName} ${doctor.specialty} ${doctor.licenseNumber} ${doctor.user?.email ?? ''}`.toLowerCase().includes(search.toLowerCase()))
  return <div className="mx-auto max-w-7xl p-5 md:p-8">
    <PageHeader title="Vérification des médecins" subtitle="Examinez les dossiers et confirmez les praticiens autorisés sur TOSUMO." />
    {error && <div className="mb-4"><ErrorBanner message={error} /></div>}
    <section className="card overflow-hidden">
      <div className="flex flex-col gap-3 border-b border-slate-100 p-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex gap-2">{([['pending', 'À vérifier'], ['verified', 'Vérifiés'], ['all', 'Tous']] as const).map(([key, label]) => <button key={key} className={filter === key ? 'rounded-lg bg-primary-600 px-3 py-2 text-sm font-medium text-white' : 'rounded-lg px-3 py-2 text-sm font-medium text-slate-600 hover:bg-slate-100'} onClick={() => setFilter(key)}>{label}{key === 'pending' ? ` (${doctors.filter((d) => !d.isVerified).length})` : ''}</button>)}</div>
        <label className="relative sm:w-80"><Search size={16} className="absolute left-3 top-2.5 text-slate-400" /><input className="input pl-9" placeholder="Nom, spécialité ou licence" value={search} onChange={(e) => setSearch(e.target.value)} /></label>
      </div>
      {loading ? <div className="p-10"><PageLoader /></div> : visible.length === 0 ? <div className="p-12 text-center text-sm text-slate-500"><ShieldCheck size={28} className="mx-auto mb-2 text-slate-300" />Aucun dossier dans cette catégorie.</div> : <div className="overflow-x-auto"><table className="w-full text-sm"><thead className="bg-slate-50 text-left text-xs text-slate-500"><tr><th className="px-5 py-3">Praticien</th><th className="px-5 py-3">Contact</th><th className="px-5 py-3">Spécialité</th><th className="px-5 py-3">Licence</th><th className="px-5 py-3">Inscription</th><th className="px-5 py-3">Décision</th></tr></thead><tbody className="divide-y divide-slate-100">{visible.map((d) => <tr key={d.id} className="hover:bg-slate-50/70"><td className="px-5 py-4 font-semibold text-slate-900">Dr {d.firstName} {d.lastName}</td><td className="px-5 py-4 text-slate-600">{d.user?.email || d.user?.phone || '—'}</td><td className="px-5 py-4 text-slate-700">{d.specialty || '—'}</td><td className="px-5 py-4 font-mono text-xs text-slate-600">{d.licenseNumber || 'Non renseignée'}</td><td className="px-5 py-4 text-slate-600">{formatDate(d.createdAt)}</td><td className="px-5 py-4">{d.isVerified ? <div className="flex items-center gap-2"><Badge variant="green"><Check size={12} />Vérifié</Badge><button disabled={busy === d.id} onClick={() => void verify(d, false)} className="btn-secondary text-red-700"><X size={14} />Retirer</button></div> : <button disabled={busy === d.id} onClick={() => void verify(d, true)} className="btn-primary"><Check size={14} />{busy === d.id ? 'Enregistrement…' : 'Approuver'}</button>}</td></tr>)}</tbody></table></div>}
    </section>
  </div>
}
