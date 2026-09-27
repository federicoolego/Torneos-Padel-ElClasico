import { useEffect, useMemo, useState } from 'react'
import { Save, Sparkles } from 'lucide-react'
import type { PartidoVista, Zona } from '../../lib/types'
import { FASE_LABEL } from '../../lib/formato'
import { Alerta, Button, Card, Select } from '../ui'

type ZonaCon = Zona & { zona_parejas: { inscripcion_id: string }[] }
interface Clasificado { key: string; zona: string; pos: number; label: string }
/** '' = sin elegir · 'libre' = el rival pasa directo · 'zona:pos' = clasificado */
type Lado = string

const FASE_POR_TAM: Record<number, keyof typeof FASE_LABEL> = { 2: 'final', 4: 'semifinal', 8: 'cuartos', 16: 'octavos', 32: 'dieciseisavos' }

/**
 * Armado del cuadro de playoff a mano, antes (o después) de jugar las zonas:
 * cada partido de primera ronda dice de dónde sale cada lado ("1° Zona A vs 2° Zona D").
 * Cuando una zona termina, sus clasificados se ubican solos.
 */
export default function ArmadoCuadro({
  zonas, playoff, trabajando, onGuardar,
}: {
  zonas: ZonaCon[]
  playoff: PartidoVista[]
  trabajando: boolean
  /** null = que lo arme automático */
  onGuardar: (cruces: ({ zona: string; pos: number } | null)[][] | null) => void
}) {
  const clasificados: Clasificado[] = useMemo(() => {
    const out: Clasificado[] = []
    const ord = [...zonas].sort((a, b) => a.nombre.localeCompare(b.nombre))
    for (const pos of [1, 2, 3]) {
      for (const z of ord) {
        const cupo = z.zona_parejas.length === 4 ? 3 : 2
        if (pos <= cupo) out.push({ key: `${z.id}:${pos}`, zona: z.id, pos, label: `${pos}° Zona ${z.nombre}` })
      }
    }
    return out
  }, [zonas])
  const q = clasificados.length
  let b = 2
  while (b < q) b *= 2
  const nPartidos = b / 2
  const fase = FASE_POR_TAM[b] ?? 'dieciseisavos'

  const primera = playoff.filter((p) => p.ronda === 1).sort((x, y) => x.orden - y.orden)
  const inicial = useMemo<Lado[][]>(() => {
    if (primera.length !== nPartidos || !primera.some((p) => p.origen_a_zona_id || p.origen_b_zona_id)) {
      return Array.from({ length: nPartidos }, () => ['', ''])
    }
    return primera.map((p) => [
      p.origen_a_zona_id ? `${p.origen_a_zona_id}:${p.origen_a_pos}` : 'libre',
      p.origen_b_zona_id ? `${p.origen_b_zona_id}:${p.origen_b_pos}` : 'libre',
    ])
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [JSON.stringify(primera.map((p) => [p.orden, p.origen_a_zona_id, p.origen_a_pos, p.origen_b_zona_id, p.origen_b_pos])), nPartidos])
  const [cruces, setCruces] = useState<Lado[][]>(inicial)
  useEffect(() => setCruces(inicial), [inicial])

  const usados = new Map<string, number>()
  cruces.flat().forEach((v) => { if (v && v !== 'libre') usados.set(v, (usados.get(v) ?? 0) + 1) })
  const libres = cruces.flat().filter((v) => v === 'libre').length
  const errores: string[] = []
  const faltan = clasificados.filter((c) => !usados.has(c.key))
  if (cruces.flat().some((v) => v === '')) errores.push('Completá todos los lados.')
  if (faltan.length) errores.push(`Falta ubicar: ${faltan.map((c) => c.label).join(', ')}.`)
  if ([...usados.values()].some((n) => n > 1)) errores.push('Hay clasificados repetidos.')
  if (libres !== b - q && !cruces.flat().some((v) => v === '')) errores.push(`Tiene que haber exactamente ${b - q} lado(s) libre(s).`)
  if (cruces.some(([a, c]) => a === 'libre' && c === 'libre')) errores.push('Un partido no puede tener los dos lados libres.')
  const cambiado = JSON.stringify(cruces) !== JSON.stringify(inicial)
  const hayCuadro = playoff.length > 0

  const set = (i: number, k: 0 | 1, v: Lado) => setCruces((cs) => cs.map((c, j) => (j === i ? (k === 0 ? [v, c[1]] : [c[0], v]) : c)))
  const aJson = () => cruces.map((c) => c.map((v) => (v === 'libre' ? null : { zona: v.split(':')[0], pos: Number(v.split(':')[1]) })))

  return (
    <Card>
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="max-w-2xl text-sm text-noche/75">
          <p className="font-display text-xl font-semibold text-noche">Armado del cuadro</p>
          Definí los cruces de {FASE_LABEL[fase].toLowerCase()} con las posiciones de zona (por ejemplo, 1° Zona A vs 2° Zona D) y programalos en
          la pestaña Programación. Cuando termina cada zona, sus clasificados se ubican solos.
          {b - q > 0 && ` Con ${q} clasificados, ${b - q} ${b - q === 1 ? 'pasa' : 'pasan'} directo a la ronda siguiente (lado “Libre”).`}
        </div>
        <Button variante="secundario" cargando={trabajando}
          onClick={() => (!hayCuadro || confirm('Se reemplaza el cuadro actual por el automático. ¿Continuar?')) && onGuardar(null)}>
          <Sparkles className="h-4 w-4" aria-hidden /> {hayCuadro ? 'Rearmar automático' : 'Armar automático'}
        </Button>
      </div>

      <ol className="mt-4 grid gap-2 md:grid-cols-2">
        {cruces.map((c, i) => (
          <li key={i} className="rounded-lg bg-vidrio p-3">
            <p className="mb-1.5 text-xs font-semibold text-noche/60">{FASE_LABEL[fase]}{fase !== 'final' ? ` ${i + 1}` : ''}</p>
            <div className="grid grid-cols-[1fr_auto_1fr] items-center gap-2">
              {([0, 1] as const).map((k) => (
                <div key={k} className={k === 1 ? 'col-start-3' : ''}>
                  <Select value={c[k]} onChange={(e) => set(i, k, e.target.value)} className="py-1.5 text-sm" aria-label={`Partido ${i + 1}, lado ${k + 1}`}>
                    <option value="">Elegir…</option>
                    {clasificados.map((x) => (
                      <option key={x.key} value={x.key} disabled={usados.has(x.key) && c[k] !== x.key}>{x.label}</option>
                    ))}
                    <option value="libre">Libre (pasa directo)</option>
                  </Select>
                </div>
              ))}
              <span className="col-start-2 row-start-1 text-xs font-semibold text-noche/45">vs</span>
            </div>
          </li>
        ))}
      </ol>

      <div className="mt-4 flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-noche/65">{errores[0] ?? `${q} clasificados · cuadro de ${b}`}</p>
        <Button onClick={() => (!hayCuadro || confirm('Se reemplaza el cuadro actual. Se conserva el horario de los partidos que no cambian de número. ¿Continuar?')) && onGuardar(aJson())}
          disabled={errores.length > 0 || !cambiado} cargando={trabajando}>
          <Save className="h-4 w-4" aria-hidden /> Guardar cruces
        </Button>
      </div>
      {errores.length > 1 && <div className="mt-2"><Alerta tipo="aviso">{errores.slice(1).join(' ')}</Alerta></div>}
    </Card>
  )
}