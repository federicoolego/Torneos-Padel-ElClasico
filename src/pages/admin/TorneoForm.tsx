import { useEffect, useState, type FormEvent } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { ArrowLeft } from 'lucide-react'
import { supabase, mensajeError } from '../../lib/supabase'
import { useAuth } from '../../context/AuthContext'
import type { Categoria, EstadoTorneo, Torneo, TorneoCategoriaVista } from '../../lib/types'
import { aInputLocal, desdeInputLocal, ESTADO_TORNEO_LABEL } from '../../lib/formato'
import { Alerta, Button, Card, Field, Input, Select, Spinner, Textarea, Titulo } from '../../components/ui'

/** 'YYYY-MM-DD' → el día anterior, en el mismo formato */
function diaAnterior(fecha: string) {
  const d = new Date(`${fecha}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() - 1)
  return d.toISOString().slice(0, 10)
}

interface CatForm { activa: boolean; cupo_max: number; cupo_min: number; tcId?: string; inscriptas: number }

export default function TorneoForm() {
  const { id } = useParams()
  const nav = useNavigate()
  const { categorias, jugador } = useAuth()
  const nuevo = !id
  const [cargando, setCargando] = useState(!nuevo)
  const [f, setF] = useState({
    nombre: '', descripcion: '', fecha_desde: '', fecha_hasta: '', cierre: '',
    observaciones: '', precio: '', estado: 'borrador' as EstadoTorneo,
    americano: false, games: 9,
  })
  const [cats, setCats] = useState<Record<number, CatForm>>({})
  const [error, setError] = useState('')
  const [ok, setOk] = useState('')
  const [guardando, setGuardando] = useState(false)

  useEffect(() => {
    const base: Record<number, CatForm> = {}
    categorias.forEach((c) => (base[c.id] = { activa: false, cupo_max: 24, cupo_min: 6, inscriptas: 0 }))
    if (nuevo) return setCats(base)
    ;(async () => {
      const [t, tc] = await Promise.all([
        supabase.from('torneos').select('*').eq('id', id!).single(),
        supabase.from('v_torneo_categorias').select('*').eq('torneo_id', id!),
      ])
      const tor = t.data as Torneo
      if (tor) {
        setF({
          nombre: tor.nombre, descripcion: tor.descripcion ?? '', fecha_desde: tor.fecha_desde, fecha_hasta: tor.fecha_hasta,
          cierre: aInputLocal(tor.cierre_inscripcion), observaciones: tor.observaciones ?? '',
          precio: tor.precio_inscripcion?.toString() ?? '', estado: tor.estado,
          americano: tor.americano, games: tor.games_set_unico ?? 9,
        })
      }
      ;((tc.data as TorneoCategoriaVista[]) ?? []).forEach((c) => {
        base[c.categoria_id] = { activa: true, cupo_max: c.cupo_max, cupo_min: c.cupo_min, tcId: c.id, inscriptas: c.inscriptas ?? 0 }
      })
      setCats({ ...base })
      setCargando(false)
    })()
  }, [id, nuevo, categorias])

  async function guardar(e: FormEvent) {
    e.preventDefault()
    setError(''); setOk('')
    const fechaHasta = f.americano ? f.fecha_desde : f.fecha_hasta
    if (!f.fecha_desde) return setError(f.americano ? 'Completá la fecha del torneo' : 'Completá la fecha de inicio del torneo')
    if (!fechaHasta) return setError('Completá la fecha de fin del torneo')
    if (!f.cierre) return setError('Completá la fecha y hora de cierre de inscripción')
    if (fechaHasta < f.fecha_desde) return setError('La fecha hasta no puede ser anterior a la fecha desde')
    // f.cierre viene del datetime-local ('YYYY-MM-DDTHH:mm'): sus 10 primeros caracteres son la fecha
    if (f.cierre.slice(0, 10) >= fechaHasta)
      return setError(`El cierre de inscripción tiene que ser anterior a la fecha de fin del torneo (${fechaHasta.split('-').reverse().join('/')})`)
    if (!Object.values(cats).some((c) => c.activa)) return setError('Habilitá al menos una categoría')
    const quitadasConInscriptos = Object.entries(cats).filter(([, c]) => !c.activa && c.tcId && c.inscriptas > 0)
    if (quitadasConInscriptos.length) return setError('No podés quitar categorías que ya tienen parejas inscriptas')

    setGuardando(true)
    const datos = {
      nombre: f.nombre.trim(), descripcion: f.descripcion.trim() || null, fecha_desde: f.fecha_desde, fecha_hasta: fechaHasta,
      americano: f.americano, games_set_unico: f.americano ? f.games : null,
      cierre_inscripcion: desdeInputLocal(f.cierre), observaciones: f.observaciones.trim() || null,
      precio_inscripcion: f.precio ? Number(f.precio) : null, estado: f.estado,
    }
    const res = nuevo
      ? await supabase.from('torneos').insert({ ...datos, created_by: jugador!.id }).select('id').single()
      : await supabase.from('torneos').update(datos).eq('id', id!).select('id').single()
    if (res.error) { setGuardando(false); return setError(mensajeError(res.error)) }
    const torneoId = res.data.id as string

    for (const [catId, c] of Object.entries(cats)) {
      let r
      if (c.activa && !c.tcId) {
        r = await supabase.from('torneo_categorias').insert({ torneo_id: torneoId, categoria_id: Number(catId), cupo_max: c.cupo_max, cupo_min: c.cupo_min })
      } else if (c.activa && c.tcId) {
        r = await supabase.from('torneo_categorias').update({ cupo_max: c.cupo_max, cupo_min: c.cupo_min }).eq('id', c.tcId)
      } else if (!c.activa && c.tcId) {
        r = await supabase.from('torneo_categorias').delete().eq('id', c.tcId)
      }
      if (r?.error) { setGuardando(false); return setError(mensajeError(r.error)) }
    }
    setGuardando(false)
    if (nuevo) nav(`/admin/torneos/${torneoId}`, { replace: true })
    else setOk('Torneo guardado')
  }

  if (cargando) return <Spinner />
  /** Último momento válido para el cierre: el día anterior a la fecha de fin */
  const finTorneo = f.americano ? f.fecha_desde : f.fecha_hasta
  const maxCierre = finTorneo ? `${diaAnterior(finTorneo)}T23:59` : undefined
  const set = (k: keyof typeof f) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => setF({ ...f, [k]: e.target.value })

  return (
    <>
      <Link to="/admin/torneos" className="mb-4 inline-flex items-center gap-1 text-sm font-medium text-noche/60 hover:text-noche"><ArrowLeft className="h-4 w-4" aria-hidden /> Armado de torneos</Link>
      <Titulo bajada={nuevo ? 'Guardalo como borrador y publicalo cuando quieras abrir la inscripción.' : undefined}>{nuevo ? 'Nuevo torneo' : f.nombre}</Titulo>
      <form onSubmit={guardar} className="grid gap-6 lg:grid-cols-[1.3fr_1fr]">
        <Card>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="sm:col-span-2"><Field label="Nombre"><Input value={f.nombre} onChange={set('nombre')} required /></Field></div>
            <div className="sm:col-span-2"><Field label="Descripción"><Textarea value={f.descripcion} onChange={set('descripcion')} /></Field></div>
            <div className="sm:col-span-2 rounded-lg bg-vidrio p-3">
              <label className="flex items-center gap-2 text-sm font-semibold">
                <input type="checkbox" checked={f.americano} onChange={(e) => setF({ ...f, americano: e.target.checked })} />
                Torneo americano
              </label>
              <p className="mt-1 text-xs text-noche/60">Se juega en el día, a un solo set. No se puede cambiar una vez cargados resultados.</p>
              {f.americano && (
                <div className="mt-3 flex items-center gap-2 text-sm">
                  Un set a
                  <Select value={f.games} onChange={(e) => setF({ ...f, games: Number(e.target.value) })} className="w-20 py-1" aria-label="Games por set">
                    <option value={7}>7</option>
                    <option value={9}>9</option>
                  </Select>
                  games
                </div>
              )}
            </div>
            {f.americano ? (
              <Field label="Fecha"><Input type="date" value={f.fecha_desde} onChange={set('fecha_desde')} required /></Field>
            ) : (
              <>
                <Field label="Fecha desde"><Input type="date" value={f.fecha_desde} onChange={set('fecha_desde')} required /></Field>
                <Field label="Fecha hasta"><Input type="date" value={f.fecha_hasta} onChange={set('fecha_hasta')} required /></Field>
              </>
            )}
            <Field label="Cierre de inscripción" hint="Fecha y hora, anterior a la fecha de fin del torneo. Después del cierre no se puede cancelar ni editar.">
              <Input type="datetime-local" value={f.cierre} onChange={set('cierre')} max={maxCierre} required />
            </Field>
            <Field label="Precio de inscripción (por pareja)"><Input type="number" min="0" step="100" value={f.precio} onChange={set('precio')} /></Field>
            <div className="sm:col-span-2"><Field label="Observaciones"><Textarea value={f.observaciones} onChange={set('observaciones')} placeholder="Premios, pelotas, reglamento, etc." /></Field></div>
            <div className="sm:col-span-2">
              <Field label="Estado" hint="Borrador: solo lo ves vos. Inscripción abierta: visible y admite inscripciones hasta el cierre.">
                <Select value={f.estado} onChange={set('estado')}>
                  {(Object.keys(ESTADO_TORNEO_LABEL) as EstadoTorneo[]).map((e) => <option key={e} value={e}>{ESTADO_TORNEO_LABEL[e]}</option>)}
                </Select>
              </Field>
            </div>
          </div>
        </Card>
        <Card>
          <h2 className="font-display text-2xl font-bold">Categorías</h2>
          <p className="mb-4 text-xs text-noche/60">Cupo máximo 24 parejas, mínimo 6 para que se arme la categoría.</p>
          {([
            ['Por categoría', categorias.filter((c) => c.tipo === 'nivel')],
            ['Por suma', categorias.filter((c) => c.tipo === 'suma')],
          ] as [string, Categoria[]][]).map(([titulo, lista]) => (
          <div key={titulo} className="mb-4">
          <h3 className="mb-1 text-xs font-semibold text-noche/55">{titulo}</h3>
          <ul className="divide-y divide-noche/10">
            {lista.filter((c) => c.activa || cats[c.id]?.tcId).map((c) => {
              const v = cats[c.id]
              if (!v) return null
              const upd = (p: Partial<CatForm>) => setCats({ ...cats, [c.id]: { ...v, ...p } })
              return (
                <li key={c.id} className="flex flex-wrap items-center gap-3 py-2.5">
                  <label className="flex min-w-[10rem] flex-1 items-center gap-2 text-sm font-medium">
                    <input type="checkbox" checked={v.activa} onChange={(e) => upd({ activa: e.target.checked })} disabled={v.inscriptas > 0} />
                    {c.nombre}
                    {v.inscriptas > 0 && <span className="text-xs text-noche/50">({v.inscriptas} inscriptas)</span>}
                  </label>
                  {v.activa && (
                    <div className="flex items-center gap-2 text-xs text-noche/60">
                      mín <Input type="number" min={6} max={24} value={v.cupo_min} onChange={(e) => upd({ cupo_min: Number(e.target.value) })} className="w-16 py-1" />
                      máx <Input type="number" min={6} max={24} value={v.cupo_max} onChange={(e) => upd({ cupo_max: Number(e.target.value) })} className="w-16 py-1" />
                    </div>
                  )}
                  {v.tcId && id && <Link to={`/admin/torneos/${id}/categoria/${v.tcId}`} className="text-xs font-semibold text-cancha">Gestionar</Link>}
                </li>
              )
            })}
          </ul>
          </div>
          ))}
        </Card>
        <div className="lg:col-span-2">
          {error && <div className="mb-3"><Alerta tipo="error">{error}</Alerta></div>}
          {ok && <div className="mb-3"><Alerta tipo="ok">{ok}</Alerta></div>}
          <Button type="submit" cargando={guardando}>{nuevo ? 'Crear torneo' : 'Guardar cambios'}</Button>
        </div>
      </form>
    </>
  )
}