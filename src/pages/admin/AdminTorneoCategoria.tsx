import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { ArrowLeft, Phone, UserPlus } from 'lucide-react'
import { supabase, mensajeError } from '../../lib/supabase'
import type { InscriptoAdmin, PartidoVista, Sede, Torneo, TorneoCategoriaVista, Zona } from '../../lib/types'
import { ESTADO_CATEGORIA_LABEL, fechaHora } from '../../lib/formato'
import { Alerta, Badge, Button, Spinner, Tabs, Titulo, Vacio } from '../../components/ui'
import { ZonaTabla } from '../../components/Zonas'
import ArmadoZonas, { Horario } from '../../components/admin/ArmadoZonas'
import Programacion from '../../components/admin/Programacion'
import InscribirPareja from '../../components/admin/InscribirPareja'
import ArmadoCuadro from '../../components/admin/ArmadoCuadro'
import Bracket from '../../components/Bracket'
import ResultadoModal from '../../components/ResultadoModal'

type Tab = 'inscriptos' | 'zonas' | 'programacion' | 'playoff'

export default function AdminTorneoCategoria() {
  const { id, tcId } = useParams()
  const [torneo, setTorneo] = useState<Torneo | null>(null)
  const [tc, setTc] = useState<TorneoCategoriaVista | null>(null)
  const [inscriptos, setInscriptos] = useState<InscriptoAdmin[]>([])
  const [zonas, setZonas] = useState<(Zona & { zona_parejas: { inscripcion_id: string; posicion_sorteo: number }[] })[]>([])
  const [ocupados, setOcupados] = useState<PartidoVista[]>([])
  const [partidos, setPartidos] = useState<PartidoVista[]>([])
  const [sedes, setSedes] = useState<Sede[]>([])
  const [tab, setTab] = useState<Tab>('inscriptos')
  const [msg, setMsg] = useState<{ tipo: 'ok' | 'error'; txt: string } | null>(null)
  const [trabajando, setTrabajando] = useState(false)
  const [elegido, setElegido] = useState<PartidoVista | null>(null)
  const [inscribir, setInscribir] = useState(false)

  const cargar = useCallback(async () => {
    const [t, c, i, z, p, s] = await Promise.all([
      supabase.from('torneos').select('*').eq('id', id!).single(),
      supabase.from('v_torneo_categorias').select('*').eq('id', tcId!).single(),
      supabase.rpc('admin_inscriptos', { p_torneo_categoria: tcId }),
      supabase.from('zonas').select('*, zona_parejas(inscripcion_id, posicion_sorteo)').eq('torneo_categoria_id', tcId!).order('nombre'),
      supabase.from('v_partidos').select('*').eq('torneo_categoria_id', tcId!).order('ronda').order('orden'),
      supabase.from('sedes').select('*, canchas(*)').eq('activa', true).order('nombre'),
    ])
    const tor = t.data as Torneo | null
    if (tor) {
      // partidos de todos los torneos en las fechas de este, para ver la ocupación de canchas
      const hasta = new Date(`${tor.fecha_hasta}T00:00:00-03:00`)
      hasta.setDate(hasta.getDate() + 1)
      const { data: oc } = await supabase.from('v_partidos').select('*')
        .gte('fecha_hora', `${tor.fecha_desde}T00:00:00-03:00`).lt('fecha_hora', hasta.toISOString()).neq('estado', 'bye')
      setOcupados((oc as PartidoVista[]) ?? [])
    }
    setTorneo(tor)
    setTc(c.data as TorneoCategoriaVista)
    setInscriptos((i.data as InscriptoAdmin[]) ?? [])
    setZonas((z.data as typeof zonas) ?? [])
    setPartidos((p.data as PartidoVista[]) ?? [])
    setSedes((s.data as Sede[]) ?? [])
  }, [id, tcId])
  useEffect(() => { cargar() }, [cargar])

  const activos = inscriptos.filter((i) => i.estado === 'activa')
  const dias = useMemo(() => {
    if (!torneo) return []
    const out: string[] = []
    for (let d = new Date(`${torneo.fecha_desde}T12:00:00-03:00`); d <= new Date(`${torneo.fecha_hasta}T12:00:00-03:00`); d.setDate(d.getDate() + 1)) {
      out.push(d.toLocaleDateString('en-CA', { timeZone: 'America/Argentina/Buenos_Aires' }))
    }
    return out
  }, [torneo])
  const zonasIniciales = useMemo(
    () => zonas.map((z) => [...z.zona_parejas].sort((a, b) => a.posicion_sorteo - b.posicion_sorteo).map((zp) => zp.inscripcion_id)),
    [zonas],
  )
  const nombres = useMemo(() => Object.fromEntries(inscriptos.map((i) => [i.id, i.pareja])), [inscriptos])
  const horarios = useMemo(() => Object.fromEntries(inscriptos.map((i) => [i.id, i.problemas_horario])), [inscriptos])

  async function ejecutar(fn: () => PromiseLike<{ error: unknown }>, okTxt: string) {
    setMsg(null)
    setTrabajando(true)
    const { error } = await fn()
    setTrabajando(false)
    if (error) return setMsg({ tipo: 'error', txt: mensajeError(error) })
    setMsg({ tipo: 'ok', txt: okTxt })
    cargar()
  }

  if (!torneo || !tc) return <Spinner />
  const cierreVencido = new Date(torneo.cierre_inscripcion).getTime() <= Date.now()
  const zonaPartidos = partidos.filter((p) => p.fase === 'zona')
  const playoff = partidos.filter((p) => p.fase !== 'zona')
  const pendientesZona = zonaPartidos.filter((p) => p.estado === 'pendiente').length
  const hayResultados = partidos.some((p) => p.estado === 'finalizado' || p.estado === 'wo')
  const puedeInscribir = tc.estado === 'inscripcion' || (tc.estado === 'zonas' && !hayResultados)
  const enZona = new Set(zonas.flatMap((z) => z.zona_parejas.map((zp) => zp.inscripcion_id)))
  const sinZona = zonas.length > 0 ? activos.filter((i) => !enZona.has(i.id)).length : 0

  return (
    <>
      <Link to="/admin/torneos" className="mb-4 inline-flex items-center gap-1 text-sm font-medium text-noche/60 hover:text-noche"><ArrowLeft className="h-4 w-4" aria-hidden /> Armado de torneos</Link>
      <Titulo
        bajada={<>{torneo.nombre} · <span className="num">{activos.length}/{tc.cupo_max}</span> parejas · cierre {fechaHora(torneo.cierre_inscripcion)}</>}
        accion={<div className="flex items-center gap-2"><Badge tono="azul">{ESTADO_CATEGORIA_LABEL[tc.estado]}</Badge><Link to={`/torneos/${torneo.id}?cat=${tc.id}`} className="text-sm font-semibold text-cancha">Ver público</Link></div>}
      >
        {tc.categoria}
      </Titulo>

      {msg && <div className="mb-4"><Alerta tipo={msg.tipo}>{msg.txt}</Alerta></div>}

      <Tabs<Tab>
        valor={tab}
        onChange={(t) => { setTab(t); setMsg(null) }}
        opciones={[
          { id: 'inscriptos', label: 'Inscriptos' },
          { id: 'zonas', label: 'Zonas' },
          { id: 'programacion', label: 'Programación' },
          { id: 'playoff', label: 'Playoff' },
        ]}
      />

      <div className="mt-6">
        {tab === 'inscriptos' && (
          <Inscriptos
            lista={inscriptos}
            tc={tc}
            trabajando={trabajando}
            onPagada={(i) => ejecutar(() => supabase.from('inscripciones').update({ pagada: !i.pagada }).eq('id', i.id), i.pagada ? 'Pago desmarcado' : 'Pago registrado')}
            onCancelar={(i) => confirm(i.zona
              ? `¿Dar de baja a ${i.jugador1} y ${i.jugador2}? Ya están en la zona ${i.zona}: se borran los partidos de esa zona y vas a tener que rearmarla en la pestaña Zonas.`
              : `¿Cancelar la inscripción de ${i.jugador1} y ${i.jugador2}?`) && ejecutar(() => supabase.from('inscripciones').update({ estado: 'cancelada' }).eq('id', i.id), 'Inscripción cancelada')}
            onSuspender={() => confirm('¿Suspender la categoría por falta de parejas?') && ejecutar(() => supabase.from('torneo_categorias').update({ estado: 'suspendida' }).eq('id', tc.id), 'Categoría suspendida')}
            onReabrir={() => ejecutar(() => supabase.from('torneo_categorias').update({ estado: 'inscripcion' }).eq('id', tc.id), 'Categoría reabierta')}
            onInscribir={puedeInscribir ? () => setInscribir(true) : undefined}
            sinZona={sinZona}
            hayResultados={hayResultados}
          />
        )}

        {tab === 'zonas' && (
          <div className="space-y-6">
            {tc.estado !== 'playoff' && tc.estado !== 'finalizada' && tc.estado !== 'suspendida' && !zonaPartidos.some((p) => p.estado === 'finalizado' || p.estado === 'wo') ? (
              <ArmadoZonas
                activos={activos}
                inicial={zonasIniciales}
                cupoMin={tc.cupo_min}
                cierreVencido={cierreVencido}
                trabajando={trabajando}
                onGuardar={(zs) => ejecutar(() => supabase.rpc('armar_zonas_manual', { p_torneo_categoria: tc.id, p_zonas: zs }), 'Zonas guardadas con sus partidos. Ahora programalos en la pestaña Programación.')}
              />
            ) : zonas.length > 0 && (
              <Alerta>Ya hay resultados cargados: las zonas no se pueden modificar.</Alerta>
            )}
            {zonas.length > 0 && zonaPartidos.some((p) => p.estado === 'finalizado' || p.estado === 'wo') && (
              <div className="grid gap-5 lg:grid-cols-2">
                {zonas.map((z) => (
                  <ZonaTabla key={z.id} zona={z} nombres={nombres} cantidad={z.zona_parejas.length} partidos={zonaPartidos.filter((p) => p.zona_id === z.id)} />
                ))}
              </div>
            )}
            {zonas.length === 0 && tc.estado !== 'inscripcion' && <Vacio titulo="Todavía no hay zonas" />}
          </div>
        )}

        {tab === 'programacion' && (
          <Programacion
            partidos={partidos}
            sedes={sedes}
            horarios={horarios}
            ocupados={ocupados}
            tcId={tc.id}
            dias={dias}
            onGuardado={cargar}
            onResultado={setElegido}
          />
        )}

        {tab === 'playoff' && (
          <div className="space-y-4">
            {zonas.length === 0 ? (
              <Vacio titulo="Todavía no hay zonas">Armá las zonas para poder definir los cruces del playoff.</Vacio>
            ) : sinZona > 0 ? (
              <Alerta tipo="aviso">Hay {sinZona} pareja(s) inscriptas sin zona: ubicalas en la pestaña Zonas antes de armar el cuadro.</Alerta>
            ) : playoff.some((p) => p.estado === 'finalizado' || p.estado === 'wo') ? (
              <Alerta>El playoff ya tiene resultados cargados: el cuadro no se puede modificar.</Alerta>
            ) : (tc.estado === 'zonas' || tc.estado === 'playoff') && (
              <ArmadoCuadro
                zonas={zonas}
                playoff={playoff}
                trabajando={trabajando}
                onGuardar={(cruces) => ejecutar(
                  () => supabase.rpc('armar_cuadro', { p_torneo_categoria: tc.id, p_cruces: cruces }),
                  pendientesZona > 0 ? 'Cuadro guardado. Los clasificados se van a ubicar solos cuando termine cada zona.' : 'Cuadro guardado',
                )}
              />
            )}
            {playoff.length > 0 && <Bracket partidos={playoff} onElegir={setElegido} />}
          </div>
        )}
      </div>

      {inscribir && (
        <InscribirPareja
          tcId={tc.id}
          categoria={tc.categoria}
          conZonas={zonas.length > 0}
          onCerrar={() => setInscribir(false)}
          onHecho={(txt) => { setInscribir(false); setMsg({ tipo: 'ok', txt }); cargar() }}
        />
      )}
      {elegido && <ResultadoModal partido={elegido} esAdmin onCerrar={() => setElegido(null)} onGuardado={() => { setElegido(null); cargar() }} />}
    </>
  )
}

function Inscriptos({
  lista, tc, trabajando, onPagada, onCancelar, onSuspender, onReabrir, onInscribir, sinZona, hayResultados,
}: {
  lista: InscriptoAdmin[]
  tc: TorneoCategoriaVista
  trabajando: boolean
  onPagada: (i: InscriptoAdmin) => void
  onCancelar: (i: InscriptoAdmin) => void
  onSuspender: () => void
  onReabrir: () => void
  onInscribir?: () => void
  sinZona: number
  hayResultados: boolean
}) {
  const activos = lista.filter((i) => i.estado === 'activa')
  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-noche/70"><span className="num font-semibold text-noche">{activos.length}</span> de {tc.cupo_max} parejas activas</p>
        {onInscribir && (
          <Button onClick={onInscribir} disabled={activos.length >= tc.cupo_max}><UserPlus className="h-4 w-4" aria-hidden /> Inscribir pareja</Button>
        )}
      </div>
      {sinZona > 0 && <Alerta tipo="aviso">Hay {sinZona} pareja(s) inscriptas sin zona. Ubicalas en la pestaña Zonas y guardá.</Alerta>}
      {tc.estado === 'inscripcion' && activos.length < tc.cupo_min && (
        <Alerta tipo="aviso">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <span>Hay {activos.length} parejas y el mínimo es {tc.cupo_min}. Si no se completa, podés suspender la categoría.</span>
            <Button variante="peligro" onClick={onSuspender} disabled={trabajando}>Suspender categoría</Button>
          </div>
        </Alerta>
      )}
      {tc.estado === 'suspendida' && (
        <Alerta tipo="aviso"><div className="flex flex-wrap items-center justify-between gap-3"><span>La categoría está suspendida.</span><Button variante="secundario" onClick={onReabrir}>Reabrir inscripción</Button></div></Alerta>
      )}
      {lista.length === 0 ? <Vacio titulo="Todavía no hay inscriptos" /> : (
        <div className="overflow-x-auto rounded-xl bg-white ring-1 ring-noche/10">
          <table className="w-full min-w-[560px] text-sm">
            <thead>
              <tr className="border-b border-noche/10 text-left text-xs text-noche/55">
                <th className="px-4 py-2 font-medium">Pareja</th>
                <th className="hidden py-2 font-medium lg:table-cell">Problemas de horario</th>
                <th className="py-2 font-medium">Zona</th>
                <th className="py-2 font-medium">Pago</th>
                <th className="px-4 py-2" />
              </tr>
            </thead>
            <tbody>
              {lista.map((i) => (
                <tr key={i.id} className={`border-b border-noche/5 align-top last:border-0 ${i.estado === 'cancelada' ? 'opacity-50' : ''}`}>
                  <td className="px-4 py-3">
                    {[[i.jugador1, i.categoria1, i.telefono1, i.dni1], [i.jugador2, i.categoria2, i.telefono2, i.dni2]].map(([n, c, t, d]) => (
                      <div key={d} className="mb-1 last:mb-0">
                        <span className="font-medium">{n}</span> <span className="text-xs text-noche/55">{c} · DNI {d}</span>
                        <a href={`tel:${t}`} className="ml-2 inline-flex items-center gap-1 text-xs text-cancha"><Phone className="h-3 w-3" aria-hidden />{t}</a>
                      </div>
                    ))}
                    <div className="mt-1 lg:hidden"><Horario texto={i.problemas_horario} /></div>
                    {i.estado === 'cancelada' && <Badge tono="rojo">Cancelada</Badge>}
                  </td>
                  <td className="hidden max-w-xs py-3 pr-4 lg:table-cell"><Horario texto={i.problemas_horario} /></td>
                  <td className="py-3">{i.zona ?? '—'}</td>
                  <td className="py-3">
                    <label className="inline-flex items-center gap-2">
                      <input type="checkbox" checked={i.pagada} onChange={() => onPagada(i)} disabled={trabajando} /> {i.pagada ? 'Pagada' : 'Pendiente'}
                    </label>
                  </td>
                  <td className="px-4 py-3 text-right">
                    {i.estado === 'activa' && !hayResultados && <Button variante="fantasma" onClick={() => onCancelar(i)} disabled={trabajando}>{i.zona ? 'Dar de baja' : 'Cancelar'}</Button>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}