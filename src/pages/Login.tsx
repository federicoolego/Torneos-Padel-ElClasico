import { useState, type FormEvent } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { supabase, dniAEmail, mensajeError } from '../lib/supabase'
import { Alerta, Button, Field, Input } from '../components/ui'
import { Marca } from '../components/Layout'
import Firma from '../components/Firma'

export function PantallaAcceso({ children }: { children: React.ReactNode }) {
  return (
    <div className="grid min-h-screen lg:grid-cols-[1fr_1.1fr]">
      <div className="relative hidden overflow-hidden bg-noche lg:block">
        {/* Líneas de la pista vistas desde arriba, muy tenues detrás del logo */}
        <svg viewBox="0 0 400 800" className="absolute inset-0 h-full w-full" preserveAspectRatio="xMidYMid slice" aria-hidden>
          <g stroke="#fff" strokeOpacity=".12" strokeWidth="4" fill="none">
            <rect x="60" y="60" width="280" height="680" />
            <line x1="60" y1="250" x2="340" y2="250" />
            <line x1="60" y1="550" x2="340" y2="550" />
            <line x1="200" y1="250" x2="200" y2="550" />
          </g>
          <line x1="60" y1="400" x2="340" y2="400" stroke="#fff" strokeOpacity=".08" strokeWidth="10" />
        </svg>
        {/* Franja con los colores del escudo */}
        <div className="absolute inset-x-0 top-0 flex h-1.5" aria-hidden>
          <span className="flex-1 bg-cancha" /><span className="flex-1 bg-white" /><span className="flex-1 bg-clasico-rojo" />
        </div>
        <div className="absolute inset-0 flex flex-col items-center justify-center px-10 text-center">
          <img src={`${import.meta.env.BASE_URL}logo-el-clasico.webp`} alt="El Clásico Fútbol & Pádel" width={320} height={320} className="w-72 max-w-full" />
          <p className="mt-6 font-display text-5xl font-bold leading-[0.95] text-white">Torneos de Pádel</p>
          <p className="mt-3 max-w-md text-sm text-white/70">Inscribí tu pareja, seguí tus partidos y mirá el cuadro en vivo.</p>
        </div>
      </div>
      <div className="flex items-center justify-center px-6 py-12">
        <div className="w-full max-w-sm">
          <div className="mb-10"><Marca oscuro={false} /></div>
          {children}
          <Firma className="mt-10" />
        </div>
      </div>
    </div>
  )
}

export default function Login() {
  const nav = useNavigate()
  const [dni, setDni] = useState('')
  const [pass, setPass] = useState('')
  const [error, setError] = useState('')
  const [cargando, setCargando] = useState(false)

  async function entrar(e: FormEvent) {
    e.preventDefault()
    setError('')
    setCargando(true)
    const { error } = await supabase.auth.signInWithPassword({ email: dniAEmail(dni), password: pass })
    setCargando(false)
    if (error) return setError(mensajeError(error))
    nav('/torneos')
  }

  return (
    <PantallaAcceso>
      <h1 className="font-display text-4xl font-bold">Ingresar</h1>
      <p className="mt-1 text-sm text-noche/70">Con tu DNI y la contraseña que elegiste al registrarte.</p>
      <form onSubmit={entrar} className="mt-8 space-y-4">
        <Field label="DNI">
          <Input inputMode="numeric" autoComplete="username" value={dni} onChange={(e) => setDni(e.target.value.replace(/\D/g, ''))} required />
        </Field>
        <Field label="Contraseña">
          <Input type="password" autoComplete="current-password" value={pass} onChange={(e) => setPass(e.target.value)} required />
        </Field>
        {error && <Alerta tipo="error">{error}</Alerta>}
        <Button type="submit" cargando={cargando} className="w-full">Ingresar</Button>
      </form>
      <p className="mt-6 text-sm text-noche/70">
        ¿Primera vez? <Link to="/registro" className="font-semibold text-cancha underline-offset-2 hover:underline">Registrate como jugador</Link>
      </p>
      <p className="mt-2 text-xs text-noche/50">¿Olvidaste la contraseña? Pedile al administrador del torneo que te la restablezca.</p>
    </PantallaAcceso>
  )
}