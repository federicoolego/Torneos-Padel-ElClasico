import { Link } from 'react-router-dom'
import { AlertTriangle, ArrowRight, BookOpen } from 'lucide-react'
import { useAuth } from '../context/AuthContext'
import { AYUDA_ADMIN, AYUDA_EDITOR, AYUDA_JUGADOR, type Ayuda as AyudaContenido } from '../lib/ayuda'
import { Card, Titulo } from '../components/ui'

const CONTENIDO: Record<'jugador' | 'editor' | 'admin', AyudaContenido> = {
  jugador: AYUDA_JUGADOR,
  editor: AYUDA_EDITOR,
  admin: AYUDA_ADMIN,
}

/** Instructivo por rol: /ayuda (todos), /ayuda/editor (editor) y /ayuda/admin (administración). */
export default function Ayuda({ para }: { para: 'jugador' | 'editor' | 'admin' }) {
  const { esAdmin, esEditor } = useAuth()
  const a = CONTENIDO[para]

  return (
    <>
      <Titulo bajada={a.bajada}>{a.titulo}</Titulo>

      {para === 'jugador' && esEditor && (
        <Card className="mb-6">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <p className="text-sm">
              <BookOpen className="mr-1.5 inline h-4 w-4 text-cancha" aria-hidden />
              Como {esAdmin ? 'administrador' : 'editor'} tenés además una ayuda de {esAdmin ? 'administración' : 'carga de resultados'}.
            </p>
            <Link to={esAdmin ? '/ayuda/admin' : '/ayuda/editor'} className="inline-flex items-center gap-1 text-sm font-semibold text-cancha hover:underline">
              Ver ayuda de {esAdmin ? 'administración' : 'resultados'} <ArrowRight className="h-4 w-4" aria-hidden />
            </Link>
          </div>
        </Card>
      )}

      {a.secciones.length > 2 && (
        <nav aria-label="Secciones de la ayuda" className="mb-6 flex flex-wrap gap-2">
          {a.secciones.map((s) => (
            <a key={s.id} href={`#${s.id}`} className="rounded-full bg-white px-3 py-1 text-sm font-medium text-noche/75 ring-1 ring-noche/10 hover:text-cancha">
              {s.titulo}
            </a>
          ))}
        </nav>
      )}

      <div className="space-y-4">
        {a.secciones.map((s) => (
          <section key={s.id} id={s.id} className="scroll-mt-6">
            <Card>
              <div className="flex flex-wrap items-start justify-between gap-2">
                <h2 className="font-display text-2xl font-bold">{s.titulo}</h2>
                {s.ruta && (
                  <Link to={s.ruta} className="inline-flex items-center gap-1 text-sm font-semibold text-cancha hover:underline">
                    Ir a la sección <ArrowRight className="h-4 w-4" aria-hidden />
                  </Link>
                )}
              </div>
              <p className="mt-1 text-sm text-noche/70">{s.resumen}</p>
              <ul className="mt-3 list-disc space-y-1.5 pl-5 text-sm">
                {s.pasos.map((p) => <li key={p}>{p}</li>)}
              </ul>
              {s.ojo && (
                <div className="mt-4 rounded-lg bg-amber-50 p-3 text-sm text-amber-900">
                  <p className="mb-1 flex items-center gap-1.5 font-semibold">
                    <AlertTriangle className="h-4 w-4" aria-hidden /> Tené en cuenta
                  </p>
                  <ul className="list-disc space-y-1 pl-5">
                    {s.ojo.map((o) => <li key={o}>{o}</li>)}
                  </ul>
                </div>
              )}
            </Card>
          </section>
        ))}
      </div>
    </>
  )
}