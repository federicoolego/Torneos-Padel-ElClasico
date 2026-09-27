import type { PartidoVista } from '../lib/types'
import { FASE_LABEL, fechaHora } from '../lib/formato'
import { setsDe } from '../lib/resultado'

function Caja({ p, onClick, resaltarIds }: { p: PartidoVista; onClick?: () => void; resaltarIds: string[] }) {
  const sets = setsDe(p).filter(([a, b]) => a !== null && b !== null)
  const lados = [
    { id: p.pareja_a_id, n: p.pareja_a, o: p.origen_a },
    { id: p.pareja_b_id, n: p.pareja_b, o: p.origen_b },
  ]
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={!onClick}
      className="w-60 overflow-hidden rounded-lg bg-white text-left ring-1 ring-noche/10 enabled:hover:ring-cancha"
    >
      {lados.map((l, i) => {
        const gano = !!p.ganador_id && p.ganador_id === l.id
        return (
          <div key={i} className={`flex items-center border-noche/10 ${i === 0 ? 'border-b' : ''} ${gano ? 'bg-pelota/35' : ''} ${l.id && resaltarIds.includes(l.id) ? 'outline outline-2 -outline-offset-2 outline-cancha' : ''}`}>
            <span className={`min-w-0 flex-1 truncate px-2.5 py-1.5 text-sm ${gano ? 'font-semibold' : ''} ${l.n ? '' : 'italic text-noche/40'}`}>
              {l.n ?? l.o ?? (p.estado === 'bye' ? 'Libre' : 'A definir')}
            </span>
            {p.estado === 'wo' && gano && <span className="px-2 font-display text-sm font-semibold">W.O.</span>}
            {sets.map(([a, b], k) => {
              const v = i === 0 ? a : b
              const o = i === 0 ? b : a
              return (
                <span key={k} className={`num w-7 text-center font-display text-base ${(v ?? 0) > (o ?? 0) ? 'font-bold' : 'text-noche/45'}`}>{v}</span>
              )
            })}
          </div>
        )
      })}
      {p.estado === 'pendiente' && (
        <div className="bg-vidrio px-2.5 py-1 text-[11px] text-noche/60">{fechaHora(p.fecha_hora)}{p.sede ? ` · ${p.sede}` : ''}</div>
      )}
    </button>
  )
}

export default function Bracket({
  partidos,
  onElegir,
  resaltarIds = [],
}: {
  partidos: PartidoVista[]
  onElegir?: (p: PartidoVista) => void
  resaltarIds?: string[]
}) {
  const rondas = [...new Set(partidos.map((p) => p.ronda))].sort((a, b) => a - b)
  const ALTO = 92 // alto de una caja + separación, en px
  const primera = partidos.filter((p) => p.ronda === rondas[0]).length

  return (
    <div className="overflow-x-auto pb-4">
      <div className="flex gap-10" style={{ minHeight: primera * ALTO }}>
        {rondas.map((r, idx) => {
          const ps = partidos.filter((p) => p.ronda === r).sort((a, b) => a.orden - b.orden)
          return (
            <div key={r} className="flex shrink-0 flex-col">
              <h3 className="mb-3 font-display text-lg font-semibold text-noche">{FASE_LABEL[ps[0].fase]}</h3>
              <div className="flex flex-1 flex-col justify-around" style={{ gap: `${(2 ** idx - 1) * ALTO / 2}px` }}>
                {ps.map((p) => (
                  <Caja key={p.id} p={p} resaltarIds={resaltarIds} onClick={onElegir && p.pareja_a_id && p.pareja_b_id && p.estado !== 'bye' ? () => onElegir(p) : undefined} />
                ))}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}