import { useState, useEffect, FormEvent } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import {
  Activity, ArrowLeft, Eye, EyeOff, Loader2, Stethoscope,
  Building2, User, Mail, Phone, Shield, BookOpen,
} from 'lucide-react'
import { authApi, institutionsApi, Institution } from '../services/api'

export default function DoctorRegister() {
  const navigate = useNavigate()

  // Form state
  const [firstName, setFirstName] = useState('')
  const [lastName, setLastName] = useState('')
  const [email, setEmail] = useState('')
  const [phone, setPhone] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [specialty, setSpecialty] = useState('')
  const [licenseNumber, setLicenseNumber] = useState('')
  const [institutionId, setInstitutionId] = useState('')
  const [showPw, setShowPw] = useState(false)
  const [showConfirmPw, setShowConfirmPw] = useState(false)

  // UI state
  const [institutions, setInstitutions] = useState<Institution[]>([])
  const [loading, setLoading] = useState(false)
  const [loadingInstitutions, setLoadingInstitutions] = useState(true)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState(false)

  // Spécialités médicales communes
  const specialties = [
    'Médecine générale',
    'Pédiatrie',
    'Gynécologie',
    'Cardiologie',
    'Chirurgie générale',
    'Dermatologie',
    'ORL',
    'Ophtalmologie',
    'Radiologie',
    'Anesthésie',
    'Psychiatrie',
    'Urgences',
    'Autre',
  ]

  useEffect(() => {
    loadInstitutions()
  }, [])

  async function loadInstitutions() {
    try {
      const data = await institutionsApi.list()
      setInstitutions(data)
    } catch (e) {
      console.error('Failed to load institutions:', e)
    } finally {
      setLoadingInstitutions(false)
    }
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError('')

    // Validation
    if (password !== confirmPassword) {
      setError('Les mots de passe ne correspondent pas.')
      return
    }
    if (password.length < 8) {
      setError('Le mot de passe doit contenir au moins 8 caractères.')
      return
    }
    if (!institutionId) {
      setError('Veuillez sélectionner un centre de santé.')
      return
    }

    setLoading(true)

    try {
      await authApi.registerDoctor({
        firstName,
        lastName,
        email,
        phone,
        password,
        specialty,
        licenseNumber,
        institutionId,
      })
      setSuccess(true)
      setTimeout(() => {
        navigate('/login')
      }, 2000)
    } catch (err: any) {
      const msg = err.response?.data?.message || err.message || 'Erreur réseau. Veuillez réessayer.'
      setError(msg)
    } finally {
      setLoading(false)
    }
  }

  if (success) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-primary-50 via-white to-slate-100 px-4">
        <div className="w-full max-w-md bg-white rounded-2xl border border-green-200 shadow-sm p-8 text-center">
          <div className="w-16 h-16 mx-auto rounded-full bg-green-50 flex items-center justify-center mb-4">
            <Stethoscope size={32} className="text-green-600" />
          </div>
          <h2 className="text-xl font-bold text-slate-900 mb-2">Inscription réussie !</h2>
          <p className="text-sm text-slate-600 mb-4">
            Votre compte médecin a été créé. Vous allez être redirigé vers la page de connexion.
          </p>
          <Loader2 className="animate-spin text-primary-600 mx-auto" size={24} />
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-primary-50 via-white to-slate-100 px-4 py-8">
      <div className="max-w-2xl mx-auto">
        {/* Header */}
        <div className="flex items-center gap-4 mb-6">
          <Link
            to="/login"
            className="inline-flex items-center gap-1.5 text-sm text-slate-500 hover:text-primary-600 transition-colors"
          >
            <ArrowLeft size={16} />
            Retour
          </Link>
        </div>

        <div className="flex flex-col items-center mb-6">
          <div className="w-14 h-14 rounded-2xl bg-primary-600 flex items-center justify-center shadow-lg mb-4">
            <Activity size={28} className="text-white" />
          </div>
          <h1 className="text-2xl font-bold text-slate-900">Inscription médecin</h1>
          <p className="text-sm text-slate-500 mt-1">Créez votre compte professionnel TOSUMO</p>
        </div>

        {/* Form card */}
        <div className="bg-white rounded-2xl border border-slate-200 shadow-sm p-8">
          {error && (
            <div className="mb-6 p-4 rounded-lg bg-red-50 border border-red-200 text-red-700 text-sm">
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Identité */}
            <div>
              <h3 className="text-sm font-semibold text-slate-700 mb-4 flex items-center gap-2">
                <User size={16} />
                Identité
              </h3>
              <div className="grid sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-medium text-slate-600 mb-1.5">
                    Prénom <span className="text-red-500">*</span>
                  </label>
                  <input
                    type="text"
                    value={firstName}
                    onChange={(e) => setFirstName(e.target.value)}
                    required
                    className="input"
                    placeholder="Jean"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-slate-600 mb-1.5">
                    Nom <span className="text-red-500">*</span>
                  </label>
                  <input
                    type="text"
                    value={lastName}
                    onChange={(e) => setLastName(e.target.value)}
                    required
                    className="input"
                    placeholder="Dupont"
                  />
                </div>
              </div>
            </div>

            {/* Contact */}
            <div>
              <h3 className="text-sm font-semibold text-slate-700 mb-4 flex items-center gap-2">
                <Phone size={16} />
                Contact
              </h3>
              <div className="space-y-4">
                <div>
                  <label className="block text-xs font-medium text-slate-600 mb-1.5">
                    Email <span className="text-red-500">*</span>
                  </label>
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    required
                    className="input"
                    placeholder="jean.dupont@hopital.cm"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-slate-600 mb-1.5">
                    Téléphone <span className="text-red-500">*</span>
                  </label>
                  <input
                    type="tel"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    required
                    className="input"
                    placeholder="+237 6XX XXX XXX"
                  />
                </div>
              </div>
            </div>

            {/* Informations professionnelles */}
            <div>
              <h3 className="text-sm font-semibold text-slate-700 mb-4 flex items-center gap-2">
                <Stethoscope size={16} />
                Informations professionnelles
              </h3>
              <div className="space-y-4">
                <div>
                  <label className="block text-xs font-medium text-slate-600 mb-1.5">
                    Spécialité <span className="text-red-500">*</span>
                  </label>
                  <select
                    value={specialty}
                    onChange={(e) => setSpecialty(e.target.value)}
                    required
                    className="input"
                  >
                    <option value="">-- Sélectionner --</option>
                    {specialties.map((s) => (
                      <option key={s} value={s}>{s}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-medium text-slate-600 mb-1.5">
                    Numéro de licence <span className="text-red-500">*</span>
                  </label>
                  <input
                    type="text"
                    value={licenseNumber}
                    onChange={(e) => setLicenseNumber(e.target.value)}
                    required
                    className="input"
                    placeholder="Ex: MD-CM-2024-12345"
                  />
                </div>
                <div>
                  <label className="block text-xs font-medium text-slate-600 mb-1.5">
                    Centre de santé <span className="text-red-500">*</span>
                  </label>
                  {loadingInstitutions ? (
                    <div className="input flex items-center justify-center gap-2 text-slate-400">
                      <Loader2 size={16} className="animate-spin" />
                      Chargement...
                    </div>
                  ) : (
                    <select
                      value={institutionId}
                      onChange={(e) => setInstitutionId(e.target.value)}
                      required
                      className="input"
                    >
                      <option value="">-- Sélectionner un établissement --</option>
                      {institutions.map((inst) => (
                        <option key={inst.id} value={inst.id}>
                          {inst.name} {inst.city ? `— ${inst.city}` : ''} ({inst.type})
                        </option>
                      ))}
                    </select>
                  )}
                  <p className="text-xs text-slate-400 mt-1">
                    <Building2 size={12} className="inline mr-1" />
                    L'établissement où vous exercez principalement
                  </p>
                </div>
              </div>
            </div>

            {/* Sécurité */}
            <div>
              <h3 className="text-sm font-semibold text-slate-700 mb-4 flex items-center gap-2">
                <Shield size={16} />
                Sécurité
              </h3>
              <div className="space-y-4">
                <div>
                  <label className="block text-xs font-medium text-slate-600 mb-1.5">
                    Mot de passe <span className="text-red-500">*</span>
                  </label>
                  <div className="relative">
                    <input
                      type={showPw ? 'text' : 'password'}
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      required
                      minLength={8}
                      className="input pr-10"
                      placeholder="Minimum 8 caractères"
                    />
                    <button
                      type="button"
                      onClick={() => setShowPw(!showPw)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
                      tabIndex={-1}
                    >
                      {showPw ? <EyeOff size={16} /> : <Eye size={16} />}
                    </button>
                  </div>
                </div>
                <div>
                  <label className="block text-xs font-medium text-slate-600 mb-1.5">
                    Confirmer le mot de passe <span className="text-red-500">*</span>
                  </label>
                  <div className="relative">
                    <input
                      type={showConfirmPw ? 'text' : 'password'}
                      value={confirmPassword}
                      onChange={(e) => setConfirmPassword(e.target.value)}
                      required
                      minLength={8}
                      className="input pr-10"
                      placeholder="Retapez le mot de passe"
                    />
                    <button
                      type="button"
                      onClick={() => setShowConfirmPw(!showConfirmPw)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
                      tabIndex={-1}
                    >
                      {showConfirmPw ? <EyeOff size={16} /> : <Eye size={16} />}
                    </button>
                  </div>
                </div>
              </div>
            </div>

            <div className="flex items-start gap-3 p-4 bg-slate-50 rounded-lg border border-slate-200">
              <BookOpen size={18} className="text-slate-400 shrink-0 mt-0.5" />
              <p className="text-xs text-slate-600">
                En créant un compte, vous acceptez les conditions d'utilisation de TOSUMO et
                vous vous engagez à respecter le secret médical et les réglementations en vigueur.
              </p>
            </div>

            <button
              type="submit"
              disabled={loading || loadingInstitutions}
              className="btn-primary w-full justify-center py-3 text-base"
            >
              {loading ? (
                <>
                  <Loader2 size={18} className="animate-spin" />
                  Inscription en cours...
                </>
              ) : (
                'Créer mon compte médecin'
              )}
            </button>
          </form>

          <p className="text-center text-xs text-slate-500 mt-6">
            Vous avez déjà un compte ?{' '}
            <Link to="/login" className="text-primary-600 hover:underline font-medium">
              Se connecter
            </Link>
          </p>
        </div>
      </div>
    </div>
  )
}
