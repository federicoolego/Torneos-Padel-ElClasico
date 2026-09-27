export type Rol = 'jugador' | 'editor' | 'administrador'
export type Genero = 'caballeros' | 'damas' | 'mixto'
export type EstadoTorneo = 'borrador' | 'publicado' | 'en_curso' | 'finalizado' | 'cancelado'
export type EstadoCategoria = 'inscripcion' | 'zonas' | 'playoff' | 'finalizada' | 'suspendida'
export type EstadoInscripcion = 'activa' | 'cancelada'
export type Fase = 'zona' | 'dieciseisavos' | 'octavos' | 'cuartos' | 'semifinal' | 'final'
export type EstadoPartido = 'pendiente' | 'finalizado' | 'wo' | 'bye'

export type TipoCategoria = 'nivel' | 'suma'

export interface Categoria {
  id: number
  nombre: string
  genero: Genero
  /** 'nivel' = 3ra..7ma (categoría propia del jugador); 'suma' = Suma 8..14 */
  tipo: TipoCategoria
  nivel: number | null
  suma: number | null
  activa: boolean
  orden: number
}

export interface Jugador {
  id: string
  dni: string
  nombre: string
  apellido: string
  telefono: string
  email: string | null
  categoria_id: number
  rol: Rol
  activo: boolean
  debe_cambiar_password: boolean
  created_at: string
}

export interface Sede {
  id: string
  nombre: string
  direccion: string | null
  activa: boolean
  /** viene cuando se pide con select('*, canchas(*)') */
  canchas?: Cancha[]
}

export interface Cancha {
  id: string
  sede_id: string
  nombre: string
  orden: number
  activa: boolean
}

export interface ParejaVista {
  id: string
  activa: boolean
  created_at: string
  jugador1_id: string
  jugador1: string
  categoria1: string
  categoria1_id: number
  jugador2_id: string
  jugador2: string
  categoria2: string
  categoria2_id: number
  nombre_corto: string
}

export interface Torneo {
  id: string
  nombre: string
  descripcion: string | null
  fecha_desde: string
  fecha_hasta: string
  cierre_inscripcion: string
  observaciones: string | null
  precio_inscripcion: number | null
  estado: EstadoTorneo
  /** Americano: se juega en el día a un solo set de games_set_unico games */
  americano: boolean
  games_set_unico: number | null
}

export interface TorneoCategoriaVista {
  id: string
  torneo_id: string
  categoria_id: number
  categoria: string
  genero: Genero
  orden: number
  cupo_max: number
  cupo_min: number
  estado: EstadoCategoria
  /** null para jugadores: solo editor/admin ven el total */
  inscriptas: number | null
  cupo_completo: boolean
  tipo: TipoCategoria
  suma: number | null
}

export interface InscripcionVista {
  id: string
  torneo_categoria_id: string
  torneo_id: string
  categoria_id: number
  categoria: string
  pareja_id: string
  nombre_corto: string
  jugador1: string
  jugador2: string
  jugador1_id: string
  jugador2_id: string
  estado: EstadoInscripcion
  created_at: string
}

export interface MiInscripcion {
  id: string
  torneo_id: string
  torneo: string
  fecha_desde: string
  fecha_hasta: string
  cierre_inscripcion: string
  estado_torneo: EstadoTorneo
  torneo_categoria_id: string
  categoria: string
  estado_categoria: EstadoCategoria
  pareja_id: string
  pareja: string
  companero: string
  problemas_horario: string
  estado: EstadoInscripcion
  pagada: boolean
  created_at: string
  puede_editar: boolean
}

export interface Zona {
  id: string
  torneo_categoria_id: string
  nombre: string
}

export interface Posicion {
  inscripcion_id: string
  pj: number
  pg: number
  pp: number
  sets_favor: number
  sets_contra: number
  games_favor: number
  games_contra: number
  posicion: number
}

export interface PartidoVista {
  id: string
  torneo_categoria_id: string
  fase: Fase
  zona_id: string | null
  ronda: number
  orden: number
  tipo_zona: 'ganadores' | 'perdedores' | null
  pareja_a_id: string | null
  pareja_b_id: string | null
  sede_id: string | null
  cancha_id: string | null
  fecha_hora: string | null
  super_tiebreak: boolean
  s1_a: number | null
  s1_b: number | null
  s2_a: number | null
  s2_b: number | null
  s3_a: number | null
  s3_b: number | null
  ganador_id: string | null
  estado: EstadoPartido
  siguiente_partido_id: string | null
  siguiente_slot: 'A' | 'B' | null
  torneo_id: string
  torneo: string
  categoria_id: number
  categoria: string
  zona: string | null
  sede: string | null
  /** nombre de la cancha (Blindex, Cancha 1…) */
  cancha: string | null
  pareja_a: string | null
  pareja_a_j1: string | null
  pareja_a_j2: string | null
  pareja_b: string | null
  pareja_b_j1: string | null
  pareja_b_j2: string | null
  pareja_a_j1_id: string | null
  pareja_a_j2_id: string | null
  pareja_b_j1_id: string | null
  pareja_b_j2_id: string | null
  /** null = formato estándar (al mejor de 3); número = set único a N games */
  games_set_unico: number | null
  /** primera ronda de playoff: de qué zona y posición sale cada lado */
  origen_a_zona_id: string | null
  origen_a_pos: number | null
  origen_b_zona_id: string | null
  origen_b_pos: number | null
  /** texto para mostrar mientras no se sabe la pareja: "1° Zona A", "Ganador Cuartos 2" */
  origen_a: string | null
  origen_b: string | null
}

export interface InscriptoAdmin {
  id: string
  pareja_id: string
  pareja: string
  jugador1: string
  dni1: string
  telefono1: string
  categoria1: string
  jugador2: string
  dni2: string
  telefono2: string
  categoria2: string
  problemas_horario: string
  estado: EstadoInscripcion
  pagada: boolean
  created_at: string
  zona: string | null
}