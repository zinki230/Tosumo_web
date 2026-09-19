import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { ArrowLeft, UserPlus, Eye, EyeOff, Copy, Check } from 'lucide-react'
import { institutionsApi } from '../services/api'
import { PageHeader } from '../components/ui'

export default function DoctorCreate() {
  const navigate = useNavigate()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState(false)
  const [credentials, setCredentials] = useState<{ phone: string; temporaryPassword: string } | null>(null)
  const [showPassword, setShowPassword] = useState(false)
  const [copied, setCopied] = useState(false)

  const [formData, setFormData] = useState({
    firstName: '',
    lastName: '',
    phone: '',
    email: '',
    specialty: '',
    licenseNumber: '',
  })

  const specialties = [
    'Médecine générale',
    'Cardiologie',
    'Pédiatrie',
    'Dermatologie',
    'Gynécologie',
    'Neurologie',
    'ORL',
    'Ophtalmologie',
    'Dentisterie',
    'Psychiatrie',
    'Orthopédie',
    'Radiologie',
    'Anesthésiologie',
    'Chirurgie générale',
    'Urologie',
  ]

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    setFormData({ ...formData, [e.target.name]: e.target.value })
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    try {
      const result = await institutionsApi.createDoctor(formData)
      setSuccess(true)
      setCredentials(result.credentials)
    } catch (err: any) {
      setError(err.response?.data?.message || 'Erreur lors de la création du compte')
    } finally {
      setLoading(false)
    }
  }

  const handleCopy = () => {
    if (credentials) {
      navigator.clipboard.writeText(
        `Identifiants TOSUMO\nTéléphone: ${credentials.phone}\nMot de passe: ${credentials.temporaryPassword}`
      )
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    }
  }

  if (success && credentials) {
    return (
      <div className="p-6 max-w-2xl mx-auto">
        <div className="card p-8 text-center">
          <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <Check className="w-8 h-8 text-green-600" />
          </div>
          <h2 className="text-2xl font-bold text-slate-900 mb-2">Compte créé avec succès !</h2>
          <p className="text-slate-600 mb-6">Le compte du docteur a été créé. Veuillez noter les identifiants ci-dessous.</p>

          <div className="bg-amber-50 border border-amber-200 rounded-lg p-6 mb-6">
            <div className="flex items-start gap-3 mb-4">
              <div className="w-10 h-10 bg-amber-100 rounded-full flex items-center justify-center flex-shrink-0">
                <span className="text-amber-600 text-xl">⚠️</span>
              </div>
              <div className="text-left">
                <p className="font-semibold text-amber-900 mb-1">Important !</p>
                <p className="text-sm text-amber-800">
                  Ces identifiants ne seront affichés qu'une seule fois. Assurez-vous de les copier ou de les noter avant de quitter cette page.
                </p>
              </div>
            </div>
          </div>

          <div className="bg-slate-50 rounded-lg p-6 mb-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-sm font-semibold text-slate-700">Identifiants de connexion</h3>
              <button
                onClick={handleCopy}
                className="flex items-center gap-2 px-3 py-1.5 text-sm bg-white border border-slate-200 rounded-lg hover:bg-slate-50 transition-colors"
              >
                {copied ? (
                  <>
                    <Check className="w-4 h-4 text-green-600" />
                    <span className="text-green-600">Copié !</span>
                  </>
                ) : (
                  <>
                    <Copy className="w-4 h-4" />
                    <span>Copier</span>
                  </>
                )}
              </button>
            </div>

            <div className="space-y-3 text-left">
              <div>
                <label className="text-xs text-slate-500 block mb-1">Téléphone</label>
                <div className="bg-white px-4 py-3 rounded-lg border border-slate-200 font-mono text-slate-900">
                  {credentials.phone}
                </div>
              </div>

              <div>
                <label className="text-xs text-slate-500 block mb-1">Mot de passe temporaire</label>
                <div className="bg-white px-4 py-3 rounded-lg border border-slate-200 flex items-center justify-between">
                  <span className="font-mono text-slate-900">
                    {showPassword ? credentials.temporaryPassword : '••••••••'}
                  </span>
                  <button
                    onClick={() => setShowPassword(!showPassword)}
                    className="text-slate-400 hover:text-slate-600 transition-colors"
                  >
                    {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>
            </div>

            <p className="text-xs text-slate-500 mt-4">
              Le docteur pourra changer son mot de passe après sa première connexion depuis l'application mobile.
            </p>
          </div>

          <div className="flex gap-3">
            <button
              onClick={() => navigate('/medecins')}
              className="flex-1 px-4 py-2.5 border border-slate-200 rounded-lg hover:bg-slate-50 transition-colors font-medium"
            >
              Voir la liste des médecins
            </button>
            <button
              onClick={() => {
                setSuccess(false)
                setCredentials(null)
                setFormData({
                  firstName: '',
                  lastName: '',
                  phone: '',
                  email: '',
                  specialty: '',
                  licenseNumber: '',
                })
              }}
              className="flex-1 px-4 py-2.5 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors font-medium"
            >
              Créer un autre médecin
            </button>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="p-6 max-w-3xl mx-auto">
      <button
        onClick={() => navigate('/medecins')}
        className="flex items-center gap-2 text-slate-600 hover:text-slate-900 mb-4 transition-colors"
      >
        <ArrowLeft className="w-4 h-4" />
        <span className="text-sm font-medium">Retour à la liste</span>
      </button>

      <PageHeader
        title="Créer un compte médecin"
        subtitle="Créez un nouveau compte pour un médecin de votre établissement"
      />

      {error && (
        <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg">
          <p className="text-sm text-red-800">{error}</p>
        </div>
      )}

      <form onSubmit={handleSubmit} className="card p-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          <div>
            <label className="block text-sm font-medium text-slate-700 mb-2">
              Prénom <span className="text-red-500">*</span>
            </label>
            <input
              type="text"
              name="firstName"
              value={formData.firstName}
              onChange={handleChange}
              required
              className="w-full px-4 py-2.5 border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              placeholder="Jean"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 mb-2">
              Nom <span className="text-red-500">*</span>
            </label>
            <input
              type="text"
              name="lastName"
              value={formData.lastName}
              onChange={handleChange}
              required
              className="w-full px-4 py-2.5 border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              placeholder="Dupont"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 mb-2">
              Téléphone <span className="text-red-500">*</span>
            </label>
            <input
              type="tel"
              name="phone"
              value={formData.phone}
              onChange={handleChange}
              required
              className="w-full px-4 py-2.5 border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              placeholder="+237 6 XX XX XX XX"
            />
            <p className="text-xs text-slate-500 mt-1">Ce numéro servira d'identifiant de connexion</p>
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 mb-2">Email (optionnel)</label>
            <input
              type="email"
              name="email"
              value={formData.email}
              onChange={handleChange}
              className="w-full px-4 py-2.5 border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              placeholder="jean.dupont@example.com"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 mb-2">
              Spécialité <span className="text-red-500">*</span>
            </label>
            <select
              name="specialty"
              value={formData.specialty}
              onChange={handleChange}
              required
              className="w-full px-4 py-2.5 border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
            >
              <option value="">Sélectionner une spécialité</option>
              {specialties.map((spec) => (
                <option key={spec} value={spec}>
                  {spec}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 mb-2">
              Numéro de licence <span className="text-red-500">*</span>
            </label>
            <input
              type="text"
              name="licenseNumber"
              value={formData.licenseNumber}
              onChange={handleChange}
              required
              className="w-full px-4 py-2.5 border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
              placeholder="CAM-MD-2024-XXX"
            />
          </div>
        </div>

        <div className="mt-6 pt-6 border-t border-slate-100 flex gap-3">
          <button
            type="button"
            onClick={() => navigate('/medecins')}
            className="px-6 py-2.5 border border-slate-200 rounded-lg hover:bg-slate-50 transition-colors font-medium"
          >
            Annuler
          </button>
          <button
            type="submit"
            disabled={loading}
            className="flex-1 flex items-center justify-center gap-2 px-6 py-2.5 bg-primary-600 text-white rounded-lg hover:bg-primary-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-medium"
          >
            <UserPlus className="w-4 h-4" />
            {loading ? 'Création en cours...' : 'Créer le compte'}
          </button>
        </div>
      </form>
    </div>
  )
}
