import { useCallback, useEffect, useMemo, useState } from 'react'
import { ChevronLeft, ChevronRight, MapPin, Pencil } from 'lucide-react'
import { supabase, mensajeError } from '../lib/supabase'
import { useAuth } from '../context/AuthContext'
import type { PartidoVista } from '../lib/types'
import { resumenSets } from '../lib/resultado'
import {
  DIAS_CORTOS, diaCorto, diaDe, diaLargo, diaSemana, horaDe, hoy, inicioDia, lunesDe, nombreMes, primeroDeMes, sumarDias, sumarMeses,
} from '../lib/fechas'
import { Alerta, Select, Spinner, Titulo } from '../components/ui'
import { etiquetaPartido, nombreLado } from '../components/Partidos'
import ResultadoModal from '../components/ResultadoModal'

type Vista = 'dia' | 'semana' | 'mes'
type Estado = 'jugado' | 'falta' | 'proximo'

/** jugado: tiene resultado · falta: ya pasó la hora y no tiene resultado · proximo: todavía no se jugó */
function estadoDe(p: PartidoVista, ahora: number): Estado {
  if (p.estado === 'finalizado' || p.estado === 'wo') return 'jugado'
  return p.fecha_hora && new Date(p.fecha_hora).getTime() < ahora ? 'falta' : 'proximo'
}
const ESTILO: Record<Estado, string> = {
  jugado: 'bg-emerald-50 ring-emerald-200',
  falta: 'bg-amber-50 ring-amber-300',
  proximo: 'bg-white ring-noche/10',
}
const PUNTO: Record<Estado, string> = { jugado: 'bg-emerald-500', falta: 'bg-amber-500', proximo: 'bg-noche/30' }

function rango(vista: Vista, ref: string): [string, string] {
  if (vista === 'dia') return [ref, sumarDias(ref, 1)]
  if (vista === 'semana') { const l = lunesDe(ref); return [l, sumarDias(l, 7)] }
  const ini = lunesDe(primeroDeMes(ref))
  const fin = sumarDias(lunesDe(sumarDias(sumarMeses(ref, 1), -1)), 7)
  return [ini, fin]
}

export default function Calendario() {
  const { esAdmin } = useAuth()
  const [vista, setVista] = useState<Vista>(() => (window.innerWidth < 640 ? 'dia' : 'semana'))
  const [ref, setRef] = useState(hoy())
  const [partidos, setPartidos] = useState<PartidoVista[] | null>(null)
  const [error, setError] = useState('')
  const [torneo, setTorneo] = useState('')
  const [sede, setSede] = useState('')
  const [soloFalta, setSoloFalta] = useState(false)
  const [elegido, setElegido] = useState<PartidoVista | null>(null)
  const [desde, hasta] = rango(vista, ref)

  const cargar = useCallback(async () => {
    setError('')
    const { data, error } = await supabase.from('v_partidos').select('*')
      .gte('fecha_hora', inicioDia(desde)).lt('fecha_hora', inicioDia(hasta))
      .neq('estado', 'bye').order('fecha_hora')
    if (error) setError(mensajeError(error))
    setPartidos(((data as PartidoVista[]) ?? []).sort((a, b) => a.fecha_hora!.localeCompare(b.fecha_hora!) || a.categoria.localeCompare(b.categoria)))
  }, [desde, hasta])
  useEffect(() => { setPartidos(null); cargar() }, [cargar])

  const ahora = Date.now()
  const torneos = useMemo(() => [...new Map((partidos ?? []).map((p) => [p.torneo_id, p.torneo])).entries()], [partidos])
  const sedes = useMemo(() => [...new Set((partidos ?? []).map((p) => p.sede).filter(Boolean))] as string[], [partidos])
  const lista = (partidos ?? []).filter((p) =>
    (!torneo || p.torneo_id === torneo) && (!sede || p.sede === sede) && (!soloFalta || estadoDe(p, ahora) === 'falta'))
  const faltan = (partidos ?? []).filter((p) => (!torneo || p.torneo_id === torneo) && (!sede || p.sede === sede) && estadoDe(p, ahora) === 'falta').length

  const puedeCargar = (p: PartidoVista) =>
    !!p.pareja_a_id && !!p.pareja_b_id && (esAdmin || p.estado === 'pendiente')
  const abrir = (p: PartidoVista) => puedeCargar(p) && setElegido(p)

  const mover = (d: -1 | 1) =>
    setRef(vista === 'dia' ? sumarDias(ref, d) : vista === 'semana' ? sumarDias(ref, 7 * d) : sumarMeses(ref, d))
  const titulo = vista === 'dia' ? diaLargo(ref)
    : vista === 'semana' ? `Semana del ${diaCorto(desde)} al ${diaCorto(sumarDias(hasta, -1))}`
    : nombreMes(ref)

  return (
    <>
      <Titulo bajada="Todos los partidos programados. Tocá un partido para cargar o corregir el resultado.">Calendario de partidos</Titulo>

      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <button onClick={() => mover(-1)} aria-label="Anterior" className="rounded-lg bg-white p-2 ring-1 ring-noche/15 hover:bg-vidrio"><ChevronLeft className="h-4 w-4" /></button>
          <button onClick={() => setRef(hoy())} className="rounded-lg bg-white px-3 py-1.5 text-sm font-semibold ring-1 ring-noche/15 hover:bg-vidrio">Hoy</button>
          <button onClick={() => mover(1)} aria-label="Siguiente" className="rounded-lg bg-white p-2 ring-1 ring-noche/15 hover:bg-vidrio"><ChevronRight className="h-4 w-4" /></button>
          <h2 className="ml-1 font-display text-2xl font-bold first-letter:uppercase">{titulo}</h2>
        </div>
        <div className="inline-flex rounded-lg bg-white p-1 ring-1 ring-noche/10" role="group" aria-label="Vista">
          {(['dia', 'semana', 'mes'] as Vista[]).map((v) => (
            <button key={v} onClick={() => setVista(v)} aria-pressed={vista === v}
              className={`rounded-md px-3 py-1.5 text-sm font-semibold ${vista === v ? 'bg-noche text-white' : 'text-noche/60'}`}>
              {v === 'dia' ? 'Día' : v === 'semana' ? 'Semana' : 'Mes'}
            </button>
          ))}
        </div>
      </div>

      <div className="mb-4 flex flex-wrap items-center gap-2">
        <div className="w-full sm:w-56"><Select className="py-1.5 text-sm" value={torneo} onChange={(e) => setTorneo(e.target.value)} aria-label="Torneo">
          <option value="">Todos los torneos</option>
          {torneos.map(([id, n]) => <option key={id} value={id}>{n}</option>)}
        </Select></div>
        <div className="w-[calc(50%-0.25rem)] sm:w-44"><Select className="py-1.5 text-sm" value={sede} onChange={(e) => setSede(e.target.value)} aria-label="Sede">
          <option value="">Todas las sedes</option>
          {sedes.map((s) => <option key={s} value={s}>{s}</option>)}
        </Select></div>
        <button onClick={() => setSoloFalta(!soloFalta)} aria-pressed={soloFalta}
          className={`inline-flex items-center gap-2 rounded-lg px-3 py-1.5 text-sm font-semibold ring-1 ${soloFalta ? 'bg-amber-100 text-amber-900 ring-amber-300' : 'bg-white text-noche ring-noche/15'}`}>
          <span className="h-2 w-2 rounded-full bg-amber-500" /> Falta resultado <span className="num">({faltan})</span>
        </button>
        <span className="ml-auto hidden items-center gap-3 text-xs text-noche/55 sm:flex">
          <Leyenda e="proximo" t="Por jugar" /><Leyenda e="falta" t="Falta resultado" /><Leyenda e="jugado" t="Con resultado" />
        </span>
      </div>

      {error && <Alerta tipo="error">{error}</Alerta>}
      {!partidos ? <Spinner /> : vista === 'dia' ? (
        <VistaDia lista={lista} ahora={ahora} onAbrir={abrir} puedeCargar={puedeCargar} />
      ) : vista === 'semana' ? (
        <VistaSemana desde={desde} lista={lista} ahora={ahora} onAbrir={abrir} puedeCargar={puedeCargar} onDia={(d) => { setRef(d); setVista('dia') }} />
      ) : (
        <VistaMes desde={desde} hasta={hasta} mes={ref.slice(0, 7)} lista={lista} ahora={ahora} onDia={(d) => { setRef(d); setVista('dia') }} />
      )}

      {elegido && (
        <ResultadoModal partido={elegido} esAdmin={esAdmin} onCerrar={() => setElegido(null)} onGuardado={() => { setElegido(null); cargar() }} />
      )}
    </>
  )
}

function Leyenda({ e, t }: { e: Estado; t: string }) {
  return <span className="inline-flex items-center gap-1.5"><span className={`h-2 w-2 rounded-full ${PUNTO[e]}`} />{t}</span>
}

interface PropsLista { lista: PartidoVista[]; ahora: number; onAbrir: (p: PartidoVista) => void; puedeCargar: (p: PartidoVista) => boolean }

/** Tarjeta de partido; compacta para la vista semanal */
function Tarjeta({ p, ahora, onAbrir, puedeCargar, compacta = false }: { p: PartidoVista; compacta?: boolean } & Omit<PropsLista, 'lista'>) {
  const e = estadoDe(p, ahora)
  const editable = puedeCargar(p)
  const res = e === 'jugado' ? resumenSets(p) : null
  return (
    <button
      onClick={() => onAbrir(p)}
      disabled={!editable}
      className={`block w-full rounded-lg p-2.5 text-left ring-1 transition enabled:hover:ring-cancha disabled:cursor-default ${ESTILO[e]}`}
    >
      <div className="flex items-center justify-between gap-2 text-xs">
        <span className="num font-display text-sm font-bold">{horaDe(p.fecha_hora!)}</span>
        <span className="truncate font-semibold text-noche/70">{p.categoria}</span>
      </div>
      <p className={`mt-0.5 truncate font-medium ${compacta ? 'text-xs' : 'text-sm'}`}>{nombreLado(p, 'a')}</p>
      <p className={`truncate font-medium ${compacta ? 'text-xs' : 'text-sm'}`}>{nombreLado(p, 'b')}</p>
      {!compacta && (
        <p className="mt-1 flex items-center gap-1 truncate text-xs text-noche/55">
          <MapPin className="h-3 w-3 shrink-0" aria-hidden />{p.sede ?? 'Sin sede'}{p.cancha && ` · ${p.cancha}`} · {etiquetaPartido(p)}
        </p>
      )}
      {res ? (
        <p className="mt-1 text-xs font-semibold text-emerald-800">{res}</p>
      ) : editable && (
        <p className={`mt-1 inline-flex items-center gap-1 text-xs font-semibold ${e === 'falta' ? 'text-amber-800' : 'text-cancha'}`}>
          <Pencil className="h-3 w-3" aria-hidden /> Cargar resultado
        </p>
      )}
    </button>
  )
}

function VistaDia({ lista, ...r }: PropsLista) {
  if (!lista.length) return <p className="rounded-xl bg-white p-6 text-center text-sm text-noche/55 ring-1 ring-noche/10">No hay partidos este día.</p>
  const horas = [...new Set(lista.map((p) => horaDe(p.fecha_hora!)))]
  return (
    <div className="space-y-4">
      {horas.map((h) => (
        <section key={h} className="grid gap-2 sm:grid-cols-[4rem_1fr]">
          <p className="num font-display text-xl font-bold text-noche/60">{h}</p>
          <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
            {lista.filter((p) => horaDe(p.fecha_hora!) === h).map((p) => <Tarjeta key={p.id} p={p} {...r} />)}
          </div>
        </section>
      ))}
    </div>
  )
}

function VistaSemana({ desde, lista, onDia, ...r }: PropsLista & { desde: string; onDia: (d: string) => void }) {
  const dias = Array.from({ length: 7 }, (_, k) => sumarDias(desde, k))
  const hoyD = hoy()
  return (
    <div className="grid gap-3 lg:grid-cols-7 lg:gap-2">
      {dias.map((d) => {
        const del = lista.filter((p) => diaDe(p.fecha_hora!) === d)
        return (
          <section key={d} className={`min-w-0 rounded-xl p-2 ring-1 ${d === hoyD ? 'bg-cancha-suave ring-cancha/30' : 'bg-vidrio ring-noche/5'} ${del.length ? '' : 'hidden lg:block'}`}>
            <button onClick={() => onDia(d)} className="mb-2 flex w-full items-baseline justify-between px-1 text-left">
              <span className="font-display text-lg font-bold">{DIAS_CORTOS[diaSemana(d)]} {Number(d.slice(8, 10))}</span>
              <span className="num text-xs text-noche/50">{del.length || ''}</span>
            </button>
            <div className="space-y-1.5">
              {del.map((p) => <Tarjeta key={p.id} p={p} compacta {...r} />)}
            </div>
          </section>
        )
      })}
      {lista.length === 0 && <p className="rounded-xl bg-white p-6 text-center text-sm text-noche/55 ring-1 ring-noche/10 lg:hidden">No hay partidos esta semana.</p>}
    </div>
  )
}

function VistaMes({ desde, hasta, mes, lista, ahora, onDia }: { desde: string; hasta: string; mes: string; lista: PartidoVista[]; ahora: number; onDia: (d: string) => void }) {
  const dias: string[] = []
  for (let d = desde; d < hasta; d = sumarDias(d, 1)) dias.push(d)
  const hoyD = hoy()
  return (
    <div className="overflow-hidden rounded-xl bg-white ring-1 ring-noche/10">
      <div className="grid grid-cols-7 border-b border-noche/10 bg-vidrio text-center text-xs font-semibold text-noche/60">
        {DIAS_CORTOS.map((d) => <div key={d} className="py-2">{d}</div>)}
      </div>
      <div className="grid grid-cols-7">
        {dias.map((d) => {
          const del = lista.filter((p) => diaDe(p.fecha_hora!) === d)
          const n = { jugado: 0, falta: 0, proximo: 0 }
          del.forEach((p) => { n[estadoDe(p, ahora)]++ })
          const fuera = d.slice(0, 7) !== mes
          return (
            <button key={d} onClick={() => onDia(d)}
              className={`flex min-h-[4.5rem] flex-col items-start justify-start border-b border-r border-noche/5 p-1.5 text-left hover:bg-vidrio sm:min-h-[6.5rem] ${fuera ? 'bg-noche/[0.02] text-noche/35' : ''}`}>
              <span className={`num inline-flex h-6 min-w-[1.5rem] items-center justify-center rounded-full px-1 text-xs font-semibold ${d === hoyD ? 'bg-noche text-white' : ''}`}>
                {Number(d.slice(8, 10))}
              </span>
              {del.length > 0 && (
                <>
                  {/* celular: puntos con cantidad */}
                  <div className="mt-1 flex flex-wrap gap-1 sm:hidden">
                    {(Object.keys(n) as Estado[]).filter((e) => n[e]).map((e) => (
                      <span key={e} className="inline-flex items-center gap-0.5 text-[10px] font-semibold"><span className={`h-1.5 w-1.5 rounded-full ${PUNTO[e]}`} />{n[e]}</span>
                    ))}
                  </div>
                  {/* escritorio: primeros partidos + resto */}
                  <ul className="mt-1 hidden w-full space-y-0.5 sm:block">
                    {del.slice(0, 3).map((p) => (
                      <li key={p.id} className="flex items-center gap-1 truncate text-[11px]">
                        <span className={`h-1.5 w-1.5 shrink-0 rounded-full ${PUNTO[estadoDe(p, ahora)]}`} />
                        <span className="num font-semibold">{horaDe(p.fecha_hora!)}</span>
                        <span className="truncate text-noche/70">{p.categoria}</span>
                      </li>
                    ))}
                    {del.length > 3 && <li className="text-[11px] font-semibold text-cancha">+{del.length - 3} más</li>}
                  </ul>
                </>
              )}
            </button>
          )
        })}
      </div>
    </div>
  )
}