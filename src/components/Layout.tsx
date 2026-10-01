import { useEffect, useState } from 'react'
import { NavLink, Outlet, useLocation } from 'react-router-dom'
import { Trophy, ClipboardList, Users, CalendarDays, UserRound, LogOut, Settings2, IdCard, MapPin, Layers, ShieldCheck, X, BarChart3, CalendarRange, ScrollText, Contact } from 'lucide-react'
import { useAuth } from '../context/AuthContext'
import { ROL_LABEL } from '../lib/formato'
import Firma from './Firma'

const MENU = [
  { to: '/torneos', label: 'Torneos', icono: Trophy },
  { to: '/mis-inscripciones', label: 'Mis Inscripciones', icono: ClipboardList },
  { to: '/mis-parejas', label: 'Mis Parejas', icono: Users },
  { to: '/mis-torneos', label: 'Mis Torneos', icono: CalendarDays },
  { to: '/jugadores', label: 'Jugadores', icono: Contact },
  { to: '/perfil', label: 'Perfil', icono: UserRound },
]

/** En el celu Perfil va arriba (junto a cerrar sesión) para no pasar de 5 íconos + staff abajo */
const MENU_MOVIL = MENU.filter((m) => m.to !== '/perfil')

/** Editor y administrador */
const CALENDARIO = { to: '/calendario', label: 'Calendario de partidos', icono: CalendarRange }

const ADMIN = [
  { to: '/admin/torneos', label: 'Armado de torneos', icono: Settings2 },
  { to: '/admin/estadisticas', label: 'Estadísticas', icono: BarChart3 },
  { to: '/admin/jugadores', label: 'Jugadores', icono: IdCard },
  { to: '/admin/categorias', label: 'Categorías', icono: Layers },
  { to: '/admin/sedes', label: 'Sedes y canchas', icono: MapPin },
  { to: '/admin/logs', label: 'Logs', icono: ScrollText },
]

function Enlace({ to, label, icono: Icono }: (typeof MENU)[number]) {
  return (
    <NavLink
      to={to}
      className={({ isActive }) =>
        `flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
          isActive ? 'bg-white/10 text-white' : 'text-white/65 hover:bg-white/5 hover:text-white'
        }`
      }
    >
      <Icono className="h-4 w-4" aria-hidden />
      {label}
    </NavLink>
  )
}

export default function Layout() {
  const { jugador, esAdmin, esEditor, salir, categorias } = useAuth()
  const cat = categorias.find((c) => c.id === jugador?.categoria_id)
  const [adminAbierto, setAdminAbierto] = useState(false)
  const { pathname } = useLocation()
  const enAdmin = pathname.startsWith('/admin')
  useEffect(() => setAdminAbierto(false), [pathname])

  return (
    <div className="min-h-screen lg:flex">
      {/* Lateral escritorio */}
      <aside className="hidden w-64 shrink-0 flex-col bg-noche px-4 py-6 lg:flex">
        <Marca />
        <nav className="mt-8 flex flex-col gap-1" aria-label="Principal">
          {MENU.map((m) => <Enlace key={m.to} {...m} />)}
        </nav>
        {esEditor && (
          <nav className="mt-8 flex flex-col gap-1" aria-label="Administración">
            <p className="px-3 pb-1 text-xs font-medium text-white/40">{esAdmin ? 'Administración' : 'Resultados'}</p>
            <Enlace {...CALENDARIO} />
            {esAdmin && ADMIN.map((m) => <Enlace key={m.to} {...m} />)}
          </nav>
        )}
        <div className="mt-auto border-t border-white/10 pt-4">
          <p className="truncate text-sm font-semibold text-white">{jugador?.nombre} {jugador?.apellido}</p>
          <p className="text-xs text-white/55">
            {cat?.nombre}
            {jugador && jugador.rol !== 'jugador' && ` · ${ROL_LABEL[jugador.rol]}`}
          </p>
          <button onClick={salir} className="mt-3 flex items-center gap-2 text-xs font-medium text-white/60 hover:text-white">
            <LogOut className="h-3.5 w-3.5" /> Cerrar sesión
          </button>
        </div>
      </aside>

      {/* Barra superior móvil */}
      <header className="flex items-center justify-between bg-noche px-4 py-3 lg:hidden" style={{ paddingTop: 'max(0.75rem, env(safe-area-inset-top))' }}>
        <Marca />
        <div className="flex items-center gap-3">
          <NavLink to="/perfil" aria-label="Perfil" className={({ isActive }) => (isActive ? 'text-pelota' : 'text-white/70')}><UserRound className="h-5 w-5" /></NavLink>
          <button onClick={salir} aria-label="Cerrar sesión" className="text-white/70"><LogOut className="h-5 w-5" /></button>
        </div>
      </header>

      <main className="min-w-0 flex-1 px-4 pb-28 pt-6 sm:px-8 lg:pb-12 lg:pt-10">
        <div className="mx-auto max-w-6xl">
          <Outlet />
          <Firma className="mt-10" />
        </div>
      </main>

      {/* Tab bar móvil */}
      <nav
        aria-label="Principal"
        className={`fixed inset-x-0 bottom-0 z-40 grid border-t border-noche/10 bg-white lg:hidden ${esEditor ? 'grid-cols-6' : 'grid-cols-5'}`}
        style={{ paddingBottom: 'env(safe-area-inset-bottom)' }}
      >
        {MENU_MOVIL.map(({ to, label, icono: Icono }) => (
          <NavLink
            key={to}
            to={to}
            className={({ isActive }) =>
              `flex flex-col items-center gap-0.5 py-2 text-[11px] font-medium leading-tight ${isActive ? 'text-cancha' : 'text-noche/55'}`
            }
          >
            <Icono className="h-5 w-5" aria-hidden />
            <span className="text-center">{to === '/mis-torneos' ? 'Mis torneos' : label.replace('Mis ', '')}</span>
          </NavLink>
        ))}
        {esEditor && !esAdmin && (
          <NavLink
            to="/calendario"
            className={({ isActive }) => `flex flex-col items-center gap-0.5 py-2 text-[11px] font-medium leading-tight ${isActive ? 'text-cancha' : 'text-noche/55'}`}
          >
            <CalendarRange className="h-5 w-5" aria-hidden />
            <span>Calendario</span>
          </NavLink>
        )}
        {esAdmin && (
          <button
            onClick={() => setAdminAbierto(true)}
            aria-haspopup="dialog"
            className={`flex flex-col items-center gap-0.5 py-2 text-[11px] font-medium leading-tight ${enAdmin || pathname === '/calendario' ? 'text-cancha' : 'text-noche/55'}`}
          >
            <ShieldCheck className="h-5 w-5" aria-hidden />
            <span>Admin</span>
          </button>
        )}
      </nav>

      {/* Menú de administración en móvil */}
      {esAdmin && adminAbierto && (
        <div className="fixed inset-0 z-50 bg-noche/50 lg:hidden" onClick={() => setAdminAbierto(false)}>
          <div
            role="dialog"
            aria-modal="true"
            aria-label="Administración"
            onClick={(e) => e.stopPropagation()}
            className="absolute inset-x-0 bottom-0 rounded-t-2xl bg-noche px-4 pt-4 text-white"
            style={{ paddingBottom: 'max(1rem, env(safe-area-inset-bottom))' }}
          >
            <div className="mb-3 flex items-center justify-between">
              <p className="font-display text-xl font-bold">Administración</p>
              <button onClick={() => setAdminAbierto(false)} aria-label="Cerrar" className="text-white/70"><X className="h-5 w-5" /></button>
            </div>
            <nav className="flex flex-col gap-1" aria-label="Administración">
              <Enlace {...CALENDARIO} />
              {ADMIN.map((m) => <Enlace key={m.to} {...m} />)}
            </nav>
          </div>
        </div>
      )}
    </div>
  )
}

export function Marca({ oscuro = true }: { oscuro?: boolean }) {
  return (
    <div className="flex items-center gap-3">
      <img
        src={`${import.meta.env.BASE_URL}logo-el-clasico.webp`}
        alt="El Clásico Fútbol & Pádel"
        width={44}
        height={44}
        className={`h-11 w-11 shrink-0 ${oscuro ? '' : 'rounded-lg'}`}
      />
      <div className="leading-none">
        <span className={`block font-display text-2xl font-bold ${oscuro ? 'text-white' : 'text-noche'}`}>Torneos de Pádel</span>
      </div>
    </div>
  )
}