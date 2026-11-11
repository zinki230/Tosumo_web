import { useCallback, useEffect, useState } from 'react'
import { CalendarDays, Download, RefreshCw } from 'lucide-react'
import { adminApi, type AdminAppointment } from '../services/api'
import { Badge, ErrorBanner, PageHeader, PageLoader, formatDate } from '../components/ui'

const patientName = (a: AdminAppointment) => `${a.patient?.firstName ?? ''} ${a.patient?.lastName ?? ''}`.trim() || a.patient?.user?.email || 'Patient'
const doctorName = (a: AdminAppointment) => `Dr ${`${a.doctor?.firstName ?? ''} ${a.doctor?.lastName ?? ''}`.trim()}`
const statusStyle = (status: string) => ({ completed: 'green', confirmed: 'blue', approved: 'blue', pending: 'yellow', cancelled: 'red', scheduled: 'blue', rescheduled: 'gray', no_show: 'red' } as Record<string, 'green' | 'blue' | 'yellow' | 'red' | 'gray'>)[status.toLowerCase()] ?? 'gray'

export default function AdminAppointments() {
  const [items, setItems] = useState<AdminAppointment[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [status, setStatus] = useState('')
  const [startDate, setStartDate] = useState('')
  const [endDate, setEndDate] = useState('')
  const load = useCallback(async () => {
    setLoading(true); setError('')
    try { setItems(await adminApi.appointments({ status: status || undefined, startDate: startDate || undefined, endDate: endDate || undefined })) }
    catch { setError('Les rendez-vous n’ont pas pu être chargés. Vérifiez vos droits administrateur et réessayez.') }
    finally { setLoading(false) }
  }, [status, startDate, endDate])
  useEffect(() => { void load() }, [load])
  function downloadCsv() {
    const rows = [['Date', 'Patient', 'Médecin', 'Établissement', 'Statut', 'Motif'], ...items.map((a) => [a.appointmentDate, patientName(a), doctorName(a), a.institution?.name ?? '', a.status, a.reason ?? ''])]
    const content = '\uFEFF' + rows.map((row) => row.map((cell) => `"${String(cell).replace(/"/g, '""')}"`).join(';')).join('\r\n')
    const url = URL.createObjectURL(new Blob([content], { type: 'text/csv;charset=utf-8' }))
    const link = document.createElement('a'); link.href = url; link.download = 'tosumo-rendez-vous.csv'; link.click(); URL.revokeObjectURL(url)
  }
  return <div className="mx-auto max-w-7xl p-5 md:p-8">
    <div className="mb-6 flex flex-wrap items-start justify-between gap-3"><PageHeader title="Rendez-vous" subtitle="Suivez l’activité des consultations des patients et médecins." /><button onClick={downloadCsv} disabled={!items.length} className="btn-secondary"><Download size={16} />Exporter CSV</button></div>
    {error && <div className="mb-4"><ErrorBanner message={error} /></div>}
    <section className="card overflow-hidden">
      <div className="grid gap-3 border-b border-slate-100 p-4 sm:grid-cols-2 lg:grid-cols-[1fr_1fr_1fr_auto_auto]">
        <div><label className="mb-1 block text-xs text-slate-500">Statut</label><select className="input" value={status} onChange={(e) => setStatus(e.target.value)}><option value="">Tous</option>{['pending', 'confirmed', 'scheduled', 'completed', 'cancelled'].map((s) => <option key={s} value={s}>{s}</option>)}</select></div>
        <div><label className="mb-1 block text-xs text-slate-500">Du</label><input className="input" type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} /></div>
        <div><label className="mb-1 block text-xs text-slate-500">Au</label><input className="input" type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} /></div>
        <button onClick={() => void load()} className="btn-secondary self-end justify-center"><CalendarDays size={16} />Filtrer</button><button onClick={() => { setStatus(''); setStartDate(''); setEndDate('') }} className="btn-secondary self-end justify-center"><RefreshCw size={16} />Effacer</button>
      </div>
      {loading ? <div className="p-10"><PageLoader /></div> : items.length === 0 ? <div className="p-12 text-center text-sm text-slate-500">Aucun rendez-vous trouvé sur cette période.</div> : <div className="overflow-x-auto"><table className="w-full text-sm"><thead className="bg-slate-50 text-left text-xs text-slate-500"><tr><th className="px-5 py-3">Date et heure</th><th className="px-5 py-3">Patient</th><th className="px-5 py-3">Médecin</th><th className="px-5 py-3">Établissement</th><th className="px-5 py-3">Motif</th><th className="px-5 py-3">Statut</th></tr></thead><tbody className="divide-y divide-slate-100">{items.map((a) => <tr key={a.id} className="hover:bg-slate-50/70"><td className="px-5 py-4"><p className="font-medium text-slate-800">{formatDate(a.appointmentDate)}</p><p className="text-xs text-slate-500">{a.startTime ?? ''}{a.endTime ? ` – ${a.endTime}` : ''}</p></td><td className="px-5 py-4 font-medium text-slate-800">{patientName(a)}</td><td className="px-5 py-4"><p className="font-medium text-slate-800">{doctorName(a)}</p><p className="text-xs text-slate-500">{a.doctor?.specialty}</p></td><td className="px-5 py-4 text-slate-600">{a.institution?.name ?? '—'}</td><td className="max-w-xs px-5 py-4 text-slate-600">{a.reason || a.type || '—'}</td><td className="px-5 py-4"><Badge variant={statusStyle(a.status)}>{a.status}</Badge></td></tr>)}</tbody></table></div>}
      {!loading && <div className="border-t border-slate-100 px-5 py-3 text-xs text-slate-500">{items.length} rendez-vous</div>}
    </section>
  </div>
}
