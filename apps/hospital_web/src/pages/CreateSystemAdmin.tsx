import { FormEvent, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { ArrowLeft, KeyRound, Loader2, ShieldCheck, UserRoundPlus } from 'lucide-react'
import { adminApi, authApi, getApiErrorMessage } from '../services/api'
import { ErrorBanner, PageHeader, PageLoader } from '../components/ui'

type FormValues = { phone: string; email: string; password: string; confirmPassword: string; currentPassword: string }
const emptyForm: FormValues = { phone: '', email: '', password: '', confirmPassword: '', currentPassword: '' }

export default function CreateSystemAdmin() {
  const navigate = useNavigate()
  const [available, setAvailable] = useState(false)
  const [checking, setChecking] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [form, setForm] = useState(emptyForm)

  useEffect(() => {
    adminApi.systemAdminBootstrapStatus()
      .then((status) => setAvailable(status.available))
      .catch((loadError: unknown) => setError(getApiErrorMessage(loadError, 'Impossible de vérifier si la création est disponible.')))
      .finally(() => setChecking(false))
  }, [])

  async function submit(event: FormEvent) {
    event.preventDefault()
    setError('')
    if (form.password !== form.confirmPassword) {
      setError('Les deux mots de passe ne correspondent pas.')
      return
    }
    setSaving(true)
    try {
      await adminApi.createSystemAdmin({
        phone: form.phone,
        email: form.email,
        password: form.password,
        currentPassword: form.currentPassword,
      })
      // Switch the current browser to the newly-created system-admin account.
      await authApi.login(form.phone, form.password)
      navigate('/', { replace: true })
    } catch (createError: unknown) {
      setError(getApiErrorMessage(createError, 'Le compte administrateur n’a pas pu être créé.'))
      setSaving(false)
    }
  }

  if (checking) return <div className="p-8"><PageLoader /></div>

  return <div className="mx-auto max-w-3xl p-5 md:p-8">
    <PageHeader title="Créer le compte administrateur système" subtitle="Configurez un compte distinct pour gérer toute la plateforme." />
    {error && <div className="mb-4"><ErrorBanner message={error} /></div>}

    {!available ? <section className="card p-6 md:p-8">
      <div className="flex items-start gap-4"><span className="rounded-xl bg-emerald-50 p-3 text-emerald-700"><ShieldCheck size={22} /></span><div><h2 className="font-semibold text-slate-900">Compte déjà initialisé</h2><p className="mt-1 text-sm leading-6 text-slate-600">Un compte administrateur système existe déjà. Connectez-vous avec ses identifiants pour gérer la plateforme.</p></div></div>
      <button className="btn-secondary mt-6" onClick={() => void authApi.logoutRemote().finally(() => navigate('/login'))}><ArrowLeft size={16} />Aller à la connexion</button>
    </section> : <form onSubmit={submit} className="card space-y-5 p-6 md:p-8">
      <div className="flex items-start gap-3 rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900"><KeyRound size={18} className="mt-0.5 shrink-0" /><p>La création initiale est réservée à votre compte administrateur d’établissement et n’est possible qu’une seule fois. Confirmez votre mot de passe actuel pour autoriser cette opération.</p></div>

      <div className="grid gap-4 sm:grid-cols-2">
        <label><span className="mb-1.5 block text-sm font-medium text-slate-700">Téléphone de connexion</span><input className="input" type="tel" autoComplete="tel" placeholder="+237 6XX XXX XXX" required value={form.phone} onChange={(event) => setForm({ ...form, phone: event.target.value })} /></label>
        <label><span className="mb-1.5 block text-sm font-medium text-slate-700">Adresse email</span><input className="input" type="email" autoComplete="email" required value={form.email} onChange={(event) => setForm({ ...form, email: event.target.value })} /></label>
        <label><span className="mb-1.5 block text-sm font-medium text-slate-700">Mot de passe du nouvel administrateur</span><input className="input" type="password" autoComplete="new-password" minLength={12} required value={form.password} onChange={(event) => setForm({ ...form, password: event.target.value })} /><span className="mt-1 block text-xs text-slate-500">12 caractères minimum, avec majuscule, minuscule et chiffre.</span></label>
        <label><span className="mb-1.5 block text-sm font-medium text-slate-700">Confirmer le nouveau mot de passe</span><input className="input" type="password" autoComplete="new-password" minLength={12} required value={form.confirmPassword} onChange={(event) => setForm({ ...form, confirmPassword: event.target.value })} /></label>
      </div>

      <label className="block"><span className="mb-1.5 block text-sm font-medium text-slate-700">Votre mot de passe actuel</span><input className="input" type="password" autoComplete="current-password" required value={form.currentPassword} onChange={(event) => setForm({ ...form, currentPassword: event.target.value })} /></label>

      <div className="flex flex-col-reverse justify-end gap-2 border-t border-slate-100 pt-4 sm:flex-row"><button type="button" onClick={() => navigate('/')} className="btn-secondary justify-center">Annuler</button><button type="submit" disabled={saving} className="btn-primary justify-center">{saving ? <Loader2 size={16} className="animate-spin" /> : <UserRoundPlus size={16} />}{saving ? 'Création du compte…' : 'Créer et ouvrir le compte admin'}</button></div>
    </form>}
  </div>
}
