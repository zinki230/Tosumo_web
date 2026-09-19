import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { UserPlus, Stethoscope, Clock, CheckCircle, XCircle } from 'lucide-react'
import { institutionsApi } from '../services/api'
import { PageHeader, PageLoader, ErrorBanner, Avatar, Badge } from '../components/ui'

interface Doctor {
  id: string
  firstName: string
  lastName: string
  fullName: string
  phone: string
  email: string
  specialty: string
  licenseNumber: string
  isVerified: boolean
  isActive: boolean
  lastLoginAt: string | null
  role: string
  isPrimary: boolean
  createdAt: string
}

export default function DoctorsList() {
  const [doctors, setDoctors] = useState<Doctor[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    loadDoctors()
  }, [])

  const loadDoctors = async () => {
    try {
      const data = await institutionsApi.getDoctors()
      setDoctors(data)
    } catch (err: any) {
      setError('Impossible de charger la liste des médecins')
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <div className="p-8">
        <PageLoader />
      </div>
    )
  }

  return (
    <div className="p-6 max-w-6xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <PageHeader title="Médecins" subtitle="Gérez les comptes des médecins de votre établissement" />
        <Link
          to="/medecins/nouveau"
          className="flex items-center gap-2 px-4 py-2.5 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors font-medium"
        >
          <UserPlus className="w-4 h-4" />
          Nouveau médecin
        </Link>
      </div>

      {error && (
        <div className="mb-6">
          <ErrorBanner message={error} />
        </div>
      )}

      {doctors.length === 0 ? (
        <div className="card p-12 text-center">
          <div className="w-16 h-16 bg-slate-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <Stethoscope className="w-8 h-8 text-slate-400" />
          </div>
          <h3 className="text-lg font-semibold text-slate-900 mb-2">Aucun médecin</h3>
          <p className="text-slate-600 mb-6">Vous n'avez pas encore créé de compte médecin.</p>
          <Link
            to="/medecins/nouveau"
            className="inline-flex items-center gap-2 px-6 py-2.5 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors font-medium"
          >
            <UserPlus className="w-4 h-4" />
            Créer le premier compte
          </Link>
        </div>
      ) : (
        <div className="card overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-xs text-slate-500 border-b border-slate-100 bg-slate-50">
                  <th className="px-5 py-3 font-medium">Médecin</th>
                  <th className="px-5 py-3 font-medium">Contact</th>
                  <th className="px-5 py-3 font-medium">Spécialité</th>
                  <th className="px-5 py-3 font-medium">N° Licence</th>
                  <th className="px-5 py-3 font-medium">Statut</th>
                  <th className="px-5 py-3 font-medium">Dernière connexion</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-50">
                {doctors.map((doctor) => (
                  <tr key={doctor.id} className="hover:bg-slate-50/60 transition-colors">
                    <td className="px-5 py-4">
                      <div className="flex items-center gap-3">
                        <Avatar name={doctor.fullName} size="sm" />
                        <div>
                          <p className="font-medium text-slate-900">Dr {doctor.fullName}</p>
                          <p className="text-xs text-slate-500">{doctor.role || 'Médecin'}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-5 py-4">
                      <p className="text-slate-700">{doctor.phone}</p>
                      {doctor.email && doctor.email.includes('@') && (
                        <p className="text-xs text-slate-500">{doctor.email}</p>
                      )}
                    </td>
                    <td className="px-5 py-4 text-slate-600">{doctor.specialty}</td>
                    <td className="px-5 py-4">
                      <span className="font-mono text-xs text-slate-600">{doctor.licenseNumber}</span>
                    </td>
                    <td className="px-5 py-4">
                      <div className="flex items-center gap-2">
                        {doctor.isActive ? (
                          <Badge variant="green">
                            <CheckCircle className="w-3 h-3" />
                            <span>Actif</span>
                          </Badge>
                        ) : (
                          <Badge variant="red">
                            <XCircle className="w-3 h-3" />
                            <span>Inactif</span>
                          </Badge>
                        )}
                        {doctor.isPrimary && (
                          <Badge variant="blue">
                            <span>Principal</span>
                          </Badge>
                        )}
                      </div>
                    </td>
                    <td className="px-5 py-4">
                      {doctor.lastLoginAt ? (
                        <div className="flex items-center gap-2 text-slate-600">
                          <Clock className="w-3.5 h-3.5 text-slate-400" />
                          <span>{new Date(doctor.lastLoginAt).toLocaleDateString('fr-FR')}</span>
                        </div>
                      ) : (
                        <span className="text-slate-400 text-xs">Jamais connecté</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="px-5 py-3 bg-slate-50 border-t border-slate-100">
            <p className="text-xs text-slate-500">
              {doctors.length} médecin{doctors.length > 1 ? 's' : ''} au total
            </p>
          </div>
        </div>
      )}
    </div>
  )
}
