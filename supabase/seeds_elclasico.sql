-- =====================================================================
-- SEEDS · DATOS DE PRUEBA · Torneos de Pádel EL CLÁSICO
-- ---------------------------------------------------------------------
-- Crea 118 jugadores (que pueden loguearse), parejas y 6 torneos en
-- distintos estados, con zonas, programación y resultados:
--
--   1. Torneo Apertura ............. FINALIZADO   (5ta C, 6ta C, 6ta D)
--   2. Americano Mixto ............. FINALIZADO   (Suma 10 Mixto, Suma 11 C) · set a 9
--   3. Torneo Primavera ............ EN CURSO     (4ta C en playoff, 5ta C en zonas, 7ma D sin jugar)
--   4. Torneo Octubre .............. INSCRIPCIÓN ABIERTA (todas las categorías de nivel)
--   5. Americano Suma 12 ........... INSCRIPCIÓN ABIERTA (Suma 12 Mixto) · set a 7
--   6. Torneo Verano ............... BORRADOR
--
-- Las fechas son RELATIVAS al día en que lo corrés ('hoy'), así la demo siempre
-- queda coherente: el Primavera está en curso, el Octubre con la inscripción
-- abierta, etc. Con hoy = '2026-09-24' reproduce exactamente las fechas de la
-- demo original.
--
-- Arma zonas con armar_zonas_manual y el playoff con armar_cuadro (el mismo
-- camino que usa la app); si armar_cuadro no existe, usa generar_playoff.
--
-- Solo toca tablas del Gestor de Torneos: las tablas reservas_* (Gestor de
-- Reservas) no se leen ni se modifican.
--
-- CÓMO USARLO
--   1. Revisá las variables de abajo (sobre todo el dominio).
--   2. Pegalo completo en el SQL Editor de Supabase y ejecutalo.
--   3. Los jugadores demo entran con DNI 99000001 ... 99000118 y la clave de abajo.
--
-- Todo lo que crea usa ids que empiezan con 'de300000-' para poder borrarlo
-- sin tocar tus datos reales (ver el script de borrado al final).
-- Se puede volver a correr: primero borra la demo anterior.
-- =====================================================================

create or replace function pg_temp.cfg(k text) returns text language sql immutable as $$
  select case k
    -- Tiene que coincidir EXACTO con VITE_AUTH_EMAIL_DOMAIN
    when 'dominio'  then 'jugadores.elclasico.com.ar'
    -- Clave de todos los jugadores demo
    when 'password' then 'demo1234'
    -- Opcional: tu DNI (ya registrado) para que te aparezca una pareja e inscripción
    -- en el Torneo Octubre. Dejalo vacío ('') si no querés.
    when 'mi_dni'   then ''
    -- Día de referencia de la demo ('' = el día en que se ejecuta)
    when 'hoy'      then ''
    -- Complejos (tienen que existir en Sedes, con sus canchas activas)
    when 'sede1'    then 'El Clásico'      -- 3 canchas: BX1, BX2, C1
    when 'sede2'    then 'El Clásico 2'    -- 1 cancha: C1
  end
$$;

-- Fecha / fecha-hora relativas a 'hoy' (hora de Argentina)
create or replace function pg_temp.d(n int) returns date language sql stable as $$
  select coalesce(nullif(pg_temp.cfg('hoy'), '')::date,
                  (now() at time zone 'America/Argentina/Buenos_Aires')::date) + n
$$;
create or replace function pg_temp.ts(n int, h time) returns timestamptz language sql stable as $$
  select (pg_temp.d(n) + h) at time zone 'America/Argentina/Buenos_Aires'
$$;

-- ---------------------------------------------------------------------
-- 0. Borrar demo anterior
-- ---------------------------------------------------------------------
delete from public.torneos where id::text like 'de300000-%';
delete from auth.users     where id::text like 'de300000-%';

select setseed(0.42);

-- Chequeos previos: sedes, canchas y categorías que usa la demo
do $$
declare
  c text;
  faltan text[] := '{}';
begin
  if (select count(*) from public.canchas ca join public.sedes se on se.id = ca.sede_id
      where se.nombre = pg_temp.cfg('sede1') and ca.activa) < 3 then
    raise exception 'La sede "%" no existe o tiene menos de 3 canchas activas (revisá cfg sede1)', pg_temp.cfg('sede1');
  end if;
  if (select count(*) from public.canchas ca join public.sedes se on se.id = ca.sede_id
      where se.nombre = pg_temp.cfg('sede2') and ca.activa) < 1 then
    raise exception 'La sede "%" no existe o no tiene canchas activas (revisá cfg sede2)', pg_temp.cfg('sede2');
  end if;
  foreach c in array array['3ra Caballeros','4ta Caballeros','5ta Caballeros','6ta Caballeros','7ma Caballeros',
                           '4ta Damas','5ta Damas','6ta Damas','7ma Damas',
                           'Suma 10 Mixto','Suma 11 Caballeros','Suma 12 Mixto','Suma 12 Caballeros'] loop
    if not exists (select 1 from public.categorias where nombre = c) then faltan := faltan || c; end if;
  end loop;
  if array_length(faltan, 1) > 0 then
    raise exception 'Faltan categorías: %', array_to_string(faltan, ', ');
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Helpers (temporales: desaparecen al terminar la ejecución)
-- ---------------------------------------------------------------------
create or replace function pg_temp.uid(p_tipo int, n int) returns uuid language sql immutable as $$
  select ('de300000-0000-4000-' || p_tipo || '000-' || lpad(n::text, 12, '0'))::uuid
$$;

create or replace function pg_temp.crear_jugador(n int, p_nombre text, p_apellido text, p_cat smallint)
returns uuid language plpgsql as $$
declare
  v_id uuid := pg_temp.uid(8, n);
  v_dni text := (99000000 + n)::text;
  v_email text := v_dni || '@' || pg_temp.cfg('dominio');
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change, email_change_token_new
  ) values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated', v_email,
    extensions.crypt(pg_temp.cfg('password'), extensions.gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object('dni', v_dni, 'nombre', p_nombre, 'apellido', p_apellido,
                       'telefono', '3407' || lpad((400000 + n * 137)::text, 6, '0'), 'categoria_id', p_cat),
    now() - interval '60 days', now(), '', '', '', ''
  );
  insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), v_id, v_id::text, 'email',
          jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true),
          now(), now(), now());
  return v_id;
end $$;

create or replace function pg_temp.pareja(a uuid, b uuid) returns uuid language plpgsql as $$
declare v uuid;
begin
  select id into v from public.parejas where jugador1_id = least(a, b) and jugador2_id = greatest(a, b);
  if v is null then
    insert into public.parejas (jugador1_id, jugador2_id, creada_por)
    values (least(a, b), greatest(a, b), a) returning id into v;
  end if;
  return v;
end $$;

create or replace function pg_temp.cat(p_nombre text) returns smallint language sql stable as $$
  select id from public.categorias where nombre = p_nombre
$$;

create or replace function pg_temp.torneo_cat(p_torneo uuid, p_cat text) returns uuid language sql as $$
  insert into public.torneo_categorias (torneo_id, categoria_id) values (p_torneo, pg_temp.cat(p_cat)) returning id
$$;

-- Inscribe las parejas del array (le pone "problemas de horario" a algunas)
create or replace function pg_temp.inscribir(p_tc uuid, p_parejas uuid[], p_pagada boolean) returns void language plpgsql as $$
declare
  i int;
  v_horarios text[] := array['', '', '', 'No podemos antes de las 20 hs', '', 'Viernes solo después de las 21', '',
                             'Sábado a la mañana no', '', ''];
begin
  for i in 1..coalesce(array_length(p_parejas, 1), 0) loop
    insert into public.inscripciones (torneo_categoria_id, pareja_id, problemas_horario, pagada, created_at)
    values (p_tc, p_parejas[i], v_horarios[(i % 10) + 1], p_pagada, now() - (40 - i) * interval '1 hour');
  end loop;
end $$;

-- Asigna sede, cancha y horario a los partidos (zona o playoff) que todavía no tienen.
-- p_paralelo partidos por turno (uno por cancha), p_turnos turnos por día.
create or replace function pg_temp.programar(
  p_tc uuid, p_zona boolean, p_dia date, p_hora time, p_paso interval,
  p_paralelo int, p_turnos int, p_sedes text[], p_offset int default 0
) returns int language plpgsql as $$
declare
  r record;
  v_turno int := p_offset;   -- turno actual
  v_col int := 0;            -- cancha dentro del turno
  v_fase public.fase_partido;
begin
  for r in
    select p.id, p.fase from public.partidos p left join public.zonas z on z.id = p.zona_id
    where p.torneo_categoria_id = p_tc and (p.fase = 'zona') = p_zona and p.estado <> 'bye' and p.fecha_hora is null
    order by array_position(array['zona','dieciseisavos','octavos','cuartos','semifinal','final']::public.fase_partido[], p.fase),
             p.ronda, z.nombre, p.orden
  loop
    -- en playoff cada ronda arranca en un turno nuevo (no se juega semi a la vez que cuartos)
    if (v_col >= p_paralelo) or (v_fase is not null and r.fase <> v_fase and v_col > 0) then
      v_turno := v_turno + 1;
      v_col := 0;
    end if;
    v_fase := r.fase;
    update public.partidos set
      sede_id = (select id from public.sedes where nombre = p_sedes[v_col % array_length(p_sedes, 1) + 1]),
      -- k-ésima cancha (por orden) del complejo elegido
      cancha_id = (select ca.id from public.canchas ca join public.sedes se on se.id = ca.sede_id
                   where se.nombre = p_sedes[v_col % array_length(p_sedes, 1) + 1] and ca.activa
                   order by ca.orden, ca.nombre offset v_col / array_length(p_sedes, 1) limit 1),
      fecha_hora = ((p_dia + (v_turno / p_turnos)) + p_hora + (v_turno % p_turnos) * p_paso)
                   at time zone 'America/Argentina/Buenos_Aires'
    where id = r.id;
    v_col := v_col + 1;
  end loop;
  return v_turno + case when v_col > 0 then 1 else 0 end;   -- próximo turno libre
end $$;

-- Resultado aleatorio pero válido para un partido
create or replace function pg_temp.resultado(p_id uuid) returns void language plpgsql as $$
declare
  p public.partidos;
  g smallint;
  gana_a boolean := random() < 0.5;
  sets int[];
  perdidos int[] := array[0, 1, 2, 2, 3, 3, 4, 4, 5, 6];   -- games del perdedor de un set
  x int; i int; tres boolean;
begin
  select * into p from public.partidos where id = p_id;
  select t.games_set_unico into g from public.torneo_categorias tc join public.torneos t on t.id = tc.torneo_id
  where tc.id = p.torneo_categoria_id;

  if random() < 0.04 then   -- algún W.O. suelto
    update public.partidos set estado = 'wo', ganador_id = case when gana_a then pareja_a_id else pareja_b_id end where id = p_id;
    return;
  end if;

  if g is not null then
    x := floor(random() * g)::int;
    update public.partidos set estado = 'finalizado',
      s1_a = case when gana_a then g else x end, s1_b = case when gana_a then x else g end
    where id = p_id;
    return;
  end if;

  tres := random() < 0.35;
  sets := '{}';
  for i in 1..3 loop
    x := perdidos[1 + floor(random() * 10)::int];
    if i = 3 and p.super_tiebreak then
      x := floor(random() * 10)::int;                      -- super tiebreak 11-x
      sets := sets || case when gana_a then array[11, x] else array[x, 11] end;
    else
      -- set 1: gana el ganador; set 2: si hay 3 sets lo gana el perdedor
      sets := sets || case
        when (i = 2 and tres) <> gana_a then array[case when x = 5 then 7 when x = 6 then 7 else 6 end, x]
        else array[x, case when x = 5 then 7 when x = 6 then 7 else 6 end] end;
    end if;
    exit when i = 2 and not tres;
  end loop;

  update public.partidos set estado = 'finalizado',
    s1_a = sets[1], s1_b = sets[2], s2_a = sets[3], s2_b = sets[4], s3_a = sets[5], s3_b = sets[6]
  where id = p_id;
end $$;

-- Juega hasta p_max partidos pendientes (zona o playoff, en orden), respetando que tengan las 2 parejas
create or replace function pg_temp.jugar(p_tc uuid, p_zona boolean, p_max int default 1000) returns void language plpgsql as $$
declare v uuid; k int := 0;
begin
  loop
    exit when k >= p_max;
    select p.id into v from public.partidos p left join public.zonas z on z.id = p.zona_id
    where p.torneo_categoria_id = p_tc and (p.fase = 'zona') = p_zona and p.estado = 'pendiente'
      and p.pareja_a_id is not null and p.pareja_b_id is not null
    order by array_position(array['zona','dieciseisavos','octavos','cuartos','semifinal','final']::public.fase_partido[], p.fase),
             p.ronda, z.nombre, p.orden
    limit 1;
    exit when v is null;
    perform pg_temp.resultado(v);
    k := k + 1;
  end loop;
end $$;

-- Zonas al azar (mayoría de 3, resto de 4) guardadas con armar_zonas_manual
create or replace function pg_temp.armar_zonas(p_tc uuid) returns void language plpgsql as $$
declare
  v_ins uuid[]; v_n int; v_z int; v_de4 int; v_tam int; v_idx int := 1; i int;
  v_zonas jsonb := '[]';
begin
  -- random() se asigna en orden de inscripción (no en el orden físico de la tabla): mismo seed → mismas zonas
  select array_agg(id order by r, created_at) into v_ins
  from (select id, created_at, random() as r
        from (select id, created_at from public.inscripciones
              where torneo_categoria_id = p_tc and estado = 'activa' order by created_at, id) o) x;
  v_n := coalesce(array_length(v_ins, 1), 0);
  v_z := v_n / 3;
  v_de4 := v_n - 3 * v_z;
  for i in 1..v_z loop
    v_tam := case when i <= v_de4 then 4 else 3 end;
    v_zonas := v_zonas || jsonb_build_array(to_jsonb(v_ins[v_idx : v_idx + v_tam - 1]));
    v_idx := v_idx + v_tam;
  end loop;
  if to_regproc('public.armar_zonas_manual') is not null then
    perform public.armar_zonas_manual(p_tc, v_zonas);
  else
    perform public.generar_zonas(p_tc);
  end if;
end $$;

-- Playoff automático: armar_cuadro(tc, null) como el botón de la app; si no existe, generar_playoff
create or replace function pg_temp.armar_playoff(p_tc uuid) returns void language plpgsql as $$
begin
  if to_regproc('public.armar_cuadro') is not null then
    execute 'select public.armar_cuadro($1, null)' using p_tc;
  else
    perform public.generar_playoff(p_tc);
  end if;
end $$;

-- Categoría completa: zonas → programación → resultados → playoff → final
create or replace function pg_temp.jugar_todo(p_tc uuid, p_dia date, p_hora time, p_paso interval,
                                               p_paralelo int, p_turnos int, p_sedes text[]) returns void language plpgsql as $$
declare v_turno int;
begin
  perform pg_temp.armar_zonas(p_tc);
  v_turno := pg_temp.programar(p_tc, true, p_dia, p_hora, p_paso, p_paralelo, p_turnos, p_sedes);
  perform pg_temp.jugar(p_tc, true);
  perform pg_temp.armar_playoff(p_tc);
  perform pg_temp.programar(p_tc, false, p_dia, p_hora, p_paso, p_paralelo, p_turnos, p_sedes, v_turno);
  perform pg_temp.jugar(p_tc, false);
end $$;

-- ---------------------------------------------------------------------
-- 1. Jugadores
-- ---------------------------------------------------------------------
drop table if exists pg_temp.demo_jug;
create temp table demo_jug (n int primary key, cat text, id uuid);

do $$
declare
  nombres_c text[] := array['Juan','Martín','Lucas','Nicolás','Federico','Matías','Santiago','Diego','Pablo','Gonzalo',
                            'Facundo','Tomás','Agustín','Franco','Leandro','Ezequiel','Ignacio','Marcos','Rodrigo','Julián'];
  nombres_d text[] := array['Sofía','Valentina','Camila','Lucía','Florencia','Agustina','Micaela','Julieta','Carolina','Paula',
                            'Romina','Belén','Natalia','Victoria','Daniela','Antonella','Milagros','Luciana','Rocío','Celeste'];
  apellidos text[] := array['González','Rodríguez','Fernández','López','Martínez','Pérez','Gómez','Sánchez','Romero','Díaz',
                            'Álvarez','Torres','Ruiz','Ramírez','Flores','Benítez','Acosta','Medina','Herrera','Suárez',
                            'Aguirre','Pereyra','Gutiérrez','Giménez','Molina','Silva','Castro','Rojas','Ortiz','Núñez',
                            'Luna','Juárez','Cabrera','Ríos','Ferreyra','Godoy','Morales','Domínguez','Moreno','Peralta'];
  plan text[][] := array[
    array['3ra Caballeros','4'], array['4ta Caballeros','18'], array['5ta Caballeros','24'], array['6ta Caballeros','20'],
    array['7ma Caballeros','8'], array['4ta Damas','6'], array['5ta Damas','8'], array['6ta Damas','16'], array['7ma Damas','14']];
  n int := 0; i int; k int; dama boolean;
begin
  for i in 1..array_length(plan, 1) loop
    dama := plan[i][1] like '%Damas';
    for k in 1..plan[i][2]::int loop
      n := n + 1;
      insert into demo_jug values (n, plan[i][1], pg_temp.crear_jugador(
        n,
        (case when dama then nombres_d else nombres_c end)[1 + floor(random() * 20)::int],
        apellidos[1 + floor(random() * 40)::int],
        pg_temp.cat(plan[i][1])));
    end loop;
  end loop;
end $$;

-- Jugador k-ésimo de una categoría
create or replace function pg_temp.j(p_cat text, k int) returns uuid language sql stable as $$
  select id from demo_jug where cat = p_cat order by n offset k - 1 limit 1
$$;
-- Parejas "fijas" de una categoría: (1,2), (3,4), ... ; devuelve las primeras p_cant
create or replace function pg_temp.parejas_de(p_cat text, p_cant int, p_desde int default 1) returns uuid[] language sql as $$
  select array_agg(pg_temp.pareja(pg_temp.j(p_cat, 2 * k - 1), pg_temp.j(p_cat, 2 * k)) order by k)
  from generate_series(p_desde, p_desde + p_cant - 1) k
$$;
-- Parejas mixtas / cruzadas: jugador k de cat1 con jugador k de cat2
create or replace function pg_temp.cruzadas(p_cat1 text, p_cat2 text, p_cant int, p_desde1 int default 1, p_desde2 int default 1)
returns uuid[] language sql as $$
  select array_agg(pg_temp.pareja(pg_temp.j(p_cat1, p_desde1 + k - 1), pg_temp.j(p_cat2, p_desde2 + k - 1)) order by k)
  from generate_series(1, p_cant) k
$$;

-- ---------------------------------------------------------------------
-- 2. Torneos
-- ---------------------------------------------------------------------
do $$
declare
  t1 uuid := pg_temp.uid(9, 1); t2 uuid := pg_temp.uid(9, 2); t3 uuid := pg_temp.uid(9, 3);
  t4 uuid := pg_temp.uid(9, 4); t5 uuid := pg_temp.uid(9, 5); t6 uuid := pg_temp.uid(9, 6);
  tc uuid;
  s1 text := pg_temp.cfg('sede1');
  s2 text := pg_temp.cfg('sede2');
  dos_sedes text[] := array[pg_temp.cfg('sede1'), pg_temp.cfg('sede2')];
  club text[] := array[pg_temp.cfg('sede1')];
  c text;
  yo uuid; mi_cat text; compa uuid;
begin
  insert into public.torneos (id, nombre, descripcion, fecha_desde, fecha_hasta, cierre_inscripcion, observaciones,
                              precio_inscripcion, estado, americano, games_set_unico) values
  (t1, 'Torneo Apertura', 'Primera fecha del circuito del complejo.', pg_temp.d(-48), pg_temp.d(-46),
   pg_temp.ts(-50, '20:00'), 'Premios para campeones y finalistas. Pelotas nuevas en cada partido.', 30000, 'finalizado', false, null),
  (t2, 'Americano Mixto', 'Americano de un día, un set a 9 games.', pg_temp.d(-18), pg_temp.d(-18),
   pg_temp.ts(-19, '12:00'), 'Arranca 9 hs. Cantina abierta todo el día.', 20000, 'finalizado', true, 9),
  (t3, 'Torneo Primavera', 'Segunda fecha del circuito.', pg_temp.d(-5), pg_temp.d(3),
   pg_temp.ts(-7, '20:00'), 'Finales el ' || to_char(pg_temp.d(3), 'DD/MM') || ' desde las 16 hs.', 32000, 'en_curso', false, null),
  (t4, 'Torneo Octubre', 'Tercera fecha del circuito. Todas las categorías.', pg_temp.d(21), pg_temp.d(24),
   pg_temp.ts(18, '20:00'), 'Consultas al 3407-555000.', 32000, 'publicado', false, null),
  (t5, 'Americano Suma 12', 'Americano mixto de un día, un set a 7 games.', pg_temp.d(10), pg_temp.d(10),
   pg_temp.ts(9, '12:00'), 'Arranca 10 hs.', 20000, 'publicado', true, 7),
  (t6, 'Torneo Verano', 'Borrador: todavía no publicado.', pg_temp.d(77), pg_temp.d(80),
   pg_temp.ts(74, '20:00'), null, null, 'borrador', false, null);

  -- 1. Apertura (finalizado): 3 días, 2 sedes, turnos de 1h15 desde las 17
  tc := pg_temp.torneo_cat(t1, '5ta Caballeros');
  perform pg_temp.inscribir(tc, pg_temp.parejas_de('5ta Caballeros', 12), true);
  perform pg_temp.jugar_todo(tc, pg_temp.d(-48), '17:00', '75 min', 2, 5, dos_sedes);
  tc := pg_temp.torneo_cat(t1, '6ta Caballeros');
  perform pg_temp.inscribir(tc, pg_temp.parejas_de('6ta Caballeros', 10), true);
  perform pg_temp.jugar_todo(tc, pg_temp.d(-48), '17:00', '75 min', 2, 5, array[s1]);
  tc := pg_temp.torneo_cat(t1, '6ta Damas');
  perform pg_temp.inscribir(tc, pg_temp.parejas_de('6ta Damas', 8), true);
  perform pg_temp.jugar_todo(tc, pg_temp.d(-47), '10:00', '75 min', 1, 6, array[s2]);

  -- 2. Americano Mixto (finalizado): todo el día en la sede 1, 3 canchas, turnos de 40 min
  tc := pg_temp.torneo_cat(t2, 'Suma 10 Mixto');
  perform pg_temp.inscribir(tc,
    pg_temp.cruzadas('4ta Damas', '6ta Caballeros', 6, 1, 11) || pg_temp.cruzadas('5ta Damas', '5ta Caballeros', 2, 1, 13), true);
  perform pg_temp.jugar_todo(tc, pg_temp.d(-18), '09:00', '40 min', 3, 20, club);
  tc := pg_temp.torneo_cat(t2, 'Suma 11 Caballeros');
  perform pg_temp.inscribir(tc, pg_temp.cruzadas('5ta Caballeros', '6ta Caballeros', 6, 1, 1), true);
  perform pg_temp.jugar_todo(tc, pg_temp.d(-18), '13:00', '40 min', 3, 20, club);

  -- 3. Primavera (en curso)
  --    4ta C: zonas y cuartos jugados; semis en 2 días, final en 3
  tc := pg_temp.torneo_cat(t3, '4ta Caballeros');
  perform pg_temp.inscribir(tc, pg_temp.parejas_de('4ta Caballeros', 9), true);
  perform pg_temp.armar_zonas(tc);
  perform pg_temp.programar(tc, true, pg_temp.d(-5), '18:00', '75 min', 2, 5, dos_sedes);
  perform pg_temp.jugar(tc, true);
  perform pg_temp.armar_playoff(tc);
  perform pg_temp.programar(tc, false, pg_temp.d(-1), '20:00', '90 min', 2, 2, dos_sedes);
  perform pg_temp.jugar(tc, false, 2);   -- cuartos jugados; semis pasado mañana y final al otro día
  update public.partidos set fecha_hora = pg_temp.ts(2, '20:00') + (orden - 1) * interval '90 min',
         sede_id = (select id from public.sedes where nombre = s1),
         cancha_id = (select ca.id from public.canchas ca join public.sedes se on se.id = ca.sede_id where se.nombre = s1 order by ca.orden limit 1)
  where torneo_categoria_id = tc and fase = 'semifinal';
  update public.partidos set fecha_hora = pg_temp.ts(3, '18:00'), sede_id = (select id from public.sedes where nombre = s1),
         cancha_id = (select ca.id from public.canchas ca join public.sedes se on se.id = ca.sede_id where se.nombre = s1 order by ca.orden limit 1)
  where torneo_categoria_id = tc and fase = 'final';
  --    5ta C: zonas a medio jugar
  tc := pg_temp.torneo_cat(t3, '5ta Caballeros');
  perform pg_temp.inscribir(tc, pg_temp.parejas_de('5ta Caballeros', 11), true);
  perform pg_temp.armar_zonas(tc);
  perform pg_temp.programar(tc, true, pg_temp.d(-1), '18:30', '75 min', 2, 3, array[s1]);
  perform pg_temp.jugar(tc, true, 6);   -- lo de ayer jugado; lo de hoy y mañana, pendiente
  --    7ma D: zonas armadas y programadas, sin jugar
  tc := pg_temp.torneo_cat(t3, '7ma Damas');
  perform pg_temp.inscribir(tc, pg_temp.parejas_de('7ma Damas', 7), false);
  perform pg_temp.armar_zonas(tc);
  perform pg_temp.programar(tc, true, pg_temp.d(1), '19:00', '75 min', 1, 5, array[s2]);

  -- 4. Octubre (inscripción abierta): todas las categorías de nivel, con distinta cantidad de inscriptas
  for c in select nombre from public.categorias where tipo = 'nivel' order by orden loop
    tc := pg_temp.torneo_cat(t4, c);
  end loop;
  perform pg_temp.inscribir((select id from public.torneo_categorias where torneo_id = t4 and categoria_id = pg_temp.cat('4ta Caballeros')), pg_temp.parejas_de('4ta Caballeros', 5), false);
  perform pg_temp.inscribir((select id from public.torneo_categorias where torneo_id = t4 and categoria_id = pg_temp.cat('5ta Caballeros')), pg_temp.parejas_de('5ta Caballeros', 9), false);
  perform pg_temp.inscribir((select id from public.torneo_categorias where torneo_id = t4 and categoria_id = pg_temp.cat('6ta Caballeros')), pg_temp.parejas_de('6ta Caballeros', 6), false);
  perform pg_temp.inscribir((select id from public.torneo_categorias where torneo_id = t4 and categoria_id = pg_temp.cat('7ma Caballeros')), pg_temp.parejas_de('7ma Caballeros', 3), false);
  perform pg_temp.inscribir((select id from public.torneo_categorias where torneo_id = t4 and categoria_id = pg_temp.cat('6ta Damas')), pg_temp.parejas_de('6ta Damas', 4), false);
  perform pg_temp.inscribir((select id from public.torneo_categorias where torneo_id = t4 and categoria_id = pg_temp.cat('7ma Damas')), pg_temp.parejas_de('7ma Damas', 6), false);

  -- 5. Americano Suma 12 (inscripción abierta)
  tc := pg_temp.torneo_cat(t5, 'Suma 12 Mixto');
  perform pg_temp.inscribir(tc, pg_temp.cruzadas('6ta Damas', '6ta Caballeros', 5, 1, 1), false);
  tc := pg_temp.torneo_cat(t5, 'Suma 12 Caballeros');
  perform pg_temp.inscribir(tc, pg_temp.cruzadas('5ta Caballeros', '7ma Caballeros', 4, 15, 1), false);

  -- 6. Verano (borrador)
  perform pg_temp.torneo_cat(t6, '5ta Caballeros');
  perform pg_temp.torneo_cat(t6, '6ta Caballeros');

  -- Opcional: vos con un compañero demo en el Torneo Octubre
  if pg_temp.cfg('mi_dni') <> '' then
    select j.id, c2.nombre into yo, mi_cat from public.jugadores j join public.categorias c2 on c2.id = j.categoria_id
    where j.dni = pg_temp.cfg('mi_dni');
    if yo is null then
      raise notice 'No encontré un jugador con DNI %: salteo tu inscripción', pg_temp.cfg('mi_dni');
    else
      select id into compa from demo_jug where cat = mi_cat order by n desc limit 1;   -- el último, que no está inscripto
      perform pg_temp.inscribir((select id from public.torneo_categorias where torneo_id = t4 and categoria_id = pg_temp.cat(mi_cat)),
                                array[pg_temp.pareja(yo, compa)], false);
      raise notice 'Te inscribí en Torneo Octubre · % con un compañero demo', mi_cat;
    end if;
  end if;
end $$;

-- Ids de los torneos con el prefijo demo (para el borrado)
-- (los torneos se crearon con uid(9, n) → 'de300000-0000-4000-9000-...')

-- Resumen
select t.nombre, t.estado, c.nombre as categoria, tc.estado as estado_categoria,
       (select count(*) from public.inscripciones i where i.torneo_categoria_id = tc.id and i.estado = 'activa') as parejas,
       (select count(*) from public.partidos p where p.torneo_categoria_id = tc.id and p.estado in ('finalizado', 'wo')) as jugados,
       (select count(*) from public.partidos p where p.torneo_categoria_id = tc.id and p.estado = 'pendiente') as pendientes
from public.torneos t
join public.torneo_categorias tc on tc.torneo_id = t.id
join public.categorias c on c.id = tc.categoria_id
where t.id::text like 'de300000-%'
order by t.fecha_desde, c.orden;

-- =====================================================================
-- PARA BORRAR SOLO LA DEMO (sin tocar tus datos), corré estas 2 líneas:
--
--   delete from public.torneos where id::text like 'de300000-%';
--   delete from auth.users     where id::text like 'de300000-%';
-- =====================================================================