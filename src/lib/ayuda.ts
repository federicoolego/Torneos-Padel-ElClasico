/**
 * Contenido de las pantallas de Ayuda. Para cambiar un texto, editá acá:
 * cada sección es una tarjeta con lo que se puede hacer y lo que conviene saber.
 */
export interface SeccionAyuda {
  id: string
  titulo: string
  /** Ruta de la sección en la app (muestra el botón "Ir a …") */
  ruta?: string
  resumen: string
  pasos: string[]
  /** Reglas o advertencias importantes */
  ojo?: string[]
}

export interface Ayuda {
  titulo: string
  bajada: string
  secciones: SeccionAyuda[]
}

export const AYUDA_JUGADOR: Ayuda = {
  titulo: 'Ayuda',
  bajada: 'Qué podés hacer en cada sección de la app y cómo inscribirte a un torneo paso a paso.',
  secciones: [
    {
      id: 'primeros-pasos',
      titulo: 'Primeros pasos: cómo inscribirte',
      resumen: 'Para jugar un torneo necesitás una pareja y anotarla en una categoría antes del cierre de inscripción.',
      pasos: [
        'En Mis Parejas, armá tu pareja con el DNI de tu compañero (tiene que estar registrado en la app).',
        'En Torneos, entrá al torneo que te interese y elegí la categoría.',
        'Elegí la pareja, contá si tienen problemas de horario (por ejemplo "no podemos antes de las 20 hs") y confirmá la inscripción.',
        'Vas a ver la inscripción en Mis Inscripciones. Cuando la organización arme las zonas, tus partidos aparecen en Mis Torneos.',
      ],
    },
    {
      id: 'torneos',
      titulo: 'Torneos',
      ruta: '/torneos',
      resumen: 'Todos los torneos publicados: con inscripción abierta, en curso y finalizados.',
      pasos: [
        'Tocá un torneo para ver sus fechas, precio, observaciones y categorías.',
        'Zonas: posiciones de cada zona (partidos ganados, sets y games).',
        'Partidos: todos los partidos con día, hora, sede y cancha, y los resultados.',
        'Playoff: el cuadro desde la primera ronda hasta la final.',
        'Si la inscripción está abierta, desde ahí inscribís a tu pareja.',
      ],
      ojo: [
        'Una pareja juega en la categoría de su jugador mejor categorizado o en las superiores.',
        'Una dama equivale a un caballero dos categorías abajo (dama 5ta = caballero 7ma). Los caballeros no juegan en Damas.',
        'Categorías por suma: la suma de las categorías de los dos jugadores tiene que llegar a la de la categoría. En Mixto juegan una dama y un caballero.',
        'Cada categoría tiene cupo máximo: si se completa, no admite más parejas.',
      ],
    },
    {
      id: 'mis-inscripciones',
      titulo: 'Mis Inscripciones',
      ruta: '/mis-inscripciones',
      resumen: 'Tus inscripciones, en qué torneo y categoría, y si están pagas.',
      pasos: [
        'Hasta el cierre de inscripción podés editar los problemas de horario o cancelar la inscripción.',
        'El pago lo registra la organización: cuando lo cargan, la inscripción figura como pagada.',
      ],
      ojo: [
        'Después del cierre la inscripción queda firme: no se puede cancelar ni modificar, y se cobra aunque la pareja no se presente.',
      ],
    },
    {
      id: 'mis-parejas',
      titulo: 'Mis Parejas',
      ruta: '/mis-parejas',
      resumen: 'Las parejas que integrás. Podés tener varias (por ejemplo una para cada categoría).',
      pasos: [
        'Nueva pareja: buscá a tu compañero por DNI y creá la pareja.',
        'Podés dar de baja una pareja que ya no uses.',
      ],
      ojo: [
        'Solo las parejas activas se pueden inscribir.',
        'Una pareja con inscripciones vigentes no se puede dar de baja: primero cancelá esas inscripciones.',
        'Un jugador no puede estar en dos parejas inscriptas en la misma categoría de un torneo.',
      ],
    },
    {
      id: 'mis-torneos',
      titulo: 'Mis Torneos',
      ruta: '/mis-torneos',
      resumen: 'Tus próximos partidos y el historial de resultados.',
      pasos: [
        'Partidos: próximos partidos con día, hora, sede y cancha, y los que ya jugaste.',
        'Rendimiento: tus participaciones y hasta qué instancia llegaste en cada torneo.',
      ],
      ojo: [
        'Hay 15 minutos de tolerancia: si la pareja completa no está en el predio, el partido se pierde.',
        'Al llegar, anunciense en pareja con la organización. La cancha asignada es orientativa y puede cambiar.',
      ],
    },
    {
      id: 'formato',
      titulo: 'Formato de los partidos',
      resumen: 'Cómo se juega cada etapa del torneo.',
      pasos: [
        'Zona de 3 parejas: todos contra todos; clasifican 2.',
        'Zona de 4 parejas: 1 vs 4 y 2 vs 3; después ganadores contra ganadores y perdedores contra perdedores. Clasifican 3.',
        'En zona se juega al mejor de 3 sets y el tercero es super tiebreak a 11 (diferencia de 2).',
        'Playoff: mejor de 3 sets normales. Los mejores clasificados pueden pasar directo la primera ronda (bye).',
        'Torneo americano: se juega en el día, a un solo set de 7 o 9 games.',
        'Un W.O. cuenta 2-0 en sets y 12-0 en games.',
      ],
    },
    {
      id: 'jugadores',
      titulo: 'Jugadores',
      ruta: '/jugadores',
      resumen: 'Consultá en qué categoría está cada jugador, por ejemplo antes de armar una pareja.',
      pasos: ['Buscá por nombre o apellido. Los datos de contacto no se muestran.'],
    },
    {
      id: 'perfil',
      titulo: 'Perfil',
      ruta: '/perfil',
      resumen: 'Tus datos y tu contraseña.',
      pasos: [
        'Editá nombre, apellido, teléfono y email. Los datos de contacto los ve solo la organización.',
        'Cambiá tu contraseña cuando quieras.',
        'Mirá el historial de tus cambios de categoría.',
      ],
      ojo: [
        'La categoría y el DNI no los podés cambiar vos: la categoría la ajusta la organización (ascensos o correcciones).',
        'Si te olvidaste la contraseña, pedile a la organización que te la resetee: te dan una clave temporal y al entrar elegís una nueva.',
      ],
    },
  ],
}

const CALENDARIO_COMUN = [
  'Navegá por día, semana o mes con las flechas; "Hoy" vuelve a la fecha actual.',
  'Tocá un partido para cargar el resultado.',
  'También podés cargar resultados desde la pestaña Partidos de cada torneo.',
]

const CARGA_RESULTADOS: SeccionAyuda = {
  id: 'resultados',
  titulo: 'Cómo cargar un resultado',
  resumen: 'La app valida el resultado antes de guardarlo y avanza sola a los ganadores.',
  pasos: [
    'Cargá los games de cada set. Un set termina 6-0 a 6-4, 7-5 o 7-6.',
    'En zona, el tercer set es super tiebreak a 11 con diferencia de 2 (11-7, 12-10…).',
    'Si el partido se definió en 2 sets, dejá el tercero vacío.',
    'En un americano se carga un solo set (por ejemplo 9-5).',
    'W.O.: elegí qué pareja gana; cuenta 2-0 en sets y 12-0 en games.',
    'Al guardar, la tabla de la zona se actualiza y, en playoff, el ganador pasa solo al partido siguiente.',
  ],
}

export const AYUDA_EDITOR: Ayuda = {
  titulo: 'Ayuda de Resultados',
  bajada: 'Como editor podés cargar los resultados de los partidos. Acá te contamos cómo.',
  secciones: [
    {
      id: 'calendario',
      titulo: 'Calendario de partidos',
      ruta: '/calendario',
      resumen: 'Todos los partidos programados de todos los torneos, ordenados por día y horario.',
      pasos: CALENDARIO_COMUN,
    },
    {
      ...CARGA_RESULTADOS,
      ojo: [
        'Como editor solo cargás resultados de partidos pendientes. Si te equivocaste, pedile a un administrador que lo corrija o lo anule.',
        'Solo se puede cargar un partido que ya tiene definidas las dos parejas.',
        'Cada resultado que cargás queda registrado con tu nombre en los Logs.',
      ],
    },
  ],
}

export const AYUDA_ADMIN: Ayuda = {
  titulo: 'Ayuda de Administración',
  bajada: 'Todo lo que podés hacer como administrador, sección por sección, y el orden recomendado para armar un torneo.',
  secciones: [
    {
      id: 'flujo',
      titulo: 'Paso a paso: de cero a la final',
      resumen: 'El orden típico para organizar un torneo.',
      pasos: [
        'Sedes y canchas: revisá que estén cargados los complejos y sus canchas activas.',
        'Armado de torneos → Nuevo torneo: cargá datos, fechas y categorías. Guardalo como borrador.',
        'Cuando quieras abrir la inscripción, pasalo a "Inscripción abierta" (publicado).',
        'Al cierre, en cada categoría: Inscriptos (pagos y bajas) → Zonas → Programación → Playoff.',
        'Durante el torneo, cargá resultados desde el Calendario o desde la categoría.',
        'Cuando termina, pasá el torneo a Finalizado.',
      ],
    },
    {
      id: 'armado',
      titulo: 'Armado de torneos',
      ruta: '/admin/torneos',
      resumen: 'Crear y editar torneos y entrar a gestionar cada categoría.',
      pasos: [
        'Nuevo torneo: nombre, descripción, fechas, cierre de inscripción, precio por pareja y observaciones (premios, pelotas, reglamento).',
        'Torneo americano: se juega en un día, a un solo set de 7 o 9 games.',
        'Habilitá las categorías del torneo y definí el cupo de cada una (máximo 24, mínimo 6 parejas para que se arme).',
        'Estado: Borrador (solo lo ve la administración), Inscripción abierta, En curso, Finalizado o Cancelado.',
        'Desde el listado, "Gestionar" abre cada categoría con sus pestañas.',
      ],
      ojo: [
        'Las fechas de inicio, de fin y de cierre de inscripción son obligatorias.',
        'El cierre de inscripción tiene que ser anterior a la fecha de fin del torneo.',
        'No se puede quitar una categoría que ya tiene parejas inscriptas.',
        'El formato (americano o no, games del set) no se puede cambiar cuando ya hay resultados cargados.',
      ],
    },
    {
      id: 'inscriptos',
      titulo: 'Categoría · Inscriptos',
      resumen: 'Las parejas anotadas en la categoría, con teléfonos y problemas de horario.',
      pasos: [
        'Registrá o desmarcá el pago de cada inscripción.',
        'Inscribir pareja: anotás una pareja con los DNI de los dos jugadores (si no existe la pareja, se crea). Funciona aunque haya cerrado la inscripción, hasta que se cargue el primer resultado.',
        'Cancelar una inscripción. Si la pareja ya estaba en una zona, se borran los partidos de esa zona y hay que rearmarla.',
        'Suspender la categoría (por ejemplo por falta de parejas) o reabrir la inscripción.',
      ],
    },
    {
      id: 'zonas',
      titulo: 'Categoría · Zonas',
      resumen: 'Repartí las parejas en zonas de 3 o 4.',
      pasos: [
        '"Sugerir reparto" propone las zonas automáticamente (mayoría de 3, el resto de 4).',
        'Podés mover parejas entre zonas, agregar zonas y ajustar el orden a mano, teniendo en cuenta los problemas de horario.',
        'Al guardar se crean los partidos de cada zona.',
        'Mientras no haya resultados podés rearmar las zonas: se conserva la sede y el horario de los partidos que no cambian de parejas.',
      ],
      ojo: [
        'Hace falta el mínimo de parejas de la categoría.',
        'Con el primer resultado cargado las zonas ya no se pueden modificar.',
        'Si rearmás las zonas y ya había un cuadro de playoff, hay que volver a armarlo.',
      ],
    },
    {
      id: 'programacion',
      titulo: 'Categoría · Programación',
      resumen: 'Asigná sede, cancha, día y hora a cada partido.',
      pasos: [
        'Elegí el complejo, después una de sus canchas activas, y la fecha y hora.',
        'La app avisa si hay choques: misma cancha a la misma hora, o una pareja con dos partidos superpuestos.',
        'Tenés a la vista los problemas de horario de cada pareja.',
        'Filtrá "Solo sin programar" para ver lo que falta.',
      ],
      ojo: ['Los jugadores ven sede, cancha y horario en Mis Torneos y en el torneo apenas lo guardás.'],
    },
    {
      id: 'playoff',
      titulo: 'Categoría · Playoff',
      resumen: 'Definí los cruces del cuadro.',
      pasos: [
        '"Armar automático": siembra a los 1° de zona, después los 2° y los 3°, con byes para completar el cuadro y evitando que dos parejas de la misma zona se crucen en primera ronda.',
        'También podés armar los cruces a mano (por ejemplo 1° Zona A vs 2° Zona D) y "Guardar cruces".',
        'Se puede armar antes de que terminen las zonas: los clasificados se ubican solos cuando termina cada zona.',
        'Clasifican 2 en las zonas de 3 y 3 en las zonas de 4.',
      ],
      ojo: ['Con resultados de playoff cargados, el cuadro ya no se puede modificar.'],
    },
    {
      id: 'calendario',
      titulo: 'Calendario de partidos',
      ruta: '/calendario',
      resumen: 'Todos los partidos programados de todos los torneos.',
      pasos: [...CALENDARIO_COMUN, 'Como administrador también podés editar o anular un resultado ya cargado.'],
    },
    {
      ...CARGA_RESULTADOS,
      ojo: [
        'Para modificar un partido cuyo ganador ya jugó el partido siguiente, primero anulá el resultado de ese siguiente.',
        'Al cargar la final, la categoría queda finalizada.',
      ],
    },
    {
      id: 'estadisticas',
      titulo: 'Estadísticas',
      ruta: '/admin/estadisticas',
      resumen: 'Participaciones y logros de los jugadores.',
      pasos: [
        'Totales de jugadores, parejas y torneos.',
        'Ranking por participaciones y por instancia alcanzada (campeón, finalista, semis…).',
        'Filtrá por período (usa la fecha de inicio de cada torneo) y buscá por nombre o DNI.',
      ],
    },
    {
      id: 'admin-jugadores',
      titulo: 'Jugadores (administración)',
      ruta: '/admin/jugadores',
      resumen: 'Todos los jugadores registrados, con DNI y teléfono.',
      pasos: [
        'Buscá por apellido, nombre o DNI y filtrá por categoría, rol o estado.',
        'Recategorizá (ascensos o ajustes). Si el jugador queda con inscripciones en categorías donde ya no puede jugar, la app te las muestra para cancelarlas o dejarlas.',
        'Asigná roles: Jugador, Editor (carga resultados) o Administrador.',
        'Activá o desactivá jugadores.',
        'Resetear contraseña: genera una clave temporal que se muestra una sola vez; copiá el mensaje y mandáselo al jugador.',
      ],
      ojo: ['Cada cambio de categoría queda en el historial del jugador.'],
    },
    {
      id: 'categorias',
      titulo: 'Categorías',
      ruta: '/admin/categorias',
      resumen: 'Las categorías que se pueden habilitar en los torneos.',
      pasos: [
        'Las categorías de nivel (3ra a 7ma, Caballeros y Damas) vienen fijas.',
        'Creá categorías por suma (por ejemplo Suma 12 Mixto) eligiendo género y suma.',
        'Activá o desactivá categorías: las inactivas no aparecen al armar un torneo.',
      ],
    },
    {
      id: 'sedes',
      titulo: 'Sedes y canchas',
      ruta: '/admin/sedes',
      resumen: 'Los complejos donde se juegan los partidos y sus canchas.',
      pasos: [
        'Agregá o editá complejos y sus canchas (nombre y orden).',
        'Desactivá los que no uses: no aparecen al programar.',
      ],
    },
    {
      id: 'logs',
      titulo: 'Logs',
      ruta: '/admin/logs',
      resumen: 'Quién hizo qué y cuándo.',
      pasos: [
        'Movimientos de administradores y editores: torneos, categorías, inscripciones, jugadores, resultados, programación, zonas y sedes.',
        'Filtrá por fechas, usuario, rol, tipo de movimiento o texto.',
      ],
    },
  ],
}