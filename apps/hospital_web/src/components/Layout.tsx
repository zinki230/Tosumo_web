import { useState } from 'react'
import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import {
  LayoutDashboard,
  Stethoscope,
  Users,
  GitBranch,
  LogOut,
  Menu,
  X,
  Activity,
  CalendarDays,
  ShieldCheck,
  ClipboardList,
  BadgeCheck,
} from 'lucide-react'
import clsx from 'clsx'
import { authApi } from '../services/api'

const NAV = [
  { to: '/', label: 'Vue générale', icon: LayoutDashboard },
  { to: '/suivi', label: 'Suivi patient', icon: GitBranch },
  { to: '/medecins', label: 'Médecins', icon: Stethoscope },
  { to: '/patients', label: 'Patients', icon: Users },
  { to: '/rendez-vous', label: 'Rendez-vous', icon: CalendarDays, adminOnly: true },
  { to: '/comptes', label: 'Comptes', icon: ShieldCheck, adminOnly: true },
  { to: '/verifications', label: 'Vérifier les médecins', icon: BadgeCheck, adminOnly: true },
  { to: '/journal', label: 'Journal d’audit', icon: ClipboardList, adminOnly: true },
]

export default function Layout() {
  const [open, setOpen] = useState(false)
  const navigate = useNavigate()
  let user: { role?: string; email?: string; phone?: string } = {}
  try { user = JSON.parse(localStorage.getItem('tosumo_user') ?? '{}') } catch { user = {} }
  const isSystemAdmin = user.role === 'admin' || user.role === 'superadmin'

  async function handleLogout() {
    try { await authApi.logoutRemote() } catch { authApi.logout() }
    navigate('/login')
  }

  return (
    <div className="flex h-screen overflow-hidden bg-slate-50">
      {/* ── Sidebar ── */}
      <aside
        className={clsx(
          'fixed inset-y-0 left-0 z-40 flex flex-col w-64 bg-white border-r border-slate-200 transition-transform duration-200',
          open ? 'translate-x-0' : '-translate-x-full',
          'lg:relative lg:translate-x-0',
        )}
      >
        {/* Logo */}
        <div className="flex items-center gap-3 px-6 py-5 border-b border-slate-100">
          <div className="flex items-center justify-center w-10 h-10 rounded-lg bg-white border border-slate-200">
            <img 
              src="/images/TOSUMO.png" 
              alt="TOSUMO" 
              className="w-8 h-8 object-contain"
            />
          </div>
          <div>
            <p className="text-sm font-bold text-slate-900 leading-tight">TOSUMO</p>
              <p className="text-[11px] text-slate-400 leading-tight">Administration santé</p>
          </div>
        </div>

        {/* Nav */}
        <nav className="flex-1 px-3 py-4 space-y-0.5 overflow-y-auto">
          {NAV.filter((item) => !item.adminOnly || isSystemAdmin).map(({ to, label, icon: Icon }) => (
            <NavLink
              key={to}
              to={to}
              end={to === '/'}
              onClick={() => setOpen(false)}
              className={({ isActive }) =>
                clsx(
                  'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors',
                  isActive
                    ? 'bg-primary-50 text-primary-700'
                    : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900',
                )
              }
            >
              <Icon size={17} />
              {label}
            </NavLink>
          ))}
        </nav>

        {/* Logout */}
        <div className="px-3 py-4 border-t border-slate-100">
          <button
            onClick={handleLogout}
            className="flex items-center gap-3 w-full px-3 py-2.5 rounded-lg text-sm font-medium text-slate-500 hover:bg-red-50 hover:text-red-600 transition-colors"
          >
            <LogOut size={17} />
            Déconnexion
          </button>
        </div>
      </aside>

      {/* Overlay mobile */}
      {open && (
        <div
          className="fixed inset-0 z-30 bg-black/30 lg:hidden"
          onClick={() => setOpen(false)}
        />
      )}

      {/* ── Main ── */}
      <div className="flex flex-col flex-1 min-w-0 overflow-hidden">
        {/* Topbar */}
        <header className="flex items-center gap-4 px-6 py-4 bg-white border-b border-slate-200 shrink-0">
          <button
            className="lg:hidden p-1.5 rounded-md text-slate-500 hover:bg-slate-100"
            onClick={() => setOpen(!open)}
          >
            {open ? <X size={20} /> : <Menu size={20} />}
          </button>
          <div className="flex-1" />
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-full bg-primary-100 flex items-center justify-center text-primary-700 text-xs font-bold">
              {(user.email ?? user.phone ?? 'A').slice(0, 1).toUpperCase()}
            </div>
            <span className="hidden sm:block text-sm font-medium text-slate-700">{user.email ?? (isSystemAdmin ? 'Administrateur' : 'Centre de santé')}</span>
          </div>
        </header>

        {/* Page content */}
        <main className="flex-1 overflow-y-auto">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
