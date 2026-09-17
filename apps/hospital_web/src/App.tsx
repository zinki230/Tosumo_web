import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import Layout from './components/Layout'
import Login from './pages/Login'
import DoctorRegister from './pages/DoctorRegister'
import Dashboard from './pages/Dashboard'
import TrackingPage from './pages/TrackingPage'
import DoctorsList from './pages/DoctorsList'
import DoctorDetail from './pages/DoctorDetail'
import PatientsList from './pages/PatientsList'
import PatientDetail from './pages/PatientDetail'

function RequireAuth({ children }: { children: React.ReactNode }) {
  const token = localStorage.getItem('tosumo_token')
  if (!token) return <Navigate to="/login" replace />
  return <>{children}</>
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/register/doctor" element={<DoctorRegister />} />
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
          <Route path="medecins/:id" element={<DoctorDetail />} />
          <Route path="patients" element={<PatientsList />} />
          <Route path="patients/:id" element={<PatientDetail />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}
