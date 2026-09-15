/** Shared micro-components used across all pages */
import { ReactNode } from 'react'
import { Loader2, AlertCircle } from 'lucide-react'
import clsx from 'clsx'

// ── Avatar ────────────────────────────────────────────────────────────────────
export function Avatar({
  src,
  name,
  size = 'md',
}: {
  src?: string
  name: string
  size?: 'sm' | 'md' | 'lg' | 'xl'
}) {
  const initials = name
    .split(' ')
    .map((w) => w[0])
    .slice(0, 2)
    .join('')
    .toUpperCase()

  const sz = { sm: 'w-8 h-8 text-xs', md: 'w-10 h-10 text-sm', lg: 'w-14 h-14 text-base', xl: 'w-20 h-20 text-xl' }[size]

  if (src) {
    return (
      <img
        src={src}
        alt={name}
        className={clsx(sz, 'rounded-full object-cover shrink-0 ring-2 ring-white')}
        onError={(e) => {
          ;(e.target as HTMLImageElement).style.display = 'none'
        }}
      />
    )
  }
  return (
    <div
      className={clsx(
        sz,
        'rounded-full bg-primary-100 text-primary-700 font-semibold flex items-center justify-center shrink-0 ring-2 ring-white',
      )}
    >
      {initials}
    </div>
  )
}

// ── Badge ─────────────────────────────────────────────────────────────────────
const badgeVariants = {
  green:  'bg-emerald-50 text-emerald-700 ring-1 ring-emerald-200',
  red:    'bg-red-50 text-red-700 ring-1 ring-red-200',
  yellow: 'bg-amber-50 text-amber-700 ring-1 ring-amber-200',
  blue:   'bg-primary-50 text-primary-700 ring-1 ring-primary-200',
  gray:   'bg-slate-100 text-slate-600 ring-1 ring-slate-200',
}

export function Badge({
  children,
  variant = 'gray',
}: {
  children: ReactNode
  variant?: keyof typeof badgeVariants
}) {
  return (
    <span className={clsx('inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium', badgeVariants[variant])}>
      {children}
    </span>
  )
}

// ── Status badge helpers ──────────────────────────────────────────────────────
export function VerifiedBadge({ verified }: { verified: boolean }) {
  return verified ? (
    <Badge variant="green">✓ Vérifié</Badge>
  ) : (
    <Badge variant="yellow">En attente</Badge>
  )
}

export function AppointmentStatusBadge({ status }: { status: string }) {
  const map: Record<string, keyof typeof badgeVariants> = {
    completed: 'green',
    approved:  'blue',
    confirmed: 'blue',
    pending:   'yellow',
    cancelled: 'red',
    no_show:   'red',
    rescheduled: 'gray',
  }
  const labels: Record<string, string> = {
    completed:   'Terminé',
    approved:    'Approuvé',
    confirmed:   'Confirmé',
    pending:     'En attente',
    cancelled:   'Annulé',
    no_show:     'Absent',
    rescheduled: 'Reprogrammé',
  }
  return <Badge variant={map[status] ?? 'gray'}>{labels[status] ?? status}</Badge>
}

// ── Stat card ─────────────────────────────────────────────────────────────────
export function StatCard({
  label,
  value,
  icon: Icon,
  color = 'blue',
  sub,
}: {
  label: string
  value: number | string
  icon: React.ElementType
  color?: 'blue' | 'green' | 'purple' | 'orange'
  sub?: string
}) {
  const colors = {
    blue:   'bg-primary-50 text-primary-600',
    green:  'bg-emerald-50 text-emerald-600',
    purple: 'bg-violet-50 text-violet-600',
    orange: 'bg-amber-50 text-amber-600',
  }
  return (
    <div className="card p-5 flex items-start gap-4">
      <div className={clsx('w-11 h-11 rounded-xl flex items-center justify-center shrink-0', colors[color])}>
        <Icon size={20} />
      </div>
      <div className="min-w-0">
        <p className="text-2xl font-bold text-slate-900 leading-tight">{value}</p>
        <p className="text-sm text-slate-500 mt-0.5">{label}</p>
        {sub && <p className="text-xs text-slate-400 mt-0.5">{sub}</p>}
      </div>
    </div>
  )
}

// ── Loading / Error ───────────────────────────────────────────────────────────
export function Spinner({ className }: { className?: string }) {
  return <Loader2 className={clsx('animate-spin text-primary-600', className)} size={24} />
}

export function PageLoader() {
  return (
    <div className="flex items-center justify-center h-64">
      <Spinner size={32 as never} />
    </div>
  )
}

export function ErrorBanner({ message }: { message: string }) {
  return (
    <div className="flex items-center gap-3 p-4 bg-red-50 border border-red-200 rounded-xl text-red-700 text-sm">
      <AlertCircle size={18} className="shrink-0" />
      {message}
    </div>
  )
}

// ── Search input ──────────────────────────────────────────────────────────────
export function SearchInput({
  value,
  onChange,
  placeholder = 'Rechercher…',
}: {
  value: string
  onChange: (v: string) => void
  placeholder?: string
}) {
  return (
    <input
      type="text"
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      className="input max-w-xs"
    />
  )
}

// ── Empty state ───────────────────────────────────────────────────────────────
export function EmptyState({
  icon: Icon,
  title,
  subtitle,
}: {
  icon: React.ElementType
  title: string
  subtitle?: string
}) {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center text-slate-400">
      <div className="w-14 h-14 rounded-2xl bg-slate-100 flex items-center justify-center mb-4">
        <Icon size={26} />
      </div>
      <p className="text-base font-medium text-slate-500">{title}</p>
      {subtitle && <p className="text-sm mt-1">{subtitle}</p>}
    </div>
  )
}

// ── Page header ───────────────────────────────────────────────────────────────
export function PageHeader({
  title,
  subtitle,
  actions,
}: {
  title: string
  subtitle?: string
  actions?: ReactNode
}) {
  return (
    <div className="flex items-start justify-between gap-4 mb-6">
      <div>
        <h1 className="text-xl font-bold text-slate-900">{title}</h1>
        {subtitle && <p className="text-sm text-slate-500 mt-0.5">{subtitle}</p>}
      </div>
      {actions && <div className="flex items-center gap-2 shrink-0">{actions}</div>}
    </div>
  )
}

// ── Helpers ───────────────────────────────────────────────────────────────────
export function formatDate(iso?: string) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' })
}

export function formatAge(iso?: string) {
  if (!iso) return '—'
  const age = Math.floor((Date.now() - new Date(iso).getTime()) / 3.156e10)
  return `${age} ans`
}
