import { useState } from 'react'
import { MapPin, Clock, Pencil } from 'lucide-react'
import type { PartidoVista } from '../lib/types'
import { FASE_LABEL, fechaHora } from '../lib/formato'
import { formatoPartido, setsDe } from '../lib/resultado'
import { nombreCancha, toleranciaHasta } from '../lib/reglas'
import { Badge, Button } from './ui'
import ResultadoModal from './ResultadoModal'

export function etiquetaPartido(p: PartidoVista): string {
  if (p.fase === 'zona') {
    const extra = p.tipo_zona === 'ganadores' ? ' · Ganadores' : p.tipo_zona === 'perdedores' ? ' · Perdedores' : ''
    return `Zona ${p.zona}${extra}`
  }
  return p.fase === 'final' ? FASE_LABEL[p.fase] : `${FASE_LABEL[p.fase]} ${p.orden}`
}

/** Nombre de la pareja, o de dónde sale ("1° Zona A", "Ganador Cuartos 2") mientras no se sabe */
export function nombreLado(p: PartidoVista, lado: 'a' | 'b'): string {
  return nombreSlot(p, lado)
}

function nombreSlot(p: PartidoVista, lado: 'a' | 'b'): string {
  const n = lado === 'a' ? p.pareja_a : p.pareja_b
  if (n) return n
  const o = lado === 'a' ? p.origen_a : p.origen_b
  if (o) return o
  if (p.estado === 'bye') return 'Libre'
  if (p.tipo_zona === 'ganadores') return lado === 'a' ? 'Ganador partido 1' : 'Ganador partido 2'
  if (p.tipo_zona === 'perdedores') return lado === 'a' ? 'Perdedor partido 1' : 'Perdedor partido 2'
  return 'A definir'
}

/** Marcador tipo tablero: una fila por pareja, una columna por set */
export function Marcador({ p, resaltarIds = [] }: { p: PartidoVista; resaltarIds?: string[] }) {
  const sets = setsDe(p).filter(([a, b]) => a !== null && b !== null)
  const filas: { lado: 'a' | 'b'; id: string | null; j1: string | null; j2: string | null }[] = [
    { lado: 'a', id: p.pareja_a_id, j1: p.pareja_a_j1, j2: p.pareja_a_j2 },
    { lado: 'b', id: p.pareja_b_id, j1: p.pareja_b_j1, j2: p.pareja_b_j2 },
  ]
  return (
    <div className="divide-y divide-noche/10 overflow-hidden rounded-lg ring-1 ring-noche/10">
      {filas.map((f) => {
        const gano = !!p.ganador_id && p.ganador_id === f.id
        const mio = !!f.id && resaltarIds.includes(f.id)
        return (
          <div key={f.lado} className={`flex items-stretch ${gano ? 'bg-pelota/35' : 'bg-white'}`}>
            <div className="flex min-w-0 flex-1 items-center gap-2 px-3 py-2">
              <span className={`h-2 w-2 shrink-0 rounded-full ${gano ? 'bg-noche' : 'bg-transparent'}`} aria-hidden />
              <div className="min-w-0">
                <p className={`truncate text-sm ${gano ? 'font-semibold' : 'font-medium'} ${f.id ? 'text-noche' : 'italic text-noche/45'}`}>
                  {nombreSlot(p, f.lado)}
                  {mio && <span className="ml-2 align-middle"><Badge tono="azul">Vos</Badge></span>}
                </p>
                {f.j1 && <p className="truncate text-xs text-noche/55">{f.j1} y {f.j2}</p>}
              </div>
            </div>
            {p.estado === 'wo' && (
              <div className="flex w-14 items-center justify-center font-display text-lg font-semibold">{gano ? 'W.O.' : ''}</div>
            )}
            {sets.map(([a, b], i) => {
              const v = f.lado === 'a' ? a : b
              const o = f.lado === 'a' ? b : a
              const ganoSet = (v ?? 0) > (o ?? 0)
              return (
                <div
                  key={i}
                  className={`num flex w-10 items-center justify-center border-l border-noche/10 font-display text-xl ${ganoSet ? 'font-bold text-noche' : 'text-noche/45'}`}
                >
                  {v}
                </div>
              )
            })}
          </div>
        )
      })}
    </div>
  )
}

export function PartidoFila({
  p,
  puedeCargar,
  esAdmin,
  onCambio,
  resaltarIds,
  mostrarCategoria,
}: {
  p: PartidoVista
  puedeCargar: boolean
  esAdmin: boolean
  onCambio: () => void
  resaltarIds?: string[]
  mostrarCategoria?: boolean
}) {
  const [abierto, setAbierto] = useState(false)
  const listo = !!p.pareja_a_id && !!p.pareja_b_id
  const editable = listo && p.estado !== 'bye' && (esAdmin || (puedeCargar && p.estado === 'pendiente'))

  return (
    <article className="rounded-xl bg-white p-4 ring-1 ring-noche/10">
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2 text-xs text-noche/65">
        <div className="flex flex-wrap items-center gap-x-4 gap-y-1">
          <span className="font-display text-base font-semibold text-noche">
            {mostrarCategoria && `${p.torneo} · ${p.categoria} · `}{etiquetaPartido(p)}
          </span>
          <span className="inline-flex items-center gap-1"><Clock className="h-3.5 w-3.5" aria-hidden />{fechaHora(p.fecha_hora)}</span>
          {p.estado === 'pendiente' && p.fecha_hora && (
            <span className="font-semibold text-noche">Presentarse hasta las {toleranciaHasta(p.fecha_hora)}</span>
          )}
          <span className="inline-flex items-center gap-1">
            <MapPin className="h-3.5 w-3.5" aria-hidden />
            {p.sede ?? 'Sede a confirmar'}
            {p.cancha && <>{` · ${nombreCancha(p.cancha)}`}{p.estado === 'pendiente' && <span className="text-noche/45"> (orientativa)</span>}</>}
          </span>
        </div>
        {p.estado === 'pendiente' && <Badge>{formatoPartido(p)}</Badge>}
      </div>
      <Marcador p={p} resaltarIds={resaltarIds} />
      {editable && (
        <div className="mt-3 flex justify-end">
          <Button variante="fantasma" onClick={() => setAbierto(true)}>
            <Pencil className="h-4 w-4" aria-hidden />
            {p.estado === 'pendiente' ? 'Cargar resultado' : 'Editar resultado'}
          </Button>
        </div>
      )}
      {abierto && (
        <ResultadoModal
          partido={p}
          esAdmin={esAdmin}
          onCerrar={() => setAbierto(false)}
          onGuardado={() => {
            setAbierto(false)
            onCambio()
          }}
        />
      )}
    </article>
  )
}