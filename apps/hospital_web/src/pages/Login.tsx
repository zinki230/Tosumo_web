import { useState, FormEvent } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { Eye, EyeOff, Loader2 } from 'lucide-react'
import { authApi } from '../services/api'

export default function Login() {
  const navigate = useNavigate()
  const [phone, setPhone] = useState('')
  const [password, setPassword] = useState('')
  const [showPw, setShowPw] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const result = await authApi.login(phone, password)
      const role = result?.data?.user?.role
      const allowedRoles = ['institution_admin', 'admin', 'superadmin']
      if (!allowedRoles.includes(role)) {
        authApi.logout()
        setError('Ce portail est reserve aux centres hospitaliers et administrateurs. Utilisez un compte centre hospitalier.')
        return
      }
      navigate('/')
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { message?: string } } })?.response?.data?.message ??
        'Identifiants invalides. Vérifiez votre numéro et mot de passe.'
      setError(msg)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-primary-50 via-white to-slate-100 px-4">
      <div className="w-full max-w-sm">
        {/* Logo */}
        <div className="flex flex-col items-center mb-8">
          <div className="w-16 h-16 rounded-2xl bg-white flex items-center justify-center shadow-lg mb-4 border border-slate-200">
            <img 
              src="/images/TOSUMO.png" 
              alt="TOSUMO" 
              className="w-14 h-14 object-contain"
            />
          </div>
          <h1 className="text-2xl font-bold text-slate-900">TOSUMO</h1>
          <p className="text-sm text-green-600 font-medium mt-1">L'essentiel de votre santé au creux de vos mains</p>
          <p className="text-xs text-slate-500 mt-2">Gestion des centres hospitaliers</p>
        </div>

        {/* Form card */}
        <div className="bg-white rounded-2xl border border-slate-200 shadow-sm p-8">
          <h2 className="text-base font-semibold text-slate-800 mb-5">Connexion administrateur</h2>

          {error && (
            <div className="mb-4 p-3 rounded-lg bg-red-50 border border-red-200 text-red-700 text-sm">
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1.5">
                Numéro de téléphone
              </label>
              <input
                type="tel"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="+237 6XX XXX XXX"
                required
                className="input"
                autoComplete="tel"
              />
            </div>

            <div>
              <label className="block text-xs font-medium text-slate-600 mb-1.5">
                Mot de passe
              </label>
              <div className="relative">
                <input
                  type={showPw ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  required
                  className="input pr-10"
                  autoComplete="current-password"
                />
                <button
                  type="button"
                  onClick={() => setShowPw(!showPw)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 transition-colors"
                  tabIndex={-1}
                >
                  {showPw ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
            </div>

            <button
              type="submit"
              disabled={loading || !phone || !password}
              className="btn-primary w-full justify-center py-2.5"
            >
              {loading ? (
                <Loader2 size={16} className="animate-spin" />
              ) : null}
              {loading ? 'Connexion…' : 'Se connecter'}
            </button>
          </form>

          <p className="text-center text-xs text-slate-400 mt-5">
            Connectez-vous avec un compte centre hospitalier ou administrateur.
          </p>

          <div className="mt-6 pt-6 border-t border-slate-100">
            <p className="text-center text-sm text-slate-600 mb-3">
              Vous êtes médecin ?
            </p>
            <Link
              to="/register/doctor"
              className="btn-secondary w-full justify-center py-2.5"
            >
              Créer un compte médecin
            </Link>
          </div>

          <div className="mt-4">
            <p className="text-center text-sm text-slate-600 mb-3">
              Centre hospitalier ?
            </p>
            <Link
              to="/register/institution"
              className="btn-secondary w-full justify-center py-2.5"
            >
              Inscrire mon établissement
            </Link>
          </div>
        </div>
      </div>
    </div>
  )
}
