import { useState, FormEvent } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { Activity, Eye, EyeOff, Loader2, Building2 } from 'lucide-react'
import { institutionsApi } from '../services/api'

export default function InstitutionRegister() {
  const navigate = useNavigate()
  const [formData, setFormData] = useState({
    name: '',
    type: 'hospital',
    phone: '',
    email: '',
    password: '',
    confirmPassword: '',
    address: '',
    city: '',
    region: 'Centre',
  })
  const [showPw, setShowPw] = useState(false)
  const [showConfirmPw, setShowConfirmPw] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState(false)

  function handleChange(e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) {
    setFormData({ ...formData, [e.target.name]: e.target.value })
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError('')

    // Validation
    if (formData.password !== formData.confirmPassword) {
      setError('Les mots de passe ne correspondent pas')
      return
    }

    if (formData.password.length < 8) {
      setError('Le mot de passe doit contenir au moins 8 caractères')
      return
    }

    setLoading(true)
    try {
      await institutionsApi.register({
        name: formData.name,
        type: formData.type,
        phone: formData.phone,
        email: formData.email,
        password: formData.password,
        address: formData.address,
        city: formData.city,
        region: formData.region,
      })
      setSuccess(true)
      setTimeout(() => navigate('/login'), 3000)
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { message?: string } } })?.response?.data?.message ??
        'Une erreur est survenue lors de l\'inscription'
      setError(msg)
    } finally {
      setLoading(false)
    }
  }

  if (success) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-primary-50 via-white to-slate-100 px-4">
        <div className="w-full max-w-md bg-white rounded-2xl border border-slate-200 shadow-sm p-8 text-center">
          <div className="w-16 h-16 rounded-full bg-green-100 flex items-center justify-center mx-auto mb-4">
            <Building2 size={32} className="text-green-600" />
          </div>
          <h2 className="text-2xl font-bold text-slate-900 mb-2">Inscription réussie!</h2>
          <p className="text-slate-600 mb-6">
            Votre demande d'inscription a été envoyée. Un administrateur va vérifier vos informations
            et vous recevrez un email une fois votre compte activé.
          </p>
          <p className="text-sm text-slate-500">
            Redirection vers la page de connexion...
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-primary-50 via-white to-slate-100 px-4 py-8">
      <div className="max-w-2xl mx-auto">
        {/* Header */}
        <div className="flex flex-col items-center mb-8">
          <div className="w-14 h-14 rounded-2xl bg-primary-600 flex items-center justify-center shadow-lg mb-4">
            <Activity size={28} className="text-white" />
          </div>
          <h1 className="text-2xl font-bold text-slate-900">TOSUMO</h1>
          <p className="text-sm text-slate-500 mt-1">Inscription centre hospitalier</p>
        </div>

        {/* Form card */}
        <div className="bg-white rounded-2xl border border-slate-200 shadow-sm p-8">
          <div className="flex items-center gap-3 mb-6">
            <Building2 size={24} className="text-primary-600" />
            <div>
              <h2 className="text-lg font-semibold text-slate-800">Créer un compte centre hospitalier</h2>
              <p className="text-sm text-slate-500">Remplissez les informations de votre établissement</p>
            </div>
          </div>

          {error && (
            <div className="mb-6 p-3 rounded-lg bg-red-50 border border-red-200 text-red-700 text-sm">
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-5">
            {/* Informations établissement */}
            <div className="pb-4 border-b border-slate-100">
              <h3 className="text-sm font-semibold text-slate-700 mb-4">Informations de l'établissement</h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="md:col-span-2">
                  <label className="block text-xs font-medium text-slate-600 mb-1.5">
                    Nom de l'établissement *
                  </label>
                  <input
                    type="text"
                    name="name"
                    value={formData.name}
                    onChange={handleChange}
                    placeholder="Ex: Centre Hospitalier Central de Yaoundé"
                    required
                    className="input"
                  />
                </div>

                <div>
                  <label className="block text-xs font-medium text-slate-600 mb-1.5">
                    Type d'établissement *
                  </label>
                  <select
                    name="type"
                    value={formData.type}
                    onChange={handleChange}
                    required
                    className="input"
                  >
                    <option value="hospital">Hôpital</option>
                    <option value="clinic">Clinique</option>
                    <option value="health_center">Centre de santé</option>
                    <option value="polyclinic">Polyclinique</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-medium text-slate-600 mb-1.5">
                    Région *
                  </label>
                  <select
                    name="region"
                    value={formData.region}
                    onChange={handleChange}
                    required
                    className="input"
                  >
                    <option value="Adamaoua">Adamaoua</option>
                    <option value="Centre">Centre</option>
                    <option value="Est">Est</option>
                    <option value="Extreme-Nord">Extrême-Nord</option>
                    <option value="Littoral">Littoral</option>
                    <option value="Nord">Nord</option>
                    <option value="Nord-Ouest">Nord-Ouest</option>
                    <option value="Ouest">Ouest</option>
                    <option value="Sud">Sud</option>
                    <option value="Sud-Ouest">Sud-Ouest</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-medium text-slate-600 mb-1.5">
                    Ville *
                  </label>
                  <input
                    type="text"
                    name="city"
                    value={formData.city}
                    onChange={handleChange}
                    placeholder="Ex: Yaoundé"
                    required
                    className="input"
                  />
                </div>

                <div>
                  <label className="block text-xs font-medium text-slate-600 mb-1.5">
                    Adresse
                  </label>
                  <input
                    type="text"
                    name="address"
                    value={formData.address}
                    onChange={handleChange}
                    placeholder="Ex: Avenue de l'Indépendance"
                    className="input"
                  />
                </div>
              </div>
            </div>

            {/* Contact */}
            <div className="pb-4 border-b border-slate-100">
              <h3 className="text-sm font-semibold text-slate-700 mb-4">Informations de contact</h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-medium text-slate-600 mb-1.5">
                    Téléphone *
                  </label>
                  <input
                    type="tel"
                    name="phone"
                    value={formData.phone}
                    onChange={handleChange}
                    placeholder="+237 6XX XXX XXX"
                    required
                    className="input"
                  />
                </div>

                <div>
                  <label className="block text-xs font-medium text-slate-600 mb-1.5">
                    Email *
                  </label>
                  <input
                    type="email"
                    name="email"
                    value={formData.email}
                    onChange={handleChange}
                    placeholder="contact@hopital.cm"
                    required
                    className="input"
                  />
                </div>
              </div>
            </div>

            {/* Sécurité */}
            <div>
              <h3 className="text-sm font-semibold text-slate-700 mb-4">Sécurité du compte</h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-medium text-slate-600 mb-1.5">
                    Mot de passe *
                  </label>
                  <div className="relative">
                    <input
                      type={showPw ? 'text' : 'password'}
                      name="password"
                      value={formData.password}
                      onChange={handleChange}
                      placeholder="••••••••"
                      required
                      className="input pr-10"
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
                  <p className="text-xs text-slate-500 mt-1">Minimum 8 caractères</p>
                </div>

                <div>
                  <label className="block text-xs font-medium text-slate-600 mb-1.5">
                    Confirmer le mot de passe *
                  </label>
                  <div className="relative">
                    <input
                      type={showConfirmPw ? 'text' : 'password'}
                      name="confirmPassword"
                      value={formData.confirmPassword}
                      onChange={handleChange}
                      placeholder="••••••••"
                      required
                      className="input pr-10"
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

            <div className="pt-2">
              <button
                type="submit"
                disabled={loading}
                className="btn-primary w-full justify-center py-3"
              >
                {loading && <Loader2 size={16} className="animate-spin" />}
                {loading ? 'Inscription en cours...' : 'Créer mon compte'}
              </button>
            </div>
          </form>

          <div className="mt-6 pt-6 border-t border-slate-100 text-center">
            <p className="text-sm text-slate-600">
              Vous avez déjà un compte ?{' '}
              <Link to="/login" className="text-primary-600 hover:text-primary-700 font-medium">
                Se connecter
              </Link>
            </p>
          </div>
        </div>

        <p className="text-center text-xs text-slate-500 mt-6">
          * Champs obligatoires
        </p>
      </div>
    </div>
  )
}
