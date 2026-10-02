import { Navigate, Route, Routes } from 'react-router-dom'
import type { ReactNode } from 'react'
import { useAuth } from './context/AuthContext'
import Layout from './components/Layout'
import { Spinner } from './components/ui'
import Login from './pages/Login'
import Registro from './pages/Registro'
import Perfil from './pages/Perfil'
import CambiarPassword from './pages/CambiarPassword'
import Torneos from './pages/Torneos'
import TorneoDetalle from './pages/TorneoDetalle'
import MisInscripciones from './pages/MisInscripciones'
import MisParejas from './pages/MisParejas'
import MisTorneos from './pages/MisTorneos'
import AdminTorneos from './pages/admin/AdminTorneos'
import TorneoForm from './pages/admin/TorneoForm'
import AdminTorneoCategoria from './pages/admin/AdminTorneoCategoria'
import AdminJugadores from './pages/admin/AdminJugadores'
import AdminSedes from './pages/admin/AdminSedes'
import AdminCategorias from './pages/admin/AdminCategorias'
import AdminEstadisticas from './pages/admin/AdminEstadisticas'
import Calendario from './pages/Calendario'
import Jugadores from './pages/Jugadores'
import AdminLogs from './pages/admin/AdminLogs'
import Ayuda from './pages/Ayuda'

function Privada({ children, soloAdmin, soloEditor }: { children: ReactNode; soloAdmin?: boolean; soloEditor?: boolean }) {
  const { session, jugador, cargando, esAdmin, esEditor } = useAuth()
  if (cargando) return <div className="px-6"><Spinner /></div>
  if (!session) return <Navigate to="/login" replace />
  if (!jugador) return <SinPerfil />
  if (jugador.debe_cambiar_password) return <CambiarPassword />
  if (soloAdmin && !esAdmin) return <Navigate to="/torneos" replace />
  if (soloEditor && !esEditor) return <Navigate to="/torneos" replace />
  return <>{children}</>
}

function SinPerfil() {
  const { salir } = useAuth()
  return (
    <div className="mx-auto max-w-md px-6 py-20 text-center">
      <p className="font-display text-2xl font-semibold">Tu usuario no tiene perfil de jugador</p>
      <p className="mt-2 text-sm text-noche/70">
        Esto pasa cuando la cuenta se creó desde el panel de Supabase. Registrate desde la app con tu DNI.
      </p>
      <button className="mt-6 text-sm font-semibold text-cancha underline" onClick={salir}>Cerrar sesión</button>
    </div>
  )
}

export default function App() {
  const { session, cargando } = useAuth()
  return (
    <Routes>
      <Route path="/login" element={!cargando && session ? <Navigate to="/torneos" replace /> : <Login />} />
      <Route path="/registro" element={!cargando && session ? <Navigate to="/torneos" replace /> : <Registro />} />
      <Route element={<Privada><Layout /></Privada>}>
        <Route path="/" element={<Navigate to="/torneos" replace />} />
        <Route path="/perfil" element={<Perfil />} />
        <Route path="/torneos" element={<Torneos />} />
        <Route path="/torneos/:id" element={<TorneoDetalle />} />
        <Route path="/mis-inscripciones" element={<MisInscripciones />} />
        <Route path="/mis-parejas" element={<MisParejas />} />
        <Route path="/mis-torneos" element={<MisTorneos />} />
        <Route path="/jugadores" element={<Privada><Jugadores /></Privada>} />
        <Route path="/calendario" element={<Privada soloEditor><Calendario /></Privada>} />
        <Route path="/ayuda" element={<Ayuda para="jugador" />} />
        <Route path="/ayuda/editor" element={<Privada soloEditor><Ayuda para="editor" /></Privada>} />
        <Route path="/ayuda/admin" element={<Privada soloAdmin><Ayuda para="admin" /></Privada>} />
        <Route path="/admin/torneos" element={<Privada soloAdmin><AdminTorneos /></Privada>} />
        <Route path="/admin/torneos/nuevo" element={<Privada soloAdmin><TorneoForm /></Privada>} />
        <Route path="/admin/torneos/:id" element={<Privada soloAdmin><TorneoForm /></Privada>} />
        <Route path="/admin/torneos/:id/categoria/:tcId" element={<Privada soloAdmin><AdminTorneoCategoria /></Privada>} />
        <Route path="/admin/jugadores" element={<Privada soloAdmin><AdminJugadores /></Privada>} />
        <Route path="/admin/sedes" element={<Privada soloAdmin><AdminSedes /></Privada>} />
        <Route path="/admin/categorias" element={<Privada soloAdmin><AdminCategorias /></Privada>} />
        <Route path="/admin/estadisticas" element={<Privada soloAdmin><AdminEstadisticas /></Privada>} />
        <Route path="/admin/logs" element={<Privada soloAdmin><AdminLogs /></Privada>} />
      </Route>
      <Route path="*" element={<Navigate to="/torneos" replace />} />
    </Routes>
  )
}