/** Firma del desarrollador, al pie de todas las pantallas. Para cambiar el texto, editá FIRMA. */
export const FIRMA = '🎾 Desarrollado por Federico Olego 🎾'

export default function Firma({ oscuro = false, className = '' }: { oscuro?: boolean; className?: string }) {
  return (
    <footer className={`select-none py-4 text-center text-xs font-medium tracking-wide ${oscuro ? 'text-white/50' : 'text-noche/40'} ${className}`}>
      {FIRMA}
    </footer>
  )
}