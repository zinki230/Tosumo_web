import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import Layout from './components/Layout'
import Login from './pages/Login'
import DoctorRegister from './pages/DoctorRegister'
import InstitutionRegister from './pages/InstitutionRegister'
import Dashboard from './pages/Dashboard'
import TrackingPage from './pages/TrackingPage'
import DoctorsList from './pages/DoctorsList'
import DoctorCreate from './pages/DoctorCreate'
import DoctorDetail from './pages/DoctorDetail'
import PatientsList from './pages/PatientsList'
import PatientDetail from './pages/PatientDetail'
import AdminUsers from './pages/AdminUsers'
import AdminAppointments from './pages/AdminAppointments'
import AuditLogs from './pages/AuditLogs'
import DoctorApprovals from './pages/DoctorApprovals'
import CreateSystemAdmin from './pages/CreateSystemAdmin'

function RequireAuth({ children }: { children: React.ReactNode }) {
  const token = localStorage.getItem('tosumo_token')
  const rawUser = localStorage.getItem('tosumo_user')
  const allowedRoles = ['institution_admin', 'admin', 'superadmin']

  let role = ''
  if (rawUser) {
    try {
      role = JSON.parse(rawUser)?.role ?? ''
    } catch {
      role = ''
    }
  }

  if (!token || !allowedRoles.includes(role)) {
    localStorage.removeItem('tosumo_token')
    localStorage.removeItem('tosumo_user')
    return <Navigate to="/login" replace />
  }

  return <>{children}</>
}

function RequireSystemAdmin({ children }: { children: React.ReactNode }) {
  let role = ''
  try { role = JSON.parse(localStorage.getItem('tosumo_user') ?? '{}')?.role ?? '' } catch { role = '' }
  return role === 'admin' || role === 'superadmin' ? <>{children}</> : <Navigate to="/" replace />
}

function RequireAuditAccess({ children }: { children: React.ReactNode }) {
  let role = ''
  try { role = JSON.parse(localStorage.getItem('tosumo_user') ?? '{}')?.role ?? '' } catch { role = '' }
  return ['admin', 'superadmin', 'institution_admin'].includes(role) ? <>{children}</> : <Navigate to="/" replace />
}

function RequireInstitutionAdmin({ children }: { children: React.ReactNode }) {
  let role = ''
  try { role = JSON.parse(localStorage.getItem('tosumo_user') ?? '{}')?.role ?? '' } catch { role = '' }
  return role === 'institution_admin' ? <>{children}</> : <Navigate to="/" replace />
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/register/doctor" element={<DoctorRegister />} />
        <Route path="/register/institution" element={<InstitutionRegister />} />
        <Route
          path="/"
          element={
            <RequireAuth>
              <Layout />
            </RequireAuth>
          }
        >
          <Route index element={<Dashboard />} />
          <Route path="suivi" element={<TrackingPage />} />
          <Route path="medecins" element={<DoctorsList />} />
          <Route path="medecins/nouveau" element={<DoctorCreate />} />
          <Route path="medecins/:id" element={<DoctorDetail />} />
          <Route path="patients" element={<PatientsList />} />
          <Route path="patients/:id" element={<PatientDetail />} />
          <Route path="comptes" element={<RequireSystemAdmin><AdminUsers /></RequireSystemAdmin>} />
          <Route path="rendez-vous" element={<RequireSystemAdmin><AdminAppointments /></RequireSystemAdmin>} />
          <Route path="journal" element={<RequireAuditAccess><AuditLogs /></RequireAuditAccess>} />
          <Route path="creer-admin" element={<RequireInstitutionAdmin><CreateSystemAdmin /></RequireInstitutionAdmin>} />
          <Route path="verifications" element={<RequireSystemAdmin><DoctorApprovals /></RequireSystemAdmin>} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}
