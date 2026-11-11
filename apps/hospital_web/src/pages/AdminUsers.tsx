import { useCallback, useEffect, useMemo, useState } from 'react'
import { Search, Shield, UserRound, RefreshCw, Power } from 'lucide-react'
import { adminApi, type AdminUser } from '../services/api'
import { Badge, ErrorBanner, PageHeader, PageLoader, formatDate } from '../components/ui'

const roleLabel: Record<string, string> = {
  patient: 'Patient', doctor: 'Médecin', institution_admin: 'Centre de santé', admin: 'Administrateur', superadmin: 'Super administrateur',
}

export default function AdminUsers() {
  const [users, setUsers] = useState<AdminUser[]>([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState<string | null>(null)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')
  const [role, setRole] = useState('')
  const [status, setStatus] = useState('')
  const load = useCallback(async () => {
    setLoading(true); setError('')
    try { setUsers(await adminApi.users()) }
    catch { setError('Les comptes n’ont pas pu être chargés. Vérifiez vos droits administrateur et réessayez.') }
    finally { setLoading(false) }
  }, [])
  useEffect(() => { void load() }, [load])

  const filtered = useMemo(() => users.filter((user) => {
    const term = search.trim().toLowerCase()
    return (!term || `${user.email ?? ''} ${user.phone ?? ''} ${user.id}`.toLowerCase().includes(term))
      && (!role || user.role === role)
      && (status === '' || String(user.isActive) === status)
  }), [users, search, role, status])

  async function toggle(user: AdminUser) {
    if (!window.confirm(`${user.isActive ? 'Suspendre' : 'Réactiver'} l’accès de ${user.email || user.phone || 'ce compte'} ?`)) return
    setSaving(user.id); setError('')
    try {
      await adminApi.toggleUserStatus(user.id)
      setUsers((current) => current.map((item) => item.id === user.id ? { ...item, isActive: !item.isActive } : item))
    } catch { setError('Le statut du compte n’a pas pu être modifié.') }
    finally { setSaving(null) }
  }

  return <div className="mx-auto max-w-7xl p-5 md:p-8">
    <PageHeader title="Comptes utilisateurs" subtitle="Consultez les comptes patient, médecin et administration." />
    <div className="mb-5 grid grid-cols-2 gap-3 md:grid-cols-4">
      {[['Tous les comptes', users.length], ['Patients', users.filter((u) => u.role === 'patient').length], ['Médecins', users.filter((u) => u.role === 'doctor').length], ['Comptes actifs', users.filter((u) => u.isActive).length]].map(([label, value]) => <div key={String(label)} className="card p-4"><p className="text-xs text-slate-500">{label}</p><p className="mt-1 text-2xl font-bold text-slate-900">{value}</p></div>)}
    </div>
    {error && <div className="mb-4"><ErrorBanner message={error} /></div>}
    <section className="card overflow-hidden">
      <div className="flex flex-col gap-3 border-b border-slate-100 p-4 md:flex-row">
        <label className="relative flex-1"><Search size={16} className="absolute left-3 top-2.5 text-slate-400" /><input className="input pl-9" placeholder="Rechercher par téléphone, email ou identifiant" value={search} onChange={(e) => setSearch(e.target.value)} /></label>
        <select className="input md:w-52" value={role} onChange={(e) => setRole(e.target.value)}><option value="">Tous les rôles</option>{Object.entries(roleLabel).map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select>
        <select className="input md:w-44" value={status} onChange={(e) => setStatus(e.target.value)}><option value="">Tous les statuts</option><option value="true">Actifs</option><option value="false">Suspendus</option></select>
        <button className="btn-secondary justify-center" onClick={() => void load()} aria-label="Actualiser"><RefreshCw size={16} /></button>
      </div>
      {loading ? <div className="p-10"><PageLoader /></div> : filtered.length === 0 ? <div className="p-12 text-center text-sm text-slate-500">Aucun compte ne correspond à ces filtres.</div> : <div className="overflow-x-auto"><table className="w-full text-sm">
        <thead className="bg-slate-50 text-left text-xs text-slate-500"><tr><th className="px-5 py-3">Compte</th><th className="px-5 py-3">Rôle</th><th className="px-5 py-3">Vérification email</th><th className="px-5 py-3">Créé le</th><th className="px-5 py-3">Dernière connexion</th><th className="px-5 py-3">Accès</th><th className="px-5 py-3">Action</th></tr></thead>
        <tbody className="divide-y divide-slate-100">{filtered.map((user) => <tr key={user.id} className="hover:bg-slate-50/70"><td className="px-5 py-4"><div className="flex items-center gap-3"><div className="rounded-full bg-primary-50 p-2 text-primary-700"><UserRound size={16} /></div><div><p className="font-medium text-slate-900">{user.email || user.phone || 'Contact non renseigné'}</p><p className="font-mono text-[10px] text-slate-400">{user.id}</p></div></div></td><td className="px-5 py-4"><Badge variant={user.role === 'admin' || user.role === 'superadmin' ? 'blue' : user.role === 'doctor' ? 'blue' : 'gray'}><Shield size={12} />{roleLabel[user.role] ?? user.role}</Badge></td><td className="px-5 py-4"><Badge variant={user.isEmailVerified ? 'green' : 'yellow'}>{user.isEmailVerified ? 'Vérifié' : 'À vérifier'}</Badge></td><td className="px-5 py-4 text-slate-600">{formatDate(user.createdAt)}</td><td className="px-5 py-4 text-slate-600">{formatDate(user.lastLoginAt ?? undefined)}</td><td className="px-5 py-4"><Badge variant={user.isActive ? 'green' : 'red'}>{user.isActive ? 'Actif' : 'Suspendu'}</Badge></td><td className="px-5 py-4"><button onClick={() => void toggle(user)} disabled={saving === user.id} className={user.isActive ? 'btn-secondary text-red-700' : 'btn-secondary text-green-700'}><Power size={14} />{saving === user.id ? 'Mise à jour…' : user.isActive ? 'Suspendre' : 'Réactiver'}</button></td></tr>)}</tbody>
      </table></div>}
      {!loading && <div className="border-t border-slate-100 px-5 py-3 text-xs text-slate-500">{filtered.length} compte{filtered.length > 1 ? 's' : ''} affiché{filtered.length > 1 ? 's' : ''} · {users.length} au total</div>}
    </section>
  </div>
}
