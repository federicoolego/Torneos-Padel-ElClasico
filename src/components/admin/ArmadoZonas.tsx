import { useEffect, useMemo, useState } from 'react'
import { ArrowDown, ArrowUp, Plus, Save, Sparkles, Trash2 } from 'lucide-react'
import type { InscriptoAdmin } from '../../lib/types'
import { Alerta, Button, Card, Select } from '../ui'

const LETRAS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

/** true si el texto de "problemas de horario" indica alguna restricción real */
export function tieneRestriccion(t: string | null | undefined): boolean {
  if (!t) return false
  return !/^\s*(ning|no\s+ten|sin\s+(problema|restric)|-+\s*$|\.\s*$)/i.test(t)
}

export function Horario({ texto, compacto = false }: { texto: string; compacto?: boolean }) {
  const r = tieneRestriccion(texto)
  return (
    <p className={`whitespace-pre-line ${compacto ? 'text-[11px]' : 'text-xs'} ${r ? 'font-medium text-amber-800' : 'text-noche/45'}`}>
      {r ? `Horario: ${texto}` : 'Sin problemas de horario'}
    </p>
  )
}

/**
 * Armado manual de zonas: el admin reparte las parejas mirando sus problemas de horario.
 * El orden dentro de cada zona es la posición (en zonas de 4 cruzan 1 vs 4 y 2 vs 3).
 */
export default function ArmadoZonas({
  activos,
  inicial,
  cupoMin,
  cierreVencido,
  trabajando,
  onGuardar,
}: {
  activos: InscriptoAdmin[]
  /** zonas actuales: ids de inscripción en orden de posición */
  inicial: string[][]
  cupoMin: number
  cierreVencido: boolean
  trabajando: boolean
  onGuardar: (zonas: string[][]) => void
}) {
  const [zonas, setZonas] = useState<string[][]>(inicial)
  const clave = JSON.stringify(inicial)
  useEffect(() => setZonas(JSON.parse(clave)), [clave])

  const porId = useMemo(() => Object.fromEntries(activos.map((i) => [i.id, i])), [activos])
  const ubicadas = new Set(zonas.flat())
  const sinZona = activos.filter((i) => !ubicadas.has(i.id))
  const n = activos.length
  const cambiado = JSON.stringify(zonas) !== clave

  const errores: string[] = []
  if (n < cupoMin) errores.push(`Hay ${n} parejas; se necesitan al menos ${cupoMin}.`)
  if (sinZona.length) errores.push(`Faltan ubicar ${sinZona.length} pareja(s).`)
  zonas.forEach((z, k) => {
    if (z.length < 3 || z.length > 4) errores.push(`La zona ${LETRAS[k]} tiene ${z.length}: tienen que ser de 3 o 4.`)
  })
  if (!zonas.length) errores.push('Agregá al menos una zona.')
  const clasifican = zonas.reduce((t, z) => t + (z.length === 4 ? 3 : z.length === 3 ? 2 : 0), 0)

  const quitar = (id: string, zs: string[][]) => zs.map((z) => z.filter((x) => x !== id))
  const asignar = (id: string, destino: number) =>
    setZonas((zs) => {
      const sin = quitar(id, zs)
      if (destino >= 0) sin[destino] = [...sin[destino], id]
      return sin
    })
  const mover = (zi: number, pi: number, d: -1 | 1) =>
    setZonas((zs) => {
      const c = zs.map((z) => [...z])
      const j = pi + d
      if (j < 0 || j >= c[zi].length) return zs
      ;[c[zi][pi], c[zi][j]] = [c[zi][j], c[zi][pi]]
      return c
    })
  const quitarZona = (zi: number) => setZonas((zs) => zs.filter((_, k) => k !== zi))

  function sugerir() {
    if (zonas.flat().length && !confirm('Se reemplaza el reparto actual por uno sugerido. ¿Continuar?')) return
    const cant = Math.floor(n / 3)
    if (cant < 1) return
    const de4 = n - 3 * cant
    const ids = activos.map((i) => i.id)
    const out: string[][] = []
    let k = 0
    for (let z = 0; z < cant; z++) {
      const tam = z < de4 ? 4 : 3
      out.push(ids.slice(k, k + tam))
      k += tam
    }
    setZonas(out)
  }

  const opcionesZona = (actual: number) => (
    <>
      <option value={-1}>{actual >= 0 ? 'Sacar de la zona' : 'Sin zona'}</option>
      {zonas.map((z, k) => (
        <option key={k} value={k} disabled={k === actual}>
          Zona {LETRAS[k]} ({z.length})
        </option>
      ))}
    </>
  )

  return (
    <div className="space-y-4">
      <Card className="flex flex-wrap items-center justify-between gap-3">
        <div className="max-w-2xl text-sm text-noche/75">
          <p className="font-display text-xl font-semibold text-noche">Armado de zonas</p>
          Repartí las parejas teniendo en cuenta sus problemas de horario. Zonas de 3 (clasifican 2) o de 4 (clasifican 3).
          El orden dentro de la zona es la posición: en zonas de 4 juegan 1 vs 4 y 2 vs 3.
          {!cierreVencido && <span className="mt-1 block text-amber-800">La inscripción sigue abierta: al guardar las zonas, las parejas ya no pueden cancelar.</span>}
        </div>
        <div className="flex flex-wrap gap-2">
          <Button variante="secundario" onClick={sugerir} disabled={n < 3}><Sparkles className="h-4 w-4" aria-hidden /> Sugerir reparto</Button>
          <Button variante="secundario" onClick={() => setZonas((zs) => [...zs, []])} disabled={zonas.length >= 26}><Plus className="h-4 w-4" aria-hidden /> Agregar zona</Button>
        </div>
      </Card>

      <div className="grid gap-5 lg:grid-cols-[minmax(16rem,1fr)_2fr]">
        <section aria-label="Parejas sin zona">
          <h3 className="mb-2 font-display text-lg font-semibold">Sin zona <span className="num text-noche/50">({sinZona.length})</span></h3>
          {sinZona.length === 0 ? (
            <p className="rounded-xl bg-white p-4 text-sm text-noche/55 ring-1 ring-noche/10">Todas las parejas están ubicadas.</p>
          ) : (
            <ul className="space-y-2">
              {sinZona.map((i) => (
                <li key={i.id} className="rounded-xl bg-white p-3 ring-1 ring-noche/10">
                  <p className="text-sm font-semibold">{i.pareja}</p>
                  <Horario texto={i.problemas_horario} />
                  <Select className="mt-2 py-1.5 text-sm" value={-1} onChange={(e) => asignar(i.id, Number(e.target.value))} aria-label={`Zona para ${i.pareja}`} disabled={!zonas.length}>
                    {opcionesZona(-1)}
                  </Select>
                </li>
              ))}
            </ul>
          )}
        </section>

        <section aria-label="Zonas" className="grid content-start gap-4 sm:grid-cols-2">
          {zonas.length === 0 && (
            <p className="rounded-xl bg-white p-4 text-sm text-noche/55 ring-1 ring-noche/10 sm:col-span-2">
              Agregá zonas o usá “Sugerir reparto” como punto de partida.
            </p>
          )}
          {zonas.map((z, zi) => {
            const ok = z.length === 3 || z.length === 4
            return (
              <div key={zi} className={`overflow-hidden rounded-xl bg-white ring-1 ${ok ? 'ring-noche/10' : 'ring-amber-400'}`}>
                <header className="flex items-center justify-between bg-noche px-3 py-2 text-white">
                  <p className="font-display text-lg font-bold">Zona {LETRAS[zi]} <span className="text-sm font-medium text-white/60">· {z.length} parejas</span></p>
                  <button onClick={() => quitarZona(zi)} aria-label={`Quitar zona ${LETRAS[zi]}`} className="text-white/60 hover:text-white"><Trash2 className="h-4 w-4" /></button>
                </header>
                <ol className="divide-y divide-noche/5">
                  {z.map((id, pi) => {
                    const i = porId[id]
                    if (!i) return null
                    return (
                      <li key={id} className="flex gap-2 p-3">
                        <span className="num mt-0.5 w-5 shrink-0 font-display text-lg font-bold text-noche/40">{pi + 1}</span>
                        <div className="min-w-0 flex-1">
                          <p className="text-sm font-semibold">{i.pareja}</p>
                          <Horario texto={i.problemas_horario} compacto />
                          <Select className="mt-1.5 py-1 text-xs" value={zi} onChange={(e) => asignar(id, Number(e.target.value))} aria-label={`Mover ${i.pareja}`}>
                            {opcionesZona(zi)}
                          </Select>
                        </div>
                        <div className="flex flex-col">
                          <button onClick={() => mover(zi, pi, -1)} disabled={pi === 0} aria-label="Subir" className="p-1 text-noche/50 disabled:opacity-20"><ArrowUp className="h-4 w-4" /></button>
                          <button onClick={() => mover(zi, pi, 1)} disabled={pi === z.length - 1} aria-label="Bajar" className="p-1 text-noche/50 disabled:opacity-20"><ArrowDown className="h-4 w-4" /></button>
                        </div>
                      </li>
                    )
                  })}
                </ol>
                {z.length === 4 && <p className="border-t border-noche/5 px-3 py-1.5 text-[11px] text-noche/55">Cruces: 1 vs 4 y 2 vs 3, después ganadores y perdedores</p>}
              </div>
            )
          })}
        </section>
      </div>

      <div className="sticky bottom-20 z-10 flex flex-wrap items-center justify-between gap-3 rounded-xl bg-white p-3 shadow-lg ring-1 ring-noche/10 lg:bottom-4">
        <p className="text-sm text-noche/70">
          {errores.length ? errores[0] : `${zonas.length} zonas · clasifican ${clasifican} al playoff`}
        </p>
        <Button
          onClick={() => (!inicial.length || confirm('Se reemplazan las zonas actuales. Se conserva sede y horario de los partidos de zona que no cambian de parejas; si había un cuadro de playoff armado, hay que volver a armarlo. ¿Continuar?')) && onGuardar(zonas)}
          disabled={errores.length > 0 || !cambiado}
          cargando={trabajando}
        >
          <Save className="h-4 w-4" aria-hidden /> Guardar zonas
        </Button>
      </div>
      {errores.length > 1 && <Alerta tipo="aviso">{errores.slice(1).join(' ')}</Alerta>}
    </div>
  )
}