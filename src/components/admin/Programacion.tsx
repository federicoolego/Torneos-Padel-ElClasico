import { useMemo, useState } from 'react'
import { AlertTriangle } from 'lucide-react'
import { supabase, mensajeError } from '../../lib/supabase'
import type { Cancha, PartidoVista, Sede } from '../../lib/types'
import { aInputLocal, desdeInputLocal } from '../../lib/formato'
import { resumenSets } from '../../lib/resultado'
import { Alerta, Button, Card, Input, Select, Vacio } from '../ui'
import { etiquetaPartido, nombreLado } from '../Partidos'
import { Horario } from './ArmadoZonas'

const TZ = 'America/Argentina/Buenos_Aires'
const diaDe = (iso: string) => new Date(iso).toLocaleDateString('en-CA', { timeZone: TZ })   // YYYY-MM-DD
const horaDe = (iso: string) => new Date(iso).toLocaleTimeString('es-AR', { timeZone: TZ, hour: '2-digit', minute: '2-digit', hour12: false })
const diaLargo = (d: string) =>
  new Date(`${d}T12:00:00-03:00`).toLocaleDateString('es-AR', { timeZone: TZ, weekday: 'short', day: '2-digit', month: '2-digit' })
/** canchas activas de una sede, en orden */
export const canchasDe = (s: Sede | undefined): Cancha[] =>
  (s?.canchas ?? []).filter((c) => c.activa).sort((a, b) => a.orden - b.orden || a.nombre.localeCompare(b.nombre))
const jugadoresDe = (p: PartidoVista) =>
  [p.pareja_a_j1_id, p.pareja_a_j2_id, p.pareja_b_j1_id, p.pareja_b_j2_id].filter(Boolean) as string[]
const nombreJugador = (p: PartidoVista, id: string) =>
  ({ [p.pareja_a_j1_id ?? '']: p.pareja_a_j1, [p.pareja_a_j2_id ?? '']: p.pareja_a_j2,
     [p.pareja_b_j1_id ?? '']: p.pareja_b_j1, [p.pareja_b_j2_id ?? '']: p.pareja_b_j2 })[id] ?? 'Un jugador'
const duracion = (p: PartidoVista) => (p.games_set_unico !== null ? 40 : 75)

/** Choques de cancha y de jugadores para un partido con la sede/cancha/horario propuestos */
function choques(p: PartidoVista, cancha: string, fhIso: string | null, ocupados: PartidoVista[]): string[] {
  if (!fhIso) return []
  const t = new Date(fhIso).getTime()
  const mios = new Set(jugadoresDe(p))
  const out: string[] = []
  for (const o of ocupados) {
    if (o.id === p.id || !o.fecha_hora || o.estado === 'bye') continue
    const d = Math.abs(new Date(o.fecha_hora).getTime() - t) / 60000
    const quien = `${o.torneo_id === p.torneo_id ? '' : `${o.torneo} · `}${o.categoria} · ${etiquetaPartido(o)} (${horaDe(o.fecha_hora)})`
    if (cancha && o.cancha_id === cancha && d < Math.max(duracion(o), duracion(p))) {
      out.push(`Cancha ocupada: ${quien}`)
    }
    if (d < 90) {
      const comun = jugadoresDe(o).find((j) => mios.has(j))
      if (comun) out.push(`${nombreJugador(p, comun)} también juega ${quien}`)
    }
  }
  return out
}

export function FilaProgramacion({
  p, sedes, horarios, ocupados, onGuardado, onResultado,
}: {
  p: PartidoVista
  sedes: Sede[]
  horarios: Record<string, string>
  ocupados: PartidoVista[]
  onGuardado: () => void
  onResultado: () => void
}) {
  const [sede, setSede] = useState(p.sede_id ?? '')
  const [fh, setFh] = useState(aInputLocal(p.fecha_hora))
  const [cancha, setCancha] = useState(p.cancha_id ?? '')
  const [error, setError] = useState('')
  const [guardando, setGuardando] = useState(false)
  const cambiado = sede !== (p.sede_id ?? '') || fh !== aInputLocal(p.fecha_hora) || cancha !== (p.cancha_id ?? '')
  const s = sedes.find((x) => x.id === sede)
  const opcionesCancha = canchasDe(s)
  // si el partido tiene una cancha que después se desactivó, la seguimos mostrando
  if (cancha && !opcionesCancha.some((c) => c.id === cancha)) {
    const vieja = s?.canchas?.find((c) => c.id === cancha)
    if (vieja) opcionesCancha.push(vieja)
  }
  const avisos = choques(p, cancha, desdeInputLocal(fh), ocupados)

  async function guardar() {
    setGuardando(true)
    setError('')
    const { error } = await supabase.from('partidos')
      .update({ sede_id: sede || null, fecha_hora: desdeInputLocal(fh), cancha_id: cancha || null }).eq('id', p.id)
    setGuardando(false)
    if (error) return setError(mensajeError(error))
    onGuardado()
  }

  return (
    <div className={`grid gap-3 rounded-xl bg-white p-4 ring-1 lg:grid-cols-[1.4fr_2fr_auto] lg:items-start ${avisos.length ? 'ring-amber-400' : 'ring-noche/10'}`}>
      <div className="min-w-0">
        <p className="font-display text-lg font-semibold">{etiquetaPartido(p)}</p>
        {([['a', p.pareja_a, p.pareja_a_id], ['b', p.pareja_b, p.pareja_b_id]] as const).map(([lado, n, pid], k) => (
          <div key={k} className="mt-1 text-sm">
            <span className={n ? 'font-medium' : 'italic text-noche/45'}>{nombreLado(p, lado)}</span>
            {pid && <Horario texto={horarios[pid] ?? ''} compacto />}
          </div>
        ))}
        {p.estado !== 'pendiente' && <p className="mt-1 text-xs font-semibold text-emerald-800">{resumenSets(p)}</p>}
      </div>
      <div className="grid gap-2 sm:grid-cols-[1fr_1.2fr_6.5rem]">
        <Select value={sede} onChange={(e) => { setSede(e.target.value); setCancha('') }} aria-label="Sede">
          <option value="">Sede</option>
          {sedes.map((x) => <option key={x.id} value={x.id}>{x.nombre}</option>)}
        </Select>
        <Input type="datetime-local" value={fh} onChange={(e) => setFh(e.target.value)} aria-label="Fecha y hora" />
        <Select value={cancha} onChange={(e) => setCancha(e.target.value)} aria-label="Cancha" disabled={!sede}>
          <option value="">Cancha</option>
          {opcionesCancha.map((c) => <option key={c.id} value={c.id}>{c.nombre}{c.activa ? '' : ' (inactiva)'}</option>)}
        </Select>
        {avisos.length > 0 && (
          <ul className="space-y-0.5 text-xs text-amber-800 sm:col-span-3">
            {avisos.map((a) => <li key={a} className="flex gap-1"><AlertTriangle className="mt-0.5 h-3 w-3 shrink-0" aria-hidden />{a}</li>)}
          </ul>
        )}
        {error && <p className="text-xs text-red sm:col-span-3">{error}</p>}
      </div>
      <div className="flex gap-2 lg:justify-end">
        <Button variante="secundario" onClick={guardar} disabled={!cambiado} cargando={guardando}>Guardar</Button>
        {p.pareja_a_id && p.pareja_b_id && <Button variante="fantasma" onClick={onResultado}>{p.estado === 'pendiente' ? 'Resultado' : 'Editar'}</Button>}
      </div>
    </div>
  )
}

/** Grilla día × sede/cancha con todos los partidos programados (de todos los torneos del período) */
export function OcupacionCanchas({ ocupados, sedes, tcActual, dias }: { ocupados: PartidoVista[]; sedes: Sede[]; tcActual: string; dias: string[] }) {
  const conHora = ocupados.filter((p) => p.fecha_hora && p.estado !== 'bye')
  const todosDias = useMemo(
    () => [...new Set([...dias, ...conHora.map((p) => diaDe(p.fecha_hora!))])].sort(),
    [dias, conHora],
  )
  const [dia, setDia] = useState(todosDias.find((d) => conHora.some((p) => diaDe(p.fecha_hora!) === d)) ?? todosDias[0] ?? '')
  const delDia = conHora.filter((p) => diaDe(p.fecha_hora!) === dia)
  const columnas = sedes.flatMap((s) => canchasDe(s).map((c) => ({ sede: s, cancha: c })))
  const sinCancha = delDia.filter((p) => !p.sede_id || !p.cancha_id)
  const horas = [...new Set(delDia.map((p) => horaDe(p.fecha_hora!)))].sort()

  return (
    <Card>
      <p className="font-display text-xl font-semibold">Ocupación de canchas</p>
      <p className="mb-3 text-xs text-noche/60">Todos los partidos programados de los complejos en esos días, de cualquier torneo. En azul, los de esta categoría.</p>
      <div className="mb-3 flex gap-2 overflow-x-auto pb-1">
        {todosDias.map((d) => (
          <button key={d} onClick={() => setDia(d)}
            className={`shrink-0 rounded-full px-3 py-1 text-xs font-semibold ring-1 ${d === dia ? 'bg-noche text-white ring-noche' : 'bg-white text-noche ring-noche/15'}`}>
            {diaLargo(d)} <span className="num opacity-60">({conHora.filter((p) => diaDe(p.fecha_hora!) === d).length})</span>
          </button>
        ))}
      </div>
      {horas.length === 0 ? <p className="text-sm text-noche/55">No hay partidos programados ese día.</p> : (
        <div className="overflow-x-auto">
          <table className="w-full min-w-max border-separate border-spacing-1 text-xs">
            <thead>
              <tr>
                <th className="w-14" />
                {columnas.map((c) => (
                  <th key={c.cancha.id} className="min-w-[9rem] rounded-md bg-vidrio px-2 py-1.5 text-left font-semibold">
                    {c.sede.nombre}<span className="block font-normal text-noche/55">{c.cancha.nombre}</span>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {horas.map((h) => (
                <tr key={h}>
                  <td className="num pr-1 text-right align-top font-display text-sm font-semibold text-noche/60">{h}</td>
                  {columnas.map((c) => {
                    const aca = delDia.filter((p) => horaDe(p.fecha_hora!) === h && p.cancha_id === c.cancha.id)
                    return (
                      <td key={c.cancha.id} className="align-top">
                        {aca.map((p) => (
                          <div key={p.id} className={`mb-1 rounded-md px-2 py-1 ${aca.length > 1 ? 'bg-amber-100 ring-1 ring-amber-400' : p.torneo_categoria_id === tcActual ? 'bg-cancha text-white' : 'bg-noche/5'}`}>
                            <p className="font-semibold">{p.categoria} · {etiquetaPartido(p)}</p>
                            <p className="truncate opacity-75">{nombreLado(p, 'a')} vs {nombreLado(p, 'b')}</p>
                          </div>
                        ))}
                      </td>
                    )
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {sinCancha.length > 0 && (
        <p className="mt-2 text-xs text-amber-800">{sinCancha.length} partido(s) de ese día tienen horario pero no sede o cancha.</p>
      )}
    </Card>
  )
}

export default function Programacion({
  partidos, sedes, horarios, ocupados, tcId, dias, onGuardado, onResultado,
}: {
  partidos: PartidoVista[]
  sedes: Sede[]
  horarios: Record<string, string>
  ocupados: PartidoVista[]
  tcId: string
  dias: string[]
  onGuardado: () => void
  onResultado: (p: PartidoVista) => void
}) {
  const [soloSin, setSoloSin] = useState(false)
  const lista = partidos.filter((p) => p.estado !== 'bye')
  if (lista.length === 0) return <Vacio titulo="No hay partidos para programar">Primero armá las zonas.</Vacio>
  const sinProgramar = lista.filter((p) => !p.fecha_hora || !p.sede_id)
  const visibles = soloSin ? sinProgramar : lista
  return (
    <div className="space-y-4">
      <OcupacionCanchas ocupados={ocupados} sedes={sedes} tcActual={tcId} dias={dias} />
      <Alerta>
        Asigná sede, cancha, día y hora. Te avisamos si la cancha ya está ocupada o si algún jugador tiene otro partido cerca de ese horario.
        La cancha es orientativa: el día del torneo puede cambiar.
      </Alerta>
      <label className="flex items-center gap-2 text-sm">
        <input type="checkbox" checked={soloSin} onChange={(e) => setSoloSin(e.target.checked)} />
        Solo sin programar <span className="num text-noche/50">({sinProgramar.length})</span>
      </label>
      <div className="space-y-3">
        {visibles.map((p) => (
          <FilaProgramacion
            key={p.id + (p.fecha_hora ?? '') + (p.sede_id ?? '') + (p.cancha ?? '')}
            p={p} sedes={sedes} horarios={horarios} ocupados={ocupados}
            onGuardado={onGuardado} onResultado={() => onResultado(p)}
          />
        ))}
      </div>
    </div>
  )
}