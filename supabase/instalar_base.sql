-- =====================================================================
--  INSTALACIÓN · Gestor de Torneos EL CLÁSICO · base Supabase nueva
-- ---------------------------------------------------------------------
--  Generado a partir del dump de la base actual de El Clásico
--  (estructura del schema public + configuración), SIN el Gestor de
--  Reservas: no crea ninguna tabla reservas_* ni sus funciones.
--
--  Crea: tipos, tablas, funciones, triggers, vistas, políticas RLS y
--  permisos; el trigger de alta de jugadores sobre auth.users; y la
--  configuración (categorías, sedes El Clásico / El Clásico 2 y canchas).
--  No crea jugadores, torneos ni datos de prueba.
--
--  CÓMO USARLO (proyecto Supabase NUEVO y vacío)
--    1. SQL Editor → pegá este archivo completo → Run.
--       Corre en una transacción: si algo falla, no queda nada a medias.
--    2. Authentication → Sign In / Providers → Email: desactivá
--       "Confirm email" (el login es por DNI con un email sintético).
--    3. En la app (.env o Vercel) apuntá VITE_SUPABASE_URL y
--       VITE_SUPABASE_ANON_KEY al proyecto nuevo. Mantené el mismo
--       VITE_AUTH_EMAIL_DOMAIN.
--    4. Registrate desde la app y hacete administrador:
--         update public.jugadores set rol = 'administrador' where dni = 'TU_DNI';
--    5. (Opcional) Datos de prueba: seeds_elclasico.sql.
-- =====================================================================

begin;

set local statement_timeout = 0;
set local lock_timeout = 0;
set local check_function_bodies = false;
set local client_min_messages = warning;
set local row_security = off;
select pg_catalog.set_config('search_path', '', true);

create extension if not exists pgcrypto with schema extensions;

-- =====================================================================
--  ESTRUCTURA (dump de El Clásico, sin Reservas)
-- =====================================================================
--
-- Name: estado_inscripcion; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.estado_inscripcion AS ENUM (
    'activa',
    'cancelada'
);


--
-- Name: estado_partido; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.estado_partido AS ENUM (
    'pendiente',
    'finalizado',
    'wo',
    'bye'
);


--
-- Name: estado_torneo; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.estado_torneo AS ENUM (
    'borrador',
    'publicado',
    'en_curso',
    'finalizado',
    'cancelado'
);


--
-- Name: estado_torneo_categoria; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.estado_torneo_categoria AS ENUM (
    'inscripcion',
    'zonas',
    'playoff',
    'finalizada',
    'suspendida'
);


--
-- Name: fase_partido; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.fase_partido AS ENUM (
    'zona',
    'dieciseisavos',
    'octavos',
    'cuartos',
    'semifinal',
    'final'
);


--
-- Name: genero_categoria; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.genero_categoria AS ENUM (
    'caballeros',
    'damas',
    'mixto'
);


--
-- Name: rol_usuario; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.rol_usuario AS ENUM (
    'jugador',
    'editor',
    'administrador'
);


--
-- Name: admin_inscribir(uuid, text, text, text, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_inscribir(p_torneo_categoria uuid, p_dni1 text, p_dni2 text, p_horario text, p_pagada boolean DEFAULT false) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  a uuid; b uuid; v_par uuid; v_ins uuid;
begin
  if not public.es_sistema_o_admin() then raise exception 'Solo el administrador puede inscribir parejas de otros jugadores'; end if;
  select id into a from public.jugadores where dni = trim(p_dni1) and activo;
  select id into b from public.jugadores where dni = trim(p_dni2) and activo;
  if a is null then raise exception 'No hay un jugador activo con DNI %', trim(p_dni1); end if;
  if b is null then raise exception 'No hay un jugador activo con DNI %', trim(p_dni2); end if;
  if a = b then raise exception 'Los dos DNI son del mismo jugador'; end if;

  select id into v_par from public.parejas where jugador1_id = least(a, b) and jugador2_id = greatest(a, b);
  if v_par is null then
    insert into public.parejas (jugador1_id, jugador2_id, creada_por)
    values (least(a, b), greatest(a, b), auth.uid()) returning id into v_par;
  else
    update public.parejas set activa = true where id = v_par and not activa;
  end if;

  insert into public.inscripciones (torneo_categoria_id, pareja_id, problemas_horario, pagada, inscripta_por)
  values (p_torneo_categoria, v_par, coalesce(nullif(trim(p_horario), ''), 'Ninguno'), coalesce(p_pagada, false), auth.uid())
  returning id into v_ins;
  return v_ins;
end $$;


--
-- Name: admin_inscriptos(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_inscriptos(p_torneo_categoria uuid) RETURNS TABLE(id uuid, pareja_id uuid, pareja text, jugador1 text, dni1 text, telefono1 text, categoria1 text, jugador2 text, dni2 text, telefono2 text, categoria2 text, problemas_horario text, estado public.estado_inscripcion, pagada boolean, created_at timestamp with time zone, zona text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if not public.es_sistema_o_admin() then raise exception 'Solo para administradores'; end if;
  return query
  select i.id, p.id, j1.apellido || ' / ' || j2.apellido,
         j1.nombre || ' ' || j1.apellido, j1.dni, j1.telefono, c1.nombre,
         j2.nombre || ' ' || j2.apellido, j2.dni, j2.telefono, c2.nombre,
         i.problemas_horario, i.estado, i.pagada, i.created_at, z.nombre
  from public.inscripciones i
  join public.parejas p on p.id = i.pareja_id
  join public.jugadores j1 on j1.id = p.jugador1_id join public.categorias c1 on c1.id = j1.categoria_id
  join public.jugadores j2 on j2.id = p.jugador2_id join public.categorias c2 on c2.id = j2.categoria_id
  left join public.zona_parejas zp on zp.inscripcion_id = i.id
  left join public.zonas z on z.id = zp.zona_id
  where i.torneo_categoria_id = p_torneo_categoria
  order by i.estado, i.created_at;
end $$;


--
-- Name: admin_kpis(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_kpis() RETURNS TABLE(jugadores integer, jugadores_activos integer, parejas integer, parejas_activas integer, torneos integer, torneos_finalizados integer)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select (select count(*)::int from public.jugadores),
         (select count(*)::int from public.jugadores where activo),
         (select count(*)::int from public.parejas),
         (select count(*)::int from public.parejas where activa),
         (select count(*)::int from public.torneos where estado <> 'borrador'),
         (select count(*)::int from public.torneos where estado = 'finalizado')
  where public.es_sistema_o_admin()
$$;


--
-- Name: admin_resetear_password(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_resetear_password(p_jugador uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
declare
  v_alfabeto constant text := 'abcdefghjkmnpqrstuvwxyz23456789';
  v_bytes bytea := extensions.gen_random_bytes(8);
  v_pass text := '';
  i int;
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador puede resetear contraseñas';
  end if;
  if p_jugador = auth.uid() then
    raise exception 'Tu propia contraseña cambiala desde Perfil';
  end if;
  if not exists (select 1 from public.jugadores where id = p_jugador) then
    raise exception 'Jugador inexistente';
  end if;

  for i in 0..7 loop
    v_pass := v_pass || substr(v_alfabeto, (get_byte(v_bytes, i) % length(v_alfabeto)) + 1, 1);
  end loop;

  update auth.users
     set encrypted_password = extensions.crypt(v_pass, extensions.gen_salt('bf')),
         updated_at = now()
   where id = p_jugador;

  delete from auth.sessions where user_id = p_jugador;  -- cierra sesiones abiertas (cascadea refresh tokens)

  update public.jugadores set debe_cambiar_password = true where id = p_jugador;
  perform public.registrar('jugador', 'Contraseña reseteada: ' ||
    (select nombre || ' ' || apellido || ' (' || dni || ')' from public.jugadores where id = p_jugador), p_jugador);
  return v_pass;
end $$;


--
-- Name: armar_cuadro(uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.armar_cuadro(p_torneo_categoria uuid, p_cruces jsonb DEFAULT NULL::jsonb) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_tc public.torneo_categorias;
  v_q int; v_b int := 2; v_rondas int;
  v_zon uuid[]; v_pos int[];
  v_seeds int[] := array[1]; v_nuevo int[];
  v_sz uuid[]; v_sp int[];
  v_tz uuid; v_tp int;
  v_id uuid; v_next uuid;
  v_ids jsonb := '{}'::jsonb;
  v_prog jsonb;
  e jsonb;
  r int; j int; k int; s int; n int;
begin
  if not public.es_sistema_o_admin() then raise exception 'Solo el administrador puede armar el playoff'; end if;
  perform set_config('app.sin_auditoria', 'on', true);

  select * into v_tc from public.torneo_categorias where id = p_torneo_categoria for update;
  if v_tc.estado not in ('zonas', 'playoff') then raise exception 'Primero hay que armar las zonas'; end if;
  if exists (select 1 from public.inscripciones i
             where i.torneo_categoria_id = p_torneo_categoria and i.estado = 'activa'
               and not exists (select 1 from public.zona_parejas zp where zp.inscripcion_id = i.id)) then
    raise exception 'Hay parejas inscriptas sin zona: ubicalas en el armado de zonas antes de armar el playoff';
  end if;
  if exists (select 1 from public.zonas z
             where z.torneo_categoria_id = p_torneo_categoria
               and ((select count(*) from public.zona_parejas zp where zp.zona_id = z.id) not between 3 and 4
                    or not exists (select 1 from public.partidos x where x.zona_id = z.id))) then
    raise exception 'Hay zonas incompletas (por una baja): rearmalas antes de armar el playoff';
  end if;
  if exists (select 1 from public.partidos
             where torneo_categoria_id = p_torneo_categoria and fase <> 'zona' and estado in ('finalizado', 'wo')) then
    raise exception 'El playoff ya tiene resultados cargados: no se puede rearmar';
  end if;

  -- Clasificados posibles (zona, posición), en orden de siembra
  select array_agg(z.id order by q.pos, z.nombre), array_agg(q.pos order by q.pos, z.nombre)
    into v_zon, v_pos
  from public.zonas z
  cross join lateral generate_series(1, case when (select count(*) from public.zona_parejas where zona_id = z.id) = 4 then 3 else 2 end) q(pos)
  where z.torneo_categoria_id = p_torneo_categoria;

  v_q := coalesce(array_length(v_zon, 1), 0);
  if v_q < 2 then raise exception 'No hay clasificados suficientes'; end if;
  while v_b < v_q loop v_b := v_b * 2; end loop;
  v_rondas := (log(2, v_b))::int;
  v_sz := array_fill(null::uuid, array[v_b]);
  v_sp := array_fill(null::int, array[v_b]);

  if p_cruces is null then
    while array_length(v_seeds, 1) < v_b loop
      n := array_length(v_seeds, 1);
      v_nuevo := '{}';
      foreach s in array v_seeds loop v_nuevo := v_nuevo || s || (2 * n + 1 - s); end loop;
      v_seeds := v_nuevo;
    end loop;
    for k in 1..v_b loop
      if v_seeds[k] <= v_q then v_sz[k] := v_zon[v_seeds[k]]; v_sp[k] := v_pos[v_seeds[k]]; end if;
    end loop;
    -- evitar cruces de la misma zona en primera ronda
    for j in 1..(v_b / 2) loop
      if v_sz[2*j-1] is not null and v_sz[2*j-1] = v_sz[2*j] then
        for k in 1..(v_b / 2) loop
          if k <> j and v_sz[2*k] is not null and v_sz[2*k] <> v_sz[2*j-1] and v_sz[2*j] is distinct from v_sz[2*k-1] then
            v_tz := v_sz[2*j]; v_sz[2*j] := v_sz[2*k]; v_sz[2*k] := v_tz;
            v_tp := v_sp[2*j]; v_sp[2*j] := v_sp[2*k]; v_sp[2*k] := v_tp;
            exit;
          end if;
        end loop;
      end if;
    end loop;
  else
    if jsonb_typeof(p_cruces) <> 'array' or jsonb_array_length(p_cruces) <> v_b / 2 then
      raise exception 'El cuadro tiene que tener % partidos de primera ronda', v_b / 2;
    end if;
    for j in 1..(v_b / 2) loop
      for k in 0..1 loop
        e := p_cruces -> (j - 1) -> k;
        if e is not null and jsonb_typeof(e) = 'object' then
          v_sz[2*j-1+k] := (e ->> 'zona')::uuid;
          v_sp[2*j-1+k] := (e ->> 'pos')::int;
        end if;
      end loop;
      if v_sz[2*j-1] is null and v_sz[2*j] is null then
        raise exception 'El partido % de primera ronda no tiene ninguna pareja', j;
      end if;
    end loop;
    -- cada clasificado exactamente una vez, y nada que no sea un clasificado
    if (select count(*) from unnest(v_sz, v_sp) t(z, p) where z is not null) <> v_q
       or (select count(distinct (z, p)) from unnest(v_sz, v_sp) t(z, p) where z is not null) <> v_q
       or exists (select 1 from unnest(v_sz, v_sp) t(z, p) where z is not null
                  and (z, p) not in (select * from unnest(v_zon, v_pos))) then
      raise exception 'Cada clasificado (1°, 2°, 3° de cada zona) tiene que aparecer una sola vez en el cuadro';
    end if;
  end if;

  -- guardar la programación actual (por fase y número de partido) para no perderla
  select coalesce(jsonb_agg(jsonb_build_object('f', fase, 'o', orden, 'sede', sede_id, 'cancha', cancha_id, 'fh', fecha_hora)), '[]')
    into v_prog
  from public.partidos where torneo_categoria_id = p_torneo_categoria and fase <> 'zona'
    and (sede_id is not null or fecha_hora is not null);

  delete from public.partidos where torneo_categoria_id = p_torneo_categoria and fase <> 'zona';

  for r in reverse v_rondas..1 loop
    n := v_b / (2 ^ r)::int;
    for j in 1..n loop
      v_next := null;
      if r < v_rondas then v_next := (v_ids ->> format('%s-%s', r + 1, (j + 1) / 2))::uuid; end if;
      insert into public.partidos (torneo_categoria_id, fase, ronda, orden, super_tiebreak,
                                   siguiente_partido_id, siguiente_slot,
                                   origen_a_zona_id, origen_a_pos, origen_b_zona_id, origen_b_pos)
      values (p_torneo_categoria, public.nombre_fase(v_b / (2 ^ (r - 1))::int), r, j, false,
              v_next, case when v_next is null then null when j % 2 = 1 then 'A' else 'B' end,
              case when r = 1 then v_sz[2*j-1] end, case when r = 1 then v_sp[2*j-1] end,
              case when r = 1 then v_sz[2*j] end,   case when r = 1 then v_sp[2*j] end)
      returning id into v_id;
      v_ids := v_ids || jsonb_build_object(format('%s-%s', r, j), v_id);
    end loop;
  end loop;

  perform set_config('app.interno', 'on', true);
  -- lados libres: el partido queda como "bye" y la pareja pasa directo cuando se conozca
  update public.partidos set estado = 'bye'
  where torneo_categoria_id = p_torneo_categoria and fase <> 'zona' and ronda = 1
    and (origen_a_zona_id is null or origen_b_zona_id is null);
  -- reponer sede/horario
  update public.partidos p set sede_id = (g ->> 'sede')::uuid, cancha_id = (g ->> 'cancha')::uuid, fecha_hora = (g ->> 'fh')::timestamptz
  from jsonb_array_elements(v_prog) g
  where p.torneo_categoria_id = p_torneo_categoria and p.fase::text = g ->> 'f' and p.orden = (g ->> 'o')::int and p.estado <> 'bye';
  perform set_config('app.interno', 'off', true);

  perform public.resolver_cuadro(p_torneo_categoria);
  perform public.registrar('zonas', 'Cuadro de playoff armado (' || case when p_cruces is null then 'automático' else 'a mano' end || '): ' ||
    public.aud_tc(p_torneo_categoria) || ' (' || v_q || ' clasificados)', p_torneo_categoria);
  perform set_config('app.sin_auditoria', 'off', true);
  return v_q;
end $$;


--
-- Name: armar_zonas_manual(uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.armar_zonas_manual(p_torneo_categoria uuid, p_zonas jsonb) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
declare
  v_tc public.torneo_categorias;
  v_letras text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  v_z int := jsonb_array_length(p_zonas);
  v_ids uuid[];
  v_zona uuid;
  v_prog jsonb;
  i int;
  s uuid[];
begin
  if not public.es_sistema_o_admin() then raise exception 'Solo el administrador puede armar zonas'; end if;
  perform set_config('app.sin_auditoria', 'on', true);

  select * into v_tc from public.torneo_categorias where id = p_torneo_categoria for update;
  if v_tc.id is null then raise exception 'Categoría de torneo inexistente'; end if;
  if v_tc.estado not in ('inscripcion', 'zonas') then
    raise exception 'La categoría ya está en playoff o finalizada';
  end if;
  if exists (select 1 from public.partidos where torneo_categoria_id = p_torneo_categoria and estado in ('finalizado', 'wo')) then
    raise exception 'Ya hay resultados cargados: no se pueden rearmar las zonas';
  end if;
  if v_z < 1 or v_z > 26 then raise exception 'Cantidad de zonas inválida'; end if;

  for i in 0..v_z - 1 loop
    if jsonb_array_length(p_zonas -> i) not between 3 and 4 then
      raise exception 'La zona % tiene % parejas: cada zona tiene que tener 3 o 4',
        substr(v_letras, i + 1, 1), jsonb_array_length(p_zonas -> i);
    end if;
  end loop;

  select array_agg(x::uuid) into v_ids
  from jsonb_array_elements(p_zonas) z, jsonb_array_elements_text(z) x;

  if (select count(distinct u) from unnest(v_ids) u) <> array_length(v_ids, 1) then
    raise exception 'Hay una pareja repetida en más de una zona';
  end if;
  if exists (select unnest(v_ids) except
             select id from public.inscripciones where torneo_categoria_id = p_torneo_categoria and estado = 'activa') then
    raise exception 'Hay parejas que no están inscriptas (o están canceladas) en esta categoría';
  end if;
  if exists (select id from public.inscripciones where torneo_categoria_id = p_torneo_categoria and estado = 'activa'
             except select unnest(v_ids)) then
    raise exception 'Faltan parejas inscriptas por ubicar en alguna zona';
  end if;

  -- guardar la programación actual por cruce (pareja_a, pareja_b) para no perderla
  select coalesce(jsonb_agg(jsonb_build_object('a', pareja_a_id, 'b', pareja_b_id, 'z', z.nombre, 'r', p.ronda, 'o', p.orden,
                                               'sede', sede_id, 'cancha', cancha_id, 'fh', fecha_hora)), '[]')
    into v_prog
  from public.partidos p join public.zonas z on z.id = p.zona_id
  where p.torneo_categoria_id = p_torneo_categoria and (p.sede_id is not null or p.fecha_hora is not null);

  delete from public.partidos where torneo_categoria_id = p_torneo_categoria;
  delete from public.zonas where torneo_categoria_id = p_torneo_categoria;

  for i in 0..v_z - 1 loop
    insert into public.zonas (torneo_categoria_id, nombre)
    values (p_torneo_categoria, substr(v_letras, i + 1, 1)) returning id into v_zona;
    select array_agg(x::uuid order by n) into s from jsonb_array_elements_text(p_zonas -> i) with ordinality t(x, n);
    insert into public.zona_parejas (zona_id, inscripcion_id, posicion_sorteo)
    select v_zona, u, n from unnest(s) with ordinality t(u, n);
    perform public.crear_partidos_zona(p_torneo_categoria, v_zona, s);
  end loop;

  -- reponer sede/horario: mismo cruce de parejas, o mismo partido de zona de 4 (ronda 2) en la misma zona
  update public.partidos p set sede_id = (g ->> 'sede')::uuid, cancha_id = (g ->> 'cancha')::uuid, fecha_hora = (g ->> 'fh')::timestamptz
  from jsonb_array_elements(v_prog) g, public.zonas z
  where p.torneo_categoria_id = p_torneo_categoria and z.id = p.zona_id
    and ((p.pareja_a_id is not null and least(p.pareja_a_id, p.pareja_b_id) = least((g ->> 'a')::uuid, (g ->> 'b')::uuid)
          and greatest(p.pareja_a_id, p.pareja_b_id) = greatest((g ->> 'a')::uuid, (g ->> 'b')::uuid))
      or (p.pareja_a_id is null and g ->> 'a' is null and z.nombre = g ->> 'z' and p.ronda = (g ->> 'r')::int and p.orden = (g ->> 'o')::int));

  update public.torneo_categorias set estado = 'zonas' where id = p_torneo_categoria;
  perform public.registrar('zonas', 'Zonas armadas: ' || public.aud_tc(p_torneo_categoria) || ' (' || v_z || ' zonas, ' ||
    jsonb_array_length(jsonb_path_query_array(p_zonas, '$[*][*]')) || ' parejas)', p_torneo_categoria);
  perform set_config('app.sin_auditoria', 'off', true);
  return v_z;
end $_$;


--
-- Name: asignar_slot(uuid, character, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.asignar_slot(p_partido uuid, p_slot character, p_inscripcion uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v public.partidos;
begin
  select * into v from public.partidos where id = p_partido;
  if v.id is null then return; end if;
  if (p_slot = 'A' and v.pareja_a_id is not distinct from p_inscripcion)
     or (p_slot = 'B' and v.pareja_b_id is not distinct from p_inscripcion) then
    return;
  end if;
  if v.estado in ('finalizado', 'wo') then
    raise exception 'El partido siguiente ya tiene resultado. Anulá primero ese resultado para poder modificar este';
  end if;
  if p_slot = 'A' then
    update public.partidos set pareja_a_id = p_inscripcion where id = p_partido;
  else
    update public.partidos set pareja_b_id = p_inscripcion where id = p_partido;
  end if;
end $$;


--
-- Name: aud_canchas(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aud_canchas() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare s text;
begin
  if public.auditoria_omitir() then return null; end if;
  select nombre into s from public.sedes where id = coalesce(new.sede_id, old.sede_id);
  if tg_op = 'INSERT' then perform public.registrar('sede', 'Cancha agregada en ' || s || ': ' || new.nombre, new.id);
  elsif tg_op = 'DELETE' then perform public.registrar('sede', 'Cancha eliminada en ' || s || ': ' || old.nombre, old.id);
  elsif new.nombre is distinct from old.nombre then perform public.registrar('sede', 'Cancha renombrada en ' || s || ': ' || old.nombre || ' → ' || new.nombre, new.id);
  elsif new.activa is distinct from old.activa then perform public.registrar('sede', 'Cancha ' || case when new.activa then 'activada' else 'desactivada' end || ' en ' || s || ': ' || new.nombre, new.id);
  end if;
  return null;
end $$;


--
-- Name: aud_categorias(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aud_categorias() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if public.auditoria_omitir() then return null; end if;
  if tg_op = 'INSERT' then perform public.registrar('config', 'Categoría creada: ' || new.nombre);
  elsif new.activa is distinct from old.activa then perform public.registrar('config', 'Categoría ' || case when new.activa then 'activada' else 'desactivada' end || ': ' || new.nombre);
  end if;
  return null;
end $$;


--
-- Name: aud_inscripcion(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aud_inscripcion(p uuid) RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select vp.nombre_corto from public.inscripciones i join public.v_parejas vp on vp.id = i.pareja_id where i.id = p
$$;


--
-- Name: aud_inscripciones(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aud_inscripciones() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if public.auditoria_omitir() then return null; end if;
  -- solo lo que hace el staff sobre parejas ajenas (lo que hace un jugador con su propia pareja no es "movimiento de admin")
  if tg_op = 'INSERT' then
    if not public.es_miembro_pareja(new.pareja_id) then
      perform public.registrar('inscripcion', 'Pareja inscripta: ' || public.aud_inscripcion(new.id) || ' en ' || public.aud_tc(new.torneo_categoria_id), new.id);
    end if;
  else
    if new.estado = 'cancelada' and old.estado = 'activa' and not public.es_miembro_pareja(new.pareja_id) then
      perform public.registrar('inscripcion', 'Inscripción cancelada: ' || public.aud_inscripcion(new.id) || ' en ' || public.aud_tc(new.torneo_categoria_id), new.id);
    end if;
    if new.pagada is distinct from old.pagada then
      perform public.registrar('inscripcion', 'Inscripción ' || case when new.pagada then 'marcada como pagada' else 'marcada como no pagada' end || ': ' ||
        public.aud_inscripcion(new.id) || ' en ' || public.aud_tc(new.torneo_categoria_id), new.id);
    end if;
    if new.problemas_horario is distinct from old.problemas_horario and not public.es_miembro_pareja(new.pareja_id) then
      perform public.registrar('inscripcion', 'Problemas de horario editados: ' || public.aud_inscripcion(new.id) || ' en ' || public.aud_tc(new.torneo_categoria_id), new.id);
    end if;
  end if;
  return null;
end $$;


--
-- Name: aud_jugadores(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aud_jugadores() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare quien text := new.nombre || ' ' || new.apellido || ' (' || new.dni || ')';
begin
  if public.auditoria_omitir() or new.id = auth.uid() and new.rol = old.rol and new.categoria_id = old.categoria_id then return null; end if;
  if new.categoria_id is distinct from old.categoria_id then
    perform public.registrar('jugador', 'Cambio de categoría: ' || quien || ' de ' ||
      (select nombre from public.categorias where id = old.categoria_id) || ' a ' || (select nombre from public.categorias where id = new.categoria_id), new.id);
  end if;
  if new.rol is distinct from old.rol then
    perform public.registrar('jugador', 'Cambio de rol: ' || quien || ' de ' || initcap(old.rol::text) || ' a ' || initcap(new.rol::text), new.id);
  end if;
  if new.activo is distinct from old.activo then
    perform public.registrar('jugador', 'Jugador ' || case when new.activo then 'activado' else 'desactivado' end || ': ' || quien, new.id);
  end if;
  if (new.nombre, new.apellido, new.telefono, new.email) is distinct from (old.nombre, old.apellido, old.telefono, old.email) and new.id <> auth.uid() then
    perform public.registrar('jugador', 'Datos editados: ' || quien, new.id);
  end if;
  return null;
end $$;


--
-- Name: aud_nombre_torneo(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aud_nombre_torneo(p uuid) RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select '"' || nombre || '"' from public.torneos where id = p
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: partidos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.partidos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    torneo_categoria_id uuid NOT NULL,
    fase public.fase_partido NOT NULL,
    zona_id uuid,
    ronda smallint DEFAULT 1 NOT NULL,
    orden smallint DEFAULT 1 NOT NULL,
    tipo_zona text,
    pareja_a_id uuid,
    pareja_b_id uuid,
    sede_id uuid,
    fecha_hora timestamp with time zone,
    super_tiebreak boolean DEFAULT false NOT NULL,
    s1_a smallint,
    s1_b smallint,
    s2_a smallint,
    s2_b smallint,
    s3_a smallint,
    s3_b smallint,
    ganador_id uuid,
    estado public.estado_partido DEFAULT 'pendiente'::public.estado_partido NOT NULL,
    siguiente_partido_id uuid,
    siguiente_slot character(1),
    cargado_por uuid,
    cargado_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    cancha_id uuid,
    origen_a_zona_id uuid,
    origen_a_pos smallint,
    origen_b_zona_id uuid,
    origen_b_pos smallint,
    CONSTRAINT partidos_parejas_distintas CHECK (((pareja_a_id IS NULL) OR (pareja_b_id IS NULL) OR (pareja_a_id <> pareja_b_id))),
    CONSTRAINT partidos_siguiente_slot_check CHECK ((siguiente_slot = ANY (ARRAY['A'::bpchar, 'B'::bpchar]))),
    CONSTRAINT partidos_tipo_zona_check CHECK ((tipo_zona = ANY (ARRAY['ganadores'::text, 'perdedores'::text]))),
    CONSTRAINT partidos_zona_coherente CHECK (((fase = 'zona'::public.fase_partido) = (zona_id IS NOT NULL)))
);


--
-- Name: aud_partido(public.partidos); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aud_partido(p public.partidos) RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select public.aud_tc(p.torneo_categoria_id) || ' · ' ||
         case when p.fase = 'zona' then 'Zona ' || coalesce((select nombre from public.zonas where id = p.zona_id), '?')
              else initcap(p.fase::text) end || ': ' ||
         coalesce(public.aud_inscripcion(p.pareja_a_id), 'A definir') || ' vs ' || coalesce(public.aud_inscripcion(p.pareja_b_id), 'A definir')
$$;


--
-- Name: aud_partidos(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aud_partidos() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  res text;
  g text;
begin
  if public.auditoria_omitir() then return null; end if;
  g := coalesce(public.aud_inscripcion(new.ganador_id), '?');
  res := case new.estado
    when 'wo' then 'W.O. a favor de ' || g
    else concat_ws(' ', new.s1_a || '-' || new.s1_b, new.s2_a || '-' || new.s2_b, new.s3_a || '-' || new.s3_b) || ' (gana ' || g || ')' end;
  if new.estado in ('finalizado', 'wo') and old.estado = 'pendiente' then
    perform public.registrar('resultado', 'Resultado cargado: ' || public.aud_partido(new) || ' → ' || res, new.id);
  elsif new.estado in ('finalizado', 'wo') and (new.estado, new.s1_a, new.s1_b, new.s2_a, new.s2_b, new.s3_a, new.s3_b, new.ganador_id)
        is distinct from (old.estado, old.s1_a, old.s1_b, old.s2_a, old.s2_b, old.s3_a, old.s3_b, old.ganador_id) then
    perform public.registrar('resultado', 'Resultado editado: ' || public.aud_partido(new) || ' → ' || res, new.id);
  elsif new.estado = 'pendiente' and old.estado in ('finalizado', 'wo') then
    perform public.registrar('resultado', 'Resultado anulado: ' || public.aud_partido(new), new.id);
  end if;
  if (new.sede_id, new.cancha_id, new.fecha_hora) is distinct from (old.sede_id, old.cancha_id, old.fecha_hora) then
    perform public.registrar('programacion', 'Partido programado: ' || public.aud_partido(new) || ' → ' ||
      coalesce((select nombre from public.sedes where id = new.sede_id), 'sin sede') ||
      coalesce(' · ' || (select nombre from public.canchas where id = new.cancha_id), '') ||
      coalesce(' · ' || to_char(new.fecha_hora at time zone 'America/Argentina/Buenos_Aires', 'DD/MM HH24:MI'), ' · sin horario'), new.id);
  end if;
  return null;
end $$;


--
-- Name: aud_sedes(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aud_sedes() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if public.auditoria_omitir() then return null; end if;
  if tg_op = 'INSERT' then perform public.registrar('sede', 'Sede creada: ' || new.nombre, new.id);
  elsif new.activa is distinct from old.activa then perform public.registrar('sede', 'Sede ' || case when new.activa then 'activada' else 'desactivada' end || ': ' || new.nombre, new.id);
  elsif (new.nombre, new.direccion) is distinct from (old.nombre, old.direccion) then perform public.registrar('sede', 'Sede editada: ' || new.nombre, new.id);
  end if;
  return null;
end $$;


--
-- Name: aud_tc(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aud_tc(p uuid) RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select '"' || t.nombre || '" · ' || c.nombre
  from public.torneo_categorias tc join public.torneos t on t.id = tc.torneo_id join public.categorias c on c.id = tc.categoria_id
  where tc.id = p
$$;


--
-- Name: aud_torneo_categorias(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aud_torneo_categorias() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if public.auditoria_omitir() then return null; end if;
  if tg_op = 'INSERT' then
    perform public.registrar('categoria', 'Categoría agregada al torneo ' || public.aud_nombre_torneo(new.torneo_id) || ': ' ||
      (select nombre from public.categorias where id = new.categoria_id), new.id);
  elsif tg_op = 'DELETE' then
    perform public.registrar('categoria', 'Categoría quitada del torneo ' || coalesce(public.aud_nombre_torneo(old.torneo_id), '(eliminado)') || ': ' ||
      (select nombre from public.categorias where id = old.categoria_id), old.id);
  else
    if new.estado is distinct from old.estado and (new.estado in ('suspendida', 'inscripcion') or old.estado = 'suspendida') then
      perform public.registrar('categoria', public.aud_tc(new.id) || ': ' ||
        case new.estado when 'suspendida' then 'suspendida' when 'inscripcion' then 'reabierta a inscripción' else 'reactivada' end, new.id);
    end if;
    if (new.cupo_max, new.cupo_min) is distinct from (old.cupo_max, old.cupo_min) then
      perform public.registrar('categoria', public.aud_tc(new.id) || ': cupo ' || new.cupo_min || ' a ' || new.cupo_max || ' parejas', new.id);
    end if;
  end if;
  return null;
end $$;


--
-- Name: aud_torneos(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.aud_torneos() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare cambios text[] := '{}';
begin
  if public.auditoria_omitir() then return null; end if;
  if tg_op = 'INSERT' then
    perform public.registrar('torneo', 'Torneo creado: "' || new.nombre || '" (' || new.estado || ')', new.id);
  elsif tg_op = 'DELETE' then
    perform public.registrar('torneo', 'Torneo eliminado: "' || old.nombre || '"', old.id);
  else
    if new.estado is distinct from old.estado then
      perform public.registrar('torneo', 'Torneo "' || new.nombre || '": ' || case new.estado
        when 'publicado' then 'publicado (inscripción abierta)'
        when 'en_curso' then 'en curso'
        when 'finalizado' then 'finalizado'
        when 'cancelado' then 'cancelado'
        else 'pasado a borrador' end, new.id);
    end if;
    if new.nombre is distinct from old.nombre then cambios := cambios || ('nombre (antes "' || old.nombre || '")'); end if;
    if (new.fecha_desde, new.fecha_hasta) is distinct from (old.fecha_desde, old.fecha_hasta) then cambios := cambios || 'fechas'::text; end if;
    if new.cierre_inscripcion is distinct from old.cierre_inscripcion then
      cambios := cambios || ('cierre de inscripción a ' || to_char(new.cierre_inscripcion at time zone 'America/Argentina/Buenos_Aires', 'DD/MM/YYYY HH24:MI'));
    end if;
    if (new.descripcion, new.observaciones) is distinct from (old.descripcion, old.observaciones) then cambios := cambios || 'descripción/observaciones'::text; end if;
    if new.precio_inscripcion is distinct from old.precio_inscripcion then cambios := cambios || 'precio'::text; end if;
    if (new.americano, new.games_set_unico) is distinct from (old.americano, old.games_set_unico) then cambios := cambios || 'formato de partido'::text; end if;
    if array_length(cambios, 1) > 0 then
      perform public.registrar('torneo', 'Torneo "' || new.nombre || '" editado: ' || array_to_string(cambios, ', '), new.id);
    end if;
  end if;
  return null;
end $$;


--
-- Name: auditoria_omitir(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.auditoria_omitir() RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  select pg_trigger_depth() > 1 or coalesce(current_setting('app.sin_auditoria', true), '') = 'on'
$$;


--
-- Name: auditoria_usuarios(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.auditoria_usuarios() RETURNS TABLE(usuario_id uuid, usuario text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select distinct on (a.usuario_id) a.usuario_id, a.usuario
  from public.auditoria a where public.es_admin() and a.usuario_id is not null
  order by a.usuario_id, a.created_at desc
$$;


--
-- Name: buscar_jugador_por_dni(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.buscar_jugador_por_dni(p_dni text) RETURNS TABLE(id uuid, nombre text, apellido text, categoria_id smallint, categoria text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select j.id, j.nombre, j.apellido, j.categoria_id, c.nombre
  from public.jugadores j join public.categorias c on c.id = j.categoria_id
  where j.dni = trim(p_dni) and j.activo
$$;


--
-- Name: categorias_habilitadas_pareja(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.categorias_habilitadas_pareja(p_pareja uuid) RETURNS SETOF smallint
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select c.id from public.categorias c where c.activa and public.pareja_puede_jugar(p_pareja, c.id) order by c.orden
$$;


--
-- Name: clasificado_zona(uuid, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clasificado_zona(p_zona uuid, p_pos smallint) RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select case
    when p_zona is null then null
    when not exists (select 1 from public.partidos where zona_id = p_zona)
      or exists (select 1 from public.partidos where zona_id = p_zona and estado = 'pendiente') then null
    else (select pz.inscripcion_id from public.posiciones_zona(p_zona) pz where pz.posicion = p_pos)
  end
$$;


--
-- Name: crear_pareja(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crear_pareja(p_dni_companero text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_yo uuid := auth.uid();
  v_otro uuid;
  v_id uuid;
begin
  if v_yo is null then raise exception 'Tenés que iniciar sesión'; end if;

  select id into v_otro from public.jugadores where dni = trim(p_dni_companero) and activo;
  if v_otro is null then
    raise exception 'No existe un jugador registrado con DNI %', trim(p_dni_companero);
  end if;
  if v_otro = v_yo then
    raise exception 'No podés armar una pareja con vos mismo';
  end if;

  select id into v_id from public.parejas
  where jugador1_id = least(v_yo, v_otro) and jugador2_id = greatest(v_yo, v_otro);

  if v_id is not null then
    update public.parejas set activa = true where id = v_id;
    return v_id;
  end if;

  insert into public.parejas (jugador1_id, jugador2_id, creada_por)
  values (least(v_yo, v_otro), greatest(v_yo, v_otro), v_yo)
  returning id into v_id;
  return v_id;
end $$;


--
-- Name: crear_partidos_zona(uuid, uuid, uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crear_partidos_zona(p_tc uuid, p_zona uuid, p_parejas uuid[]) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare s uuid[] := p_parejas;
begin
  if not public.es_sistema_o_admin() then raise exception 'Solo el administrador puede armar zonas'; end if;
  if array_length(s, 1) = 3 then
    insert into public.partidos (torneo_categoria_id, fase, zona_id, ronda, orden, pareja_a_id, pareja_b_id, super_tiebreak) values
      (p_tc, 'zona', p_zona, 1, 1, s[1], s[2], true),
      (p_tc, 'zona', p_zona, 2, 1, s[1], s[3], true),
      (p_tc, 'zona', p_zona, 3, 1, s[2], s[3], true);
  else
    insert into public.partidos (torneo_categoria_id, fase, zona_id, ronda, orden, tipo_zona, pareja_a_id, pareja_b_id, super_tiebreak) values
      (p_tc, 'zona', p_zona, 1, 1, null,         s[1], s[4], true),
      (p_tc, 'zona', p_zona, 1, 2, null,         s[2], s[3], true),
      (p_tc, 'zona', p_zona, 2, 1, 'ganadores',  null, null, true),
      (p_tc, 'zona', p_zona, 2, 2, 'perdedores', null, null, true);
  end if;
end $$;


--
-- Name: dni_disponible(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dni_disponible(p_dni text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select not exists (select 1 from public.jugadores where dni = trim(p_dni))
$$;


--
-- Name: es_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.es_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select coalesce((select rol = 'administrador' from public.jugadores where id = auth.uid()), false)
$$;


--
-- Name: es_editor_o_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.es_editor_o_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select coalesce((select rol in ('editor', 'administrador') from public.jugadores where id = auth.uid()), false)
$$;


--
-- Name: es_miembro_inscripcion(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.es_miembro_inscripcion(p_inscripcion uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from public.inscripciones i
    join public.parejas p on p.id = i.pareja_id
    where i.id = p_inscripcion and auth.uid() in (p.jugador1_id, p.jugador2_id)
  )
$$;


--
-- Name: es_miembro_pareja(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.es_miembro_pareja(p_pareja uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from public.parejas
    where id = p_pareja and auth.uid() in (jugador1_id, jugador2_id)
  )
$$;


--
-- Name: es_sistema_o_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.es_sistema_o_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select auth.uid() is null or public.es_admin()
$$;


--
-- Name: generar_playoff(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generar_playoff(p_torneo_categoria uuid) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if not public.es_sistema_o_admin() then raise exception 'Solo el administrador puede armar el playoff'; end if;
  if exists (select 1 from public.partidos
             where torneo_categoria_id = p_torneo_categoria and fase = 'zona' and estado = 'pendiente') then
    raise exception 'Faltan resultados de zona: completalos antes de armar el playoff (o armá el cuadro de antemano)';
  end if;
  return public.armar_cuadro(p_torneo_categoria, null);
end $$;


--
-- Name: generar_zonas(uuid, integer, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generar_zonas(p_torneo_categoria uuid, p_cantidad_zonas integer DEFAULT NULL::integer, p_aleatorio boolean DEFAULT true) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_tc public.torneo_categorias;
  v_n int;
  v_z int;
  v_de4 int;
  v_ins uuid[];
  v_idx int := 1;
  v_tam int;
  v_zona uuid;
  v_letras text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  i int;
  k int;
  s uuid[];
begin
  if not public.es_sistema_o_admin() then raise exception 'Solo el administrador puede armar zonas'; end if;
  perform set_config('app.sin_auditoria', 'on', true);

  select * into v_tc from public.torneo_categorias where id = p_torneo_categoria for update;
  if v_tc.id is null then raise exception 'Categoría de torneo inexistente'; end if;
  if v_tc.estado not in ('inscripcion', 'zonas') then
    raise exception 'La categoría ya está en playoff o finalizada';
  end if;
  if exists (select 1 from public.partidos where torneo_categoria_id = p_torneo_categoria and estado in ('finalizado', 'wo')) then
    raise exception 'Ya hay resultados cargados: no se pueden regenerar las zonas';
  end if;

  select array_agg(id order by case when p_aleatorio then random() else 0 end, created_at)
    into v_ins
  from public.inscripciones
  where torneo_categoria_id = p_torneo_categoria and estado = 'activa';

  v_n := coalesce(array_length(v_ins, 1), 0);
  if v_n < v_tc.cupo_min then
    raise exception 'Hay % parejas inscriptas y el mínimo para armar la categoría es %', v_n, v_tc.cupo_min;
  end if;

  v_z := coalesce(p_cantidad_zonas, v_n / 3);
  if v_z * 3 > v_n or v_z * 4 < v_n then
    raise exception 'Con % parejas se pueden armar entre % y % zonas', v_n, ceil(v_n / 4.0)::int, v_n / 3;
  end if;
  v_de4 := v_n - 3 * v_z;

  delete from public.partidos where torneo_categoria_id = p_torneo_categoria;
  delete from public.zonas where torneo_categoria_id = p_torneo_categoria;

  for i in 1..v_z loop
    v_tam := case when i <= v_de4 then 4 else 3 end;
    insert into public.zonas (torneo_categoria_id, nombre)
    values (p_torneo_categoria, substr(v_letras, i, 1))
    returning id into v_zona;

    s := v_ins[v_idx : v_idx + v_tam - 1];
    for k in 1..v_tam loop
      insert into public.zona_parejas (zona_id, inscripcion_id, posicion_sorteo) values (v_zona, s[k], k);
    end loop;
    v_idx := v_idx + v_tam;

    perform public.crear_partidos_zona(p_torneo_categoria, v_zona, s);
  end loop;

  update public.torneo_categorias set estado = 'zonas' where id = p_torneo_categoria;
  perform public.registrar('zonas', 'Zonas generadas automáticamente: ' || public.aud_tc(p_torneo_categoria) || ' (' || v_z || ' zonas)', p_torneo_categoria);
  perform set_config('app.sin_auditoria', 'off', true);
  return v_z;
end $$;


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  m jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  if m ->> 'dni' is null then
    return new;   -- usuarios creados a mano desde el dashboard: sin perfil
  end if;

  insert into public.jugadores (id, dni, nombre, apellido, telefono, email, categoria_id)
  values (
    new.id,
    trim(m ->> 'dni'),
    trim(m ->> 'nombre'),
    trim(m ->> 'apellido'),
    trim(m ->> 'telefono'),
    nullif(trim(coalesce(m ->> 'email', '')), ''),
    (m ->> 'categoria_id')::smallint
  );

  insert into public.jugador_categoria_historial (jugador_id, categoria_anterior_id, categoria_nueva_id, cambiado_por)
  values (new.id, null, (m ->> 'categoria_id')::smallint, new.id);

  return new;
end $$;


--
-- Name: inscripciones_no_elegibles(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inscripciones_no_elegibles(p_jugador uuid) RETURNS TABLE(inscripcion_id uuid, torneo text, categoria text, pareja text, en_zona boolean)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select i.id, t.nombre, c.nombre, vp.nombre_corto,
         exists (select 1 from public.zona_parejas zp where zp.inscripcion_id = i.id)
  from public.inscripciones i
  join public.parejas p on p.id = i.pareja_id
  join public.v_parejas vp on vp.id = p.id
  join public.torneo_categorias tc on tc.id = i.torneo_categoria_id
  join public.torneos t on t.id = tc.torneo_id
  join public.categorias c on c.id = tc.categoria_id
  where public.es_sistema_o_admin()
    and p_jugador in (p.jugador1_id, p.jugador2_id)
    and i.estado = 'activa'
    and tc.estado in ('inscripcion', 'zonas')
    and not exists (select 1 from public.partidos x where x.torneo_categoria_id = tc.id and x.estado in ('finalizado', 'wo'))
    and not public.pareja_puede_jugar(p.id, tc.categoria_id)
  order by t.fecha_desde
$$;


--
-- Name: inscripciones_validar(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inscripciones_validar() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_tc public.torneo_categorias;
  v_t  public.torneos;
  v_p  public.parejas;
  v_cant int;
  v_admin boolean := public.es_sistema_o_admin();
begin
  select * into v_tc from public.torneo_categorias where id = new.torneo_categoria_id for update;
  select * into v_t  from public.torneos where id = v_tc.torneo_id;

  if tg_op = 'INSERT' then
    select * into v_p from public.parejas where id = new.pareja_id;

    if not v_admin then
      if v_t.estado <> 'publicado' then
        raise exception 'El torneo no tiene la inscripción abierta';
      end if;
      if now() >= v_t.cierre_inscripcion then
        raise exception 'La inscripción de este torneo ya cerró';
      end if;
      if not public.es_miembro_pareja(new.pareja_id) then
        raise exception 'Solo podés inscribir parejas que integrás';
      end if;
    end if;

    -- El admin puede sumar parejas hasta que se cargue el primer resultado, aunque ya haya zonas
    -- (la pareja queda "sin zona" y hay que ubicarla desde el armado de zonas).
    if v_tc.estado <> 'inscripcion' and not (
         v_admin and v_tc.estado = 'zonas' and not exists (
           select 1 from public.partidos where torneo_categoria_id = v_tc.id and estado in ('finalizado', 'wo'))) then
      raise exception 'Esta categoría ya no acepta inscripciones';
    end if;
    if not v_p.activa then
      raise exception 'La pareja no está activa';
    end if;
    if not public.pareja_puede_jugar(new.pareja_id, v_tc.categoria_id) then
      raise exception 'La pareja no puede inscribirse en %: %',
        (select nombre from public.categorias where id = v_tc.categoria_id),
        (select case when tipo = 'nivel'
                  then 'por categoría solo puede jugar en la de su mejor jugador o superiores'
                  when genero = 'mixto' then 'tiene que ser una dama y un caballero, y la suma de sus categorías llegar a ' || suma
                  when genero = 'damas' then 'tienen que ser dos damas y la suma de sus categorías llegar a ' || suma
                  else 'la suma de sus categorías tiene que llegar a ' || suma || ' (una dama suma 2 categorías más)'
                end from public.categorias where id = v_tc.categoria_id);
    end if;

    select count(*) into v_cant from public.inscripciones
    where torneo_categoria_id = new.torneo_categoria_id and estado = 'activa';
    if v_cant >= v_tc.cupo_max then
      raise exception 'La categoría alcanzó el cupo máximo de % parejas', v_tc.cupo_max;
    end if;

    if exists (
      select 1 from public.inscripciones i
      join public.parejas p on p.id = i.pareja_id
      where i.torneo_categoria_id = new.torneo_categoria_id and i.estado = 'activa'
        and (p.jugador1_id in (v_p.jugador1_id, v_p.jugador2_id) or p.jugador2_id in (v_p.jugador1_id, v_p.jugador2_id))
    ) then
      raise exception 'Uno de los jugadores ya está inscripto en esta categoría con otra pareja';
    end if;

    new.estado := 'activa';
    new.inscripta_por := coalesce(new.inscripta_por, auth.uid());
    if not v_admin then new.pagada := false; end if;
    return new;
  end if;

  -- UPDATE
  if new.torneo_categoria_id is distinct from old.torneo_categoria_id or new.pareja_id is distinct from old.pareja_id then
    raise exception 'No se puede cambiar la categoría ni la pareja de una inscripción; cancelala y creá una nueva';
  end if;

  if not v_admin then
    if new.pagada is distinct from old.pagada then
      raise exception 'Solo el administrador registra pagos';
    end if;
    if old.estado = 'cancelada' and new.estado = 'activa' then
      raise exception 'Una inscripción cancelada no se puede reactivar; volvé a inscribirte';
    end if;
    if v_tc.estado <> 'inscripcion' then
      raise exception 'La categoría ya está en juego (zonas armadas): la inscripción no se puede modificar ni cancelar';
    end if;
    if now() >= v_t.cierre_inscripcion then
      raise exception 'La inscripción cerró el %: ya no podés modificarla ni cancelarla. Si no se presentan, la inscripción se cobra igual',
        to_char(v_t.cierre_inscripcion at time zone 'America/Argentina/Buenos_Aires', 'DD/MM/YYYY HH24:MI');
    end if;
  end if;

  if new.estado = 'cancelada' and old.estado = 'activa' then
    if exists (select 1 from public.zona_parejas where inscripcion_id = new.id) then
      -- El admin puede dar de baja una pareja ya ubicada mientras no haya resultados:
      -- su zona queda incompleta (sin partidos) hasta que se rearme desde el armado de zonas.
      if v_admin and not exists (select 1 from public.partidos
                                 where torneo_categoria_id = v_tc.id and estado in ('finalizado', 'wo')) then
        perform set_config('app.interno', 'on', true);
        delete from public.partidos where zona_id in (select zona_id from public.zona_parejas where inscripcion_id = new.id);
        delete from public.zona_parejas where inscripcion_id = new.id;
        perform set_config('app.interno', 'off', true);
      else
        raise exception 'La pareja ya juega en una zona con resultados cargados: no se puede cancelar';
      end if;
    end if;
    new.cancelada_at := now();
  end if;
  return new;
end $$;


--
-- Name: intercambiar_parejas_zona(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.intercambiar_parejas_zona(p_ins1 uuid, p_ins2 uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  z1 public.zona_parejas;
  z2 public.zona_parejas;
begin
  if not public.es_sistema_o_admin() then raise exception 'Solo el administrador puede mover parejas'; end if;
  perform set_config('app.sin_auditoria', 'on', true);
  select * into z1 from public.zona_parejas where inscripcion_id = p_ins1;
  select * into z2 from public.zona_parejas where inscripcion_id = p_ins2;
  if z1.zona_id is null or z2.zona_id is null then raise exception 'Ambas parejas deben estar asignadas a una zona'; end if;
  if z1.zona_id = z2.zona_id then raise exception 'Las parejas ya están en la misma zona'; end if;
  if exists (select 1 from public.partidos where zona_id in (z1.zona_id, z2.zona_id) and estado in ('finalizado', 'wo')) then
    raise exception 'Alguna de las zonas ya tiene resultados cargados';
  end if;

  delete from public.zona_parejas where inscripcion_id in (p_ins1, p_ins2);
  insert into public.zona_parejas (zona_id, inscripcion_id, posicion_sorteo) values
    (z2.zona_id, p_ins1, z2.posicion_sorteo),
    (z1.zona_id, p_ins2, z1.posicion_sorteo);

  update public.partidos set
    pareja_a_id = case pareja_a_id when p_ins1 then p_ins2 when p_ins2 then p_ins1 else pareja_a_id end,
    pareja_b_id = case pareja_b_id when p_ins1 then p_ins2 when p_ins2 then p_ins1 else pareja_b_id end
  where zona_id in (z1.zona_id, z2.zona_id);
  perform public.registrar('zonas', 'Parejas intercambiadas entre zonas: ' || coalesce(public.aud_inscripcion(p_ins1), '?') || ' ↔ ' || coalesce(public.aud_inscripcion(p_ins2), '?'));
  perform set_config('app.sin_auditoria', 'off', true);
end $$;


--
-- Name: jugadores_proteger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.jugadores_proteger() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if not public.es_sistema_o_admin() then
    if new.categoria_id is distinct from old.categoria_id then
      raise exception 'Solo el administrador puede cambiar la categoría de un jugador';
    end if;
    if new.rol is distinct from old.rol then
      raise exception 'Solo el administrador puede cambiar roles';
    end if;
    if new.dni is distinct from old.dni then
      raise exception 'El DNI no se puede modificar';
    end if;
    if new.activo is distinct from old.activo then
      raise exception 'Solo el administrador puede activar o desactivar jugadores';
    end if;
    if new.debe_cambiar_password and not old.debe_cambiar_password then
      raise exception 'Solo el administrador puede resetear contraseñas';
    end if;
  end if;

  if new.categoria_id is distinct from old.categoria_id then
    insert into public.jugador_categoria_historial (jugador_id, categoria_anterior_id, categoria_nueva_id, cambiado_por)
    values (new.id, old.categoria_id, new.categoria_id, auth.uid());
  end if;
  return new;
end $$;


--
-- Name: jugadores_validar_categoria(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.jugadores_validar_categoria() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  if (select tipo from public.categorias where id = new.categoria_id) is distinct from 'nivel' then
    raise exception 'La categoría de un jugador tiene que ser de nivel (3ra a 7ma)';
  end if;
  return new;
end $$;


--
-- Name: marcar_password_cambiada(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.marcar_password_cambiada() RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  update public.jugadores set debe_cambiar_password = false where id = auth.uid()
$$;


--
-- Name: mi_rol(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mi_rol() RETURNS public.rol_usuario
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select rol from public.jugadores where id = auth.uid()
$$;


--
-- Name: mis_inscripciones(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mis_inscripciones() RETURNS TABLE(id uuid, torneo_id uuid, torneo text, fecha_desde date, fecha_hasta date, cierre_inscripcion timestamp with time zone, estado_torneo public.estado_torneo, torneo_categoria_id uuid, categoria text, estado_categoria public.estado_torneo_categoria, pareja_id uuid, pareja text, companero text, problemas_horario text, estado public.estado_inscripcion, pagada boolean, created_at timestamp with time zone, puede_editar boolean)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select i.id, t.id, t.nombre, t.fecha_desde, t.fecha_hasta, t.cierre_inscripcion,
         t.estado, tc.id, c.nombre, tc.estado,
         vp.id, vp.jugador1 || ' / ' || vp.jugador2,
         case when vp.jugador1_id = auth.uid() then vp.jugador2 else vp.jugador1 end,
         i.problemas_horario, i.estado, i.pagada, i.created_at,
         (i.estado = 'activa' and now() < t.cierre_inscripcion and tc.estado = 'inscripcion')
  from public.inscripciones i
  join public.torneo_categorias tc on tc.id = i.torneo_categoria_id
  join public.torneos t on t.id = tc.torneo_id
  join public.categorias c on c.id = tc.categoria_id
  join public.v_parejas vp on vp.id = i.pareja_id
  where auth.uid() in (vp.jugador1_id, vp.jugador2_id)
  order by t.fecha_desde desc, c.orden
$$;


--
-- Name: nivel_efectivo(smallint, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.nivel_efectivo(p_cat_jugador smallint, p_cat_torneo smallint) RETURNS smallint
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'public'
    AS $$
  select case
           when t.genero = 'damas' and j.genero = 'caballeros' then null   -- no habilitado
           when t.genero = 'caballeros' and j.genero = 'damas' then (j.nivel + 2)::smallint
           else j.nivel
         end
  from public.categorias j, public.categorias t
  where j.id = p_cat_jugador and t.id = p_cat_torneo
$$;


--
-- Name: nombre_fase(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.nombre_fase(p_tamano integer) RETURNS public.fase_partido
    LANGUAGE sql IMMUTABLE
    AS $$
  select case p_tamano
    when 2 then 'final'::public.fase_partido
    when 4 then 'semifinal'
    when 8 then 'cuartos'
    when 16 then 'octavos'
    else 'dieciseisavos' end
$$;


--
-- Name: pareja_puede_jugar(uuid, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pareja_puede_jugar(p_pareja uuid, p_categoria smallint) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  with t as (select * from public.categorias where id = p_categoria),
  js as (
    select public.nivel_efectivo(j.categoria_id, p_categoria) as n, cj.genero
    from public.parejas p
    join public.jugadores j on j.id in (p.jugador1_id, p.jugador2_id)
    join public.categorias cj on cj.id = j.categoria_id
    where p.id = p_pareja
  )
  select coalesce((
    select count(*) = 2 and bool_and(js.n is not null)
           and case when t.tipo = 'nivel' then t.nivel <= min(js.n)
                    else sum(js.n) >= t.suma
                         and (t.genero <> 'mixto' or count(distinct js.genero) = 2)
               end
    from js, t
    group by t.tipo, t.nivel, t.suma, t.genero
  ), false)
$$;


--
-- Name: parejas_proteger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.parejas_proteger() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if new.jugador1_id is distinct from old.jugador1_id or new.jugador2_id is distinct from old.jugador2_id then
    raise exception 'No se pueden cambiar los integrantes de una pareja; creá una nueva';
  end if;
  if old.activa and not new.activa and exists (
      select 1 from public.inscripciones i
      join public.torneo_categorias tc on tc.id = i.torneo_categoria_id
      where i.pareja_id = new.id and i.estado = 'activa'
        and tc.estado not in ('finalizada', 'suspendida')) then
    raise exception 'La pareja tiene inscripciones vigentes. Cancelalas antes de darla de baja';
  end if;
  return new;
end $$;


--
-- Name: participaciones(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.participaciones(p_jugador uuid DEFAULT NULL::uuid) RETURNS TABLE(jugador_id uuid, dni text, nombre text, apellido text, companero text, pareja_id uuid, inscripcion_id uuid, torneo_id uuid, torneo text, fecha_desde date, americano boolean, categoria_id smallint, categoria text, categoria_orden smallint, instancia text, instancia_orden integer, en_curso boolean)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
#variable_conflict use_column
begin
  if p_jugador is distinct from auth.uid() and not public.es_sistema_o_admin() then
    raise exception 'Solo el administrador puede ver las estadísticas de otros jugadores';
  end if;

  return query
  with ins as (
    select i.id as ins_id, tc.id as tc_id, tc.estado as tc_estado, t.id as t_id, t.nombre as t_nombre,
           t.fecha_desde as t_desde, t.americano as t_amer, c.id as c_id, c.nombre as c_nombre, c.orden as c_orden,
           p.id as par_id, p.jugador1_id as j1, p.jugador2_id as j2
    from public.inscripciones i
    join public.torneo_categorias tc on tc.id = i.torneo_categoria_id
    join public.torneos t on t.id = tc.torneo_id
    join public.categorias c on c.id = tc.categoria_id
    join public.parejas p on p.id = i.pareja_id
    where i.estado = 'activa' and tc.estado in ('zonas', 'playoff', 'finalizada') and t.estado <> 'cancelado'
      and (p_jugador is null or p_jugador in (p.jugador1_id, p.jugador2_id))
  ),
  inst as (
    select ins.*,
      (select case when f.estado in ('finalizado', 'wo') and f.ganador_id = ins.ins_id then 1
                   when f.estado in ('finalizado', 'wo') then 2 else 3 end
       from public.partidos f
       where f.torneo_categoria_id = ins.tc_id and f.fase = 'final' and ins.ins_id in (f.pareja_a_id, f.pareja_b_id)
       limit 1) as fin,
      (select min(array_position(array['semifinal', 'cuartos', 'octavos', 'dieciseisavos']::public.fase_partido[], x.fase))
       from public.partidos x
       where x.torneo_categoria_id = ins.tc_id and x.fase in ('semifinal', 'cuartos', 'octavos', 'dieciseisavos')
         and ins.ins_id in (x.pareja_a_id, x.pareja_b_id)) as po
    from ins
  )
  select j.id, j.dni, j.nombre, j.apellido, o.nombre || ' ' || o.apellido,
         inst.par_id, inst.ins_id, inst.t_id, inst.t_nombre, inst.t_desde, inst.t_amer,
         inst.c_id, inst.c_nombre, inst.c_orden,
         case coalesce(inst.fin, inst.po + 3, 8)
           when 1 then 'campeon' when 2 then 'subcampeon' when 3 then 'final' when 4 then 'semifinal'
           when 5 then 'cuartos' when 6 then 'octavos' when 7 then 'dieciseisavos' else 'zona' end,
         coalesce(inst.fin, inst.po + 3, 8),
         inst.tc_estado <> 'finalizada'
  from inst
  join public.jugadores j on j.id in (inst.j1, inst.j2)
  join public.jugadores o on o.id in (inst.j1, inst.j2) and o.id <> j.id
  where p_jugador is null or j.id = p_jugador;
end $$;


--
-- Name: partidos_cancha_de_sede(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.partidos_cancha_de_sede() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  if new.cancha_id is not null and
     (select sede_id from public.canchas where id = new.cancha_id) is distinct from new.sede_id then
    raise exception 'La cancha elegida no pertenece a ese complejo';
  end if;
  return new;
end $$;


--
-- Name: partidos_propagar(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.partidos_propagar() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_perdedor uuid;
  v_slot char(1);
  v_gan uuid;
  v_per uuid;
begin
  if new.ganador_id is not distinct from old.ganador_id
     and new.pareja_a_id is not distinct from old.pareja_a_id
     and new.pareja_b_id is not distinct from old.pareja_b_id then
    return new;
  end if;

  v_perdedor := case
    when new.ganador_id is null then null
    when new.ganador_id = new.pareja_a_id then new.pareja_b_id
    else new.pareja_a_id end;

  -- Zona de 4: ronda 1 alimenta "ganadores" y "perdedores"
  if new.fase = 'zona' and new.ronda = 1 and new.tipo_zona is null
     and (select count(*) from public.zona_parejas where zona_id = new.zona_id) = 4 then
    v_slot := case when new.orden = 1 then 'A' else 'B' end;
    select id into v_gan from public.partidos where zona_id = new.zona_id and tipo_zona = 'ganadores';
    select id into v_per from public.partidos where zona_id = new.zona_id and tipo_zona = 'perdedores';
    perform public.asignar_slot(v_gan, v_slot, new.ganador_id);
    perform public.asignar_slot(v_per, v_slot, v_perdedor);
  end if;

  -- Playoff: el ganador avanza
  if new.fase <> 'zona' and new.siguiente_partido_id is not null then
    perform public.asignar_slot(new.siguiente_partido_id, new.siguiente_slot, new.ganador_id);
  end if;

  -- Final
  if new.fase = 'final' and new.ganador_id is distinct from old.ganador_id then
    update public.torneo_categorias
       set estado = case when new.ganador_id is null then 'playoff'::public.estado_torneo_categoria else 'finalizada' end
     where id = new.torneo_categoria_id;
  end if;

  return new;
end $$;


--
-- Name: partidos_resolver_cuadro(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.partidos_resolver_cuadro() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if new.fase = 'zona' and (new.estado, new.ganador_id, new.s1_a, new.s1_b, new.s2_a, new.s2_b, new.s3_a, new.s3_b)
     is distinct from (old.estado, old.ganador_id, old.s1_a, old.s1_b, old.s2_a, old.s2_b, old.s3_a, old.s3_b) then
    perform public.resolver_cuadro(new.torneo_categoria_id);
  end if;
  return null;
end $$;


--
-- Name: partidos_validar(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.partidos_validar() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_admin boolean := public.es_sistema_o_admin();
  v_sets_a int := 0;
  v_sets_b int := 0;
  v_games smallint;
begin
  -- Actualizaciones internas (propagación de ganadores / byes) se saltean los permisos
  if pg_trigger_depth() > 1 or current_setting('app.interno', true) = 'on' then
    return new;
  end if;

  if not v_admin then
    -- Editor: solo carga resultados de partidos pendientes
    if not public.es_editor_o_admin() then
      raise exception 'No tenés permisos para cargar resultados';
    end if;
    if old.estado <> 'pendiente' then
      raise exception 'El partido ya tiene resultado cargado; solo el administrador puede editarlo';
    end if;
    if (new.torneo_categoria_id, new.fase, new.zona_id, new.ronda, new.orden, new.tipo_zona,
        new.pareja_a_id, new.pareja_b_id, new.sede_id, new.cancha_id, new.fecha_hora,
        new.super_tiebreak, new.siguiente_partido_id, new.siguiente_slot)
       is distinct from
       (old.torneo_categoria_id, old.fase, old.zona_id, old.ronda, old.orden, old.tipo_zona,
        old.pareja_a_id, old.pareja_b_id, old.sede_id, old.cancha_id, old.fecha_hora,
        old.super_tiebreak, old.siguiente_partido_id, old.siguiente_slot) then
      raise exception 'Como editor solo podés cargar el resultado del partido';
    end if;
  end if;

  if new.estado = 'bye' and old.estado <> 'bye' then
    raise exception 'El estado "bye" lo asigna el sistema';
  end if;

  if new.estado in ('pendiente') then
    new.s1_a := null; new.s1_b := null; new.s2_a := null; new.s2_b := null; new.s3_a := null; new.s3_b := null;
    new.ganador_id := null;
    return new;
  end if;

  if new.estado in ('finalizado', 'wo') and (new.pareja_a_id is null or new.pareja_b_id is null) then
    raise exception 'El partido todavía no tiene definidas las dos parejas';
  end if;

  if new.estado = 'wo' then
    if new.ganador_id is null or new.ganador_id not in (new.pareja_a_id, new.pareja_b_id) then
      raise exception 'Indicá qué pareja gana por W.O.';
    end if;
    new.s1_a := null; new.s1_b := null; new.s2_a := null; new.s2_b := null; new.s3_a := null; new.s3_b := null;
  elsif new.estado = 'finalizado' then
    select t.games_set_unico into v_games
    from public.torneo_categorias tc join public.torneos t on t.id = tc.torneo_id
    where tc.id = new.torneo_categoria_id;
  end if;

  if new.estado = 'finalizado' and v_games is not null then
    if not public.set_unico_valido(new.s1_a, new.s1_b, v_games) then
      raise exception 'Resultado inválido (%-%): se juega a un set de % games (ej. %-%)', new.s1_a, new.s1_b, v_games, v_games, v_games - 3;
    end if;
    if coalesce(new.s2_a, new.s2_b, new.s3_a, new.s3_b) is not null then
      raise exception 'Se juega a un solo set: dejá vacíos el 2do y 3er set';
    end if;
    new.ganador_id := case when new.s1_a > new.s1_b then new.pareja_a_id else new.pareja_b_id end;
  elsif new.estado = 'finalizado' then
    if not public.set_valido(new.s1_a, new.s1_b, false) then
      raise exception 'Set 1 inválido (%-%): los sets terminan 6-0 a 6-4, 7-5 o 7-6', new.s1_a, new.s1_b;
    end if;
    if not public.set_valido(new.s2_a, new.s2_b, false) then
      raise exception 'Set 2 inválido (%-%): los sets terminan 6-0 a 6-4, 7-5 o 7-6', new.s2_a, new.s2_b;
    end if;
    v_sets_a := (new.s1_a > new.s1_b)::int + (new.s2_a > new.s2_b)::int;
    v_sets_b := 2 - v_sets_a;

    if v_sets_a = 1 then
      if not public.set_valido(new.s3_a, new.s3_b, new.super_tiebreak) then
        if new.super_tiebreak then
          raise exception 'El 3er set es super tiebreak a 11 con diferencia de 2 (ej. 11-7, 12-10)';
        else
          raise exception 'Set 3 inválido (%-%): los sets terminan 6-0 a 6-4, 7-5 o 7-6', new.s3_a, new.s3_b;
        end if;
      end if;
      v_sets_a := v_sets_a + (new.s3_a > new.s3_b)::int;
      v_sets_b := 3 - v_sets_a;
    elsif new.s3_a is not null or new.s3_b is not null then
      raise exception 'El partido se definió en 2 sets: no corresponde cargar un 3er set';
    end if;

    new.ganador_id := case when v_sets_a > v_sets_b then new.pareja_a_id else new.pareja_b_id end;
  end if;

  new.cargado_por := auth.uid();
  new.cargado_at := now();
  return new;
end $$;


--
-- Name: posiciones_zona(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.posiciones_zona(p_zona uuid) RETURNS TABLE(inscripcion_id uuid, pj integer, pg integer, pp integer, sets_favor integer, sets_contra integer, games_favor integer, games_contra integer, posicion integer)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  with fmt as (
    select t.games_set_unico as g
    from public.zonas z join public.torneo_categorias tc on tc.id = z.torneo_categoria_id
    join public.torneos t on t.id = tc.torneo_id where z.id = p_zona
  ),
  lados as (
    select p.id, p.estado, p.super_tiebreak, p.ganador_id, p.tipo_zona,
           p.pareja_a_id as yo,
           array[p.s1_a, p.s2_a, p.s3_a] as mis, array[p.s1_b, p.s2_b, p.s3_b] as sus
    from public.partidos p
    where p.zona_id = p_zona and p.estado in ('finalizado', 'wo')
    union all
    select p.id, p.estado, p.super_tiebreak, p.ganador_id, p.tipo_zona,
           p.pareja_b_id,
           array[p.s1_b, p.s2_b, p.s3_b], array[p.s1_a, p.s2_a, p.s3_a]
    from public.partidos p
    where p.zona_id = p_zona and p.estado in ('finalizado', 'wo')
  ),
  por_partido as (
    select l.yo,
           (l.ganador_id = l.yo) as gane,
           case when l.estado = 'wo' then case when l.ganador_id = l.yo then (case when f.g is null then 2 else 1 end) else 0 end
                else (select count(*) filter (where u.m > u.s) from unnest(l.mis, l.sus) as u(m, s) where u.m is not null) end as sf,
           case when l.estado = 'wo' then case when l.ganador_id = l.yo then 0 else (case when f.g is null then 2 else 1 end) end
                else (select count(*) filter (where u.m < u.s) from unnest(l.mis, l.sus) as u(m, s) where u.m is not null) end as sc,
           case when l.estado = 'wo' then case when l.ganador_id = l.yo then coalesce(f.g, 12) else 0 end
                else (select coalesce(sum(case when l.super_tiebreak and u.n = 3 then (u.m > u.s)::int else u.m end), 0)
                      from unnest(l.mis, l.sus) with ordinality as u(m, s, n) where u.m is not null) end as gf,
           case when l.estado = 'wo' then case when l.ganador_id = l.yo then 0 else coalesce(f.g, 12) end
                else (select coalesce(sum(case when l.super_tiebreak and u.n = 3 then (u.s > u.m)::int else u.s end), 0)
                      from unnest(l.mis, l.sus) with ordinality as u(m, s, n) where u.m is not null) end as gc
    from lados l cross join fmt f
  ),
  totales as (
    select zp.inscripcion_id, zp.posicion_sorteo,
           count(pp.yo)::int as pj,
           count(pp.yo) filter (where pp.gane)::int as pg,
           count(pp.yo) filter (where not pp.gane)::int as pp,
           coalesce(sum(pp.sf), 0)::int as sf, coalesce(sum(pp.sc), 0)::int as sc,
           coalesce(sum(pp.gf), 0)::int as gf, coalesce(sum(pp.gc), 0)::int as gc
    from public.zona_parejas zp
    left join por_partido pp on pp.yo = zp.inscripcion_id
    where zp.zona_id = p_zona
    group by zp.inscripcion_id, zp.posicion_sorteo
  ),
  fijas as (
    select x.ins, x.pos from (
      select case when p.ganador_id = p.pareja_a_id then p.pareja_a_id else p.pareja_b_id end as ins,
             case when p.tipo_zona = 'ganadores' then 1 else 3 end as pos
      from public.partidos p
      where p.zona_id = p_zona and p.tipo_zona is not null and p.ganador_id is not null
      union all
      select case when p.ganador_id = p.pareja_a_id then p.pareja_b_id else p.pareja_a_id end,
             case when p.tipo_zona = 'ganadores' then 2 else 4 end
      from public.partidos p
      where p.zona_id = p_zona and p.tipo_zona is not null and p.ganador_id is not null
    ) x
  )
  select t.inscripcion_id, t.pj, t.pg, t.pp, t.sf, t.sc, t.gf, t.gc,
         row_number() over (
           order by coalesce(f.pos, 100), t.pg desc, (t.sf - t.sc) desc, (t.gf - t.gc) desc, t.posicion_sorteo
         )::int as posicion
  from totales t
  left join fijas f on f.ins = t.inscripcion_id
  order by posicion
$$;


--
-- Name: registrar(text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.registrar(p_tipo text, p_movimiento text, p_entidad uuid DEFAULT NULL::uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare j public.jugadores;
begin
  select * into j from public.jugadores where id = auth.uid();
  if j.id is null or j.rol not in ('editor', 'administrador') then return; end if;
  insert into public.auditoria (usuario_id, usuario, rol, tipo, movimiento, entidad_id)
  values (j.id, j.nombre || ' ' || j.apellido || ' (' || j.dni || ')', j.rol, p_tipo, p_movimiento, p_entidad);
end $$;


--
-- Name: resolver_cuadro(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.resolver_cuadro(p_torneo_categoria uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  r public.partidos;
  a uuid; b uuid;
  v_pend boolean;
begin
  if not exists (select 1 from public.partidos where torneo_categoria_id = p_torneo_categoria
                 and (origen_a_zona_id is not null or origen_b_zona_id is not null)) then
    return;
  end if;
  perform set_config('app.interno', 'on', true);
  for r in
    select * from public.partidos
    where torneo_categoria_id = p_torneo_categoria and fase <> 'zona' and ronda = 1
    order by orden
  loop
    a := public.clasificado_zona(r.origen_a_zona_id, r.origen_a_pos);
    b := public.clasificado_zona(r.origen_b_zona_id, r.origen_b_pos);
    if r.estado in ('finalizado', 'wo') then
      if a is distinct from r.pareja_a_id or b is distinct from r.pareja_b_id then
        raise exception 'Ese cambio modifica quién clasifica a un partido de playoff que ya tiene resultado. Anulá primero ese resultado';
      end if;
    elsif r.estado = 'bye' then
      if (a, b, coalesce(a, b)) is distinct from (r.pareja_a_id, r.pareja_b_id, r.ganador_id) then
        update public.partidos set pareja_a_id = a, pareja_b_id = b, ganador_id = coalesce(a, b) where id = r.id;
      end if;
    elsif (a, b) is distinct from (r.pareja_a_id, r.pareja_b_id) then
      update public.partidos set pareja_a_id = a, pareja_b_id = b where id = r.id;
    end if;
  end loop;
  perform set_config('app.interno', 'off', true);

  -- La categoría pasa a "playoff" cuando terminaron todas las zonas (y vuelve a "zonas" si se anula algo)
  select exists (select 1 from public.partidos where torneo_categoria_id = p_torneo_categoria and fase = 'zona' and estado = 'pendiente')
    into v_pend;
  update public.torneo_categorias
     set estado = case when v_pend then 'zonas'::public.estado_torneo_categoria else 'playoff' end
   where id = p_torneo_categoria and estado in ('zonas', 'playoff')
     and estado <> case when v_pend then 'zonas'::public.estado_torneo_categoria else 'playoff' end;
end $$;


--
-- Name: set_unico_valido(smallint, smallint, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_unico_valido(a smallint, b smallint, p_games smallint) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
  select a is not null and b is not null and a >= 0 and b >= 0
     and greatest(a, b) = p_games and least(a, b) < p_games
$$;


--
-- Name: set_valido(smallint, smallint, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_valido(a smallint, b smallint, p_super boolean) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
  select case
    when a is null or b is null or a < 0 or b < 0 or a = b then false
    when p_super then (greatest(a, b) = 11 and least(a, b) <= 9)
                   or (greatest(a, b) > 11 and greatest(a, b) - least(a, b) = 2)
    else (greatest(a, b) = 6 and least(a, b) <= 4)
      or (greatest(a, b) = 7 and least(a, b) in (5, 6))
  end
$$;


--
-- Name: torneos_proteger_formato(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.torneos_proteger_formato() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if new.games_set_unico is distinct from old.games_set_unico and exists (
    select 1 from public.partidos p join public.torneo_categorias tc on tc.id = p.torneo_categoria_id
    where tc.torneo_id = new.id and p.estado in ('finalizado', 'wo')
  ) then
    raise exception 'El torneo ya tiene resultados cargados: no se puede cambiar el formato de los partidos';
  end if;
  return new;
end $$;


--
-- Name: torneos_validar_fechas(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.torneos_validar_fechas() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
declare
  v_cierre date;
begin
  if tg_op = 'UPDATE'
     and (new.fecha_desde, new.fecha_hasta, new.cierre_inscripcion)
         is not distinct from (old.fecha_desde, old.fecha_hasta, old.cierre_inscripcion) then
    return new;
  end if;

  if new.fecha_desde is null then raise exception 'Completá la fecha de inicio del torneo'; end if;
  if new.fecha_hasta is null then raise exception 'Completá la fecha de fin del torneo'; end if;
  if new.cierre_inscripcion is null then raise exception 'Completá la fecha y hora de cierre de inscripción'; end if;

  v_cierre := (new.cierre_inscripcion at time zone 'America/Argentina/Buenos_Aires')::date;
  if v_cierre >= new.fecha_hasta then
    raise exception 'El cierre de inscripción (%) tiene que ser anterior a la fecha de fin del torneo (%)',
      to_char(new.cierre_inscripcion at time zone 'America/Argentina/Buenos_Aires', 'DD/MM/YYYY HH24:MI'),
      to_char(new.fecha_hasta, 'DD/MM/YYYY');
  end if;
  return new;
end $$;


--
-- Name: touch_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.touch_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.updated_at := now();
  return new;
end $$;


--
-- Name: auditoria; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auditoria (
    id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    usuario_id uuid,
    usuario text NOT NULL,
    rol public.rol_usuario NOT NULL,
    tipo text NOT NULL,
    movimiento text NOT NULL,
    entidad_id uuid
);


--
-- Name: auditoria_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.auditoria ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.auditoria_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: canchas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.canchas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sede_id uuid NOT NULL,
    nombre text NOT NULL,
    orden smallint DEFAULT 0 NOT NULL,
    activa boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT canchas_nombre_check CHECK ((length(TRIM(BOTH FROM nombre)) > 0))
);


--
-- Name: categorias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categorias (
    id smallint NOT NULL,
    nombre text NOT NULL,
    genero public.genero_categoria NOT NULL,
    nivel smallint,
    orden smallint NOT NULL,
    tipo text DEFAULT 'nivel'::text NOT NULL,
    suma smallint,
    activa boolean DEFAULT true NOT NULL,
    CONSTRAINT categorias_nivel_check CHECK (((nivel >= 1) AND (nivel <= 9))),
    CONSTRAINT categorias_suma_check CHECK (((suma >= 4) AND (suma <= 20))),
    CONSTRAINT categorias_tipo_check CHECK ((tipo = ANY (ARRAY['nivel'::text, 'suma'::text]))),
    CONSTRAINT categorias_tipo_coherente CHECK ((((tipo = 'nivel'::text) AND (nivel IS NOT NULL) AND (suma IS NULL) AND (genero <> 'mixto'::public.genero_categoria)) OR ((tipo = 'suma'::text) AND (suma IS NOT NULL) AND (nivel IS NULL))))
);


--
-- Name: categorias_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.categorias ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.categorias_id_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: inscripciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inscripciones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    torneo_categoria_id uuid NOT NULL,
    pareja_id uuid NOT NULL,
    problemas_horario text DEFAULT ''::text NOT NULL,
    estado public.estado_inscripcion DEFAULT 'activa'::public.estado_inscripcion NOT NULL,
    pagada boolean DEFAULT false NOT NULL,
    inscripta_por uuid,
    cancelada_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: jugador_categoria_historial; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jugador_categoria_historial (
    id bigint NOT NULL,
    jugador_id uuid NOT NULL,
    categoria_anterior_id smallint,
    categoria_nueva_id smallint NOT NULL,
    cambiado_por uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: jugador_categoria_historial_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.jugador_categoria_historial ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.jugador_categoria_historial_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: jugadores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jugadores (
    id uuid NOT NULL,
    dni text NOT NULL,
    nombre text NOT NULL,
    apellido text NOT NULL,
    telefono text NOT NULL,
    email text,
    categoria_id smallint NOT NULL,
    rol public.rol_usuario DEFAULT 'jugador'::public.rol_usuario NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    debe_cambiar_password boolean DEFAULT false NOT NULL,
    CONSTRAINT jugadores_apellido_check CHECK ((length(TRIM(BOTH FROM apellido)) > 0)),
    CONSTRAINT jugadores_dni_check CHECK ((dni ~ '^[0-9]{6,9}$'::text)),
    CONSTRAINT jugadores_nombre_check CHECK ((length(TRIM(BOTH FROM nombre)) > 0)),
    CONSTRAINT jugadores_telefono_check CHECK ((length(TRIM(BOTH FROM telefono)) >= 6))
);


--
-- Name: parejas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parejas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    jugador1_id uuid NOT NULL,
    jugador2_id uuid NOT NULL,
    activa boolean DEFAULT true NOT NULL,
    creada_por uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT parejas_orden CHECK ((jugador1_id < jugador2_id))
);


--
-- Name: sedes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sedes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    direccion text,
    activa boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: torneo_categorias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.torneo_categorias (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    torneo_id uuid NOT NULL,
    categoria_id smallint NOT NULL,
    cupo_max smallint DEFAULT 24 NOT NULL,
    cupo_min smallint DEFAULT 6 NOT NULL,
    estado public.estado_torneo_categoria DEFAULT 'inscripcion'::public.estado_torneo_categoria NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT torneo_categoria_cupos CHECK ((cupo_min <= cupo_max)),
    CONSTRAINT torneo_categorias_cupo_max_check CHECK (((cupo_max >= 6) AND (cupo_max <= 24))),
    CONSTRAINT torneo_categorias_cupo_min_check CHECK ((cupo_min >= 6))
);


--
-- Name: torneos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.torneos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    descripcion text,
    fecha_desde date NOT NULL,
    fecha_hasta date NOT NULL,
    cierre_inscripcion timestamp with time zone NOT NULL,
    observaciones text,
    precio_inscripcion numeric(12,2),
    estado public.estado_torneo DEFAULT 'borrador'::public.estado_torneo NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    americano boolean DEFAULT false NOT NULL,
    games_set_unico smallint,
    CONSTRAINT torneos_americano CHECK (((americano = (games_set_unico IS NOT NULL)) AND ((NOT americano) OR (fecha_hasta = fecha_desde)))),
    CONSTRAINT torneos_fechas CHECK ((fecha_hasta >= fecha_desde)),
    CONSTRAINT torneos_games_set_unico_check CHECK (((games_set_unico >= 4) AND (games_set_unico <= 12)))
);


--
-- Name: v_parejas; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_parejas AS
 SELECT p.id,
    p.activa,
    p.created_at,
    p.jugador1_id,
    ((j1.nombre || ' '::text) || j1.apellido) AS jugador1,
    c1.nombre AS categoria1,
    j1.categoria_id AS categoria1_id,
    p.jugador2_id,
    ((j2.nombre || ' '::text) || j2.apellido) AS jugador2,
    c2.nombre AS categoria2,
    j2.categoria_id AS categoria2_id,
    ((j1.apellido || ' / '::text) || j2.apellido) AS nombre_corto
   FROM ((((public.parejas p
     JOIN public.jugadores j1 ON ((j1.id = p.jugador1_id)))
     JOIN public.categorias c1 ON ((c1.id = j1.categoria_id)))
     JOIN public.jugadores j2 ON ((j2.id = p.jugador2_id)))
     JOIN public.categorias c2 ON ((c2.id = j2.categoria_id)));


--
-- Name: v_inscripciones; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_inscripciones AS
 SELECT i.id,
    i.torneo_categoria_id,
    tc.torneo_id,
    tc.categoria_id,
    c.nombre AS categoria,
    i.pareja_id,
    vp.nombre_corto,
    vp.jugador1,
    vp.jugador2,
    vp.jugador1_id,
    vp.jugador2_id,
    i.estado,
    i.created_at
   FROM (((public.inscripciones i
     JOIN public.torneo_categorias tc ON ((tc.id = i.torneo_categoria_id)))
     JOIN public.categorias c ON ((c.id = tc.categoria_id)))
     JOIN public.v_parejas vp ON ((vp.id = i.pareja_id)))
  WHERE ((tc.estado <> 'inscripcion'::public.estado_torneo_categoria) OR public.es_editor_o_admin() OR public.es_miembro_pareja(i.pareja_id));


--
-- Name: v_jugadores; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_jugadores AS
 SELECT j.id,
    j.nombre,
    j.apellido,
    ((j.apellido || ', '::text) || j.nombre) AS nombre_completo,
    j.categoria_id,
    c.nombre AS categoria,
    c.genero,
    j.activo
   FROM (public.jugadores j
     JOIN public.categorias c ON ((c.id = j.categoria_id)));


--
-- Name: zonas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zonas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    torneo_categoria_id uuid NOT NULL,
    nombre text NOT NULL
);


--
-- Name: v_partidos; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_partidos AS
 SELECT p.id,
    p.torneo_categoria_id,
    p.fase,
    p.zona_id,
    p.ronda,
    p.orden,
    p.tipo_zona,
    p.pareja_a_id,
    p.pareja_b_id,
    p.sede_id,
    p.fecha_hora,
    p.super_tiebreak,
    p.s1_a,
    p.s1_b,
    p.s2_a,
    p.s2_b,
    p.s3_a,
    p.s3_b,
    p.ganador_id,
    p.estado,
    p.siguiente_partido_id,
    p.siguiente_slot,
    p.cargado_por,
    p.cargado_at,
    p.created_at,
    p.updated_at,
    p.cancha_id,
    p.origen_a_zona_id,
    p.origen_a_pos,
    p.origen_b_zona_id,
    p.origen_b_pos,
    tc.torneo_id,
    tc.categoria_id,
    c.nombre AS categoria,
    t.nombre AS torneo,
    z.nombre AS zona,
    s.nombre AS sede,
    ca.nombre AS cancha,
    pa.nombre_corto AS pareja_a,
    pa.jugador1 AS pareja_a_j1,
    pa.jugador2 AS pareja_a_j2,
    pb.nombre_corto AS pareja_b,
    pb.jugador1 AS pareja_b_j1,
    pb.jugador2 AS pareja_b_j2,
    pa.jugador1_id AS pareja_a_j1_id,
    pa.jugador2_id AS pareja_a_j2_id,
    pb.jugador1_id AS pareja_b_j1_id,
    pb.jugador2_id AS pareja_b_j2_id,
    t.games_set_unico,
    COALESCE(( SELECT ((p.origen_a_pos || '° Zona '::text) || zo.nombre)
           FROM public.zonas zo
          WHERE (zo.id = p.origen_a_zona_id)), ( SELECT
                CASE
                    WHEN (f.estado = 'bye'::public.estado_partido) THEN COALESCE(( SELECT ((f.origen_a_pos || '° Zona '::text) || zo.nombre)
                       FROM public.zonas zo
                      WHERE (zo.id = f.origen_a_zona_id)), ( SELECT ((f.origen_b_pos || '° Zona '::text) || zo.nombre)
                       FROM public.zonas zo
                      WHERE (zo.id = f.origen_b_zona_id)))
                    ELSE ((('Ganador '::text || initcap((f.fase)::text)) || ' '::text) || f.orden)
                END AS "case"
           FROM public.partidos f
          WHERE ((f.siguiente_partido_id = p.id) AND (f.siguiente_slot = 'A'::bpchar))
         LIMIT 1)) AS origen_a,
    COALESCE(( SELECT ((p.origen_b_pos || '° Zona '::text) || zo.nombre)
           FROM public.zonas zo
          WHERE (zo.id = p.origen_b_zona_id)), ( SELECT
                CASE
                    WHEN (f.estado = 'bye'::public.estado_partido) THEN COALESCE(( SELECT ((f.origen_a_pos || '° Zona '::text) || zo.nombre)
                       FROM public.zonas zo
                      WHERE (zo.id = f.origen_a_zona_id)), ( SELECT ((f.origen_b_pos || '° Zona '::text) || zo.nombre)
                       FROM public.zonas zo
                      WHERE (zo.id = f.origen_b_zona_id)))
                    ELSE ((('Ganador '::text || initcap((f.fase)::text)) || ' '::text) || f.orden)
                END AS "case"
           FROM public.partidos f
          WHERE ((f.siguiente_partido_id = p.id) AND (f.siguiente_slot = 'B'::bpchar))
         LIMIT 1)) AS origen_b
   FROM ((((((((public.partidos p
     JOIN public.torneo_categorias tc ON ((tc.id = p.torneo_categoria_id)))
     JOIN public.categorias c ON ((c.id = tc.categoria_id)))
     JOIN public.torneos t ON ((t.id = tc.torneo_id)))
     LEFT JOIN public.zonas z ON ((z.id = p.zona_id)))
     LEFT JOIN public.canchas ca ON ((ca.id = p.cancha_id)))
     LEFT JOIN public.sedes s ON ((s.id = p.sede_id)))
     LEFT JOIN ( SELECT i.id,
            vp.id,
            vp.activa,
            vp.created_at,
            vp.jugador1_id,
            vp.jugador1,
            vp.categoria1,
            vp.categoria1_id,
            vp.jugador2_id,
            vp.jugador2,
            vp.categoria2,
            vp.categoria2_id,
            vp.nombre_corto
           FROM (public.inscripciones i
             JOIN public.v_parejas vp ON ((vp.id = i.pareja_id)))) pa(ins_id, id, activa, created_at, jugador1_id, jugador1, categoria1, categoria1_id, jugador2_id, jugador2, categoria2, categoria2_id, nombre_corto) ON ((pa.ins_id = p.pareja_a_id)))
     LEFT JOIN ( SELECT i.id,
            vp.id,
            vp.activa,
            vp.created_at,
            vp.jugador1_id,
            vp.jugador1,
            vp.categoria1,
            vp.categoria1_id,
            vp.jugador2_id,
            vp.jugador2,
            vp.categoria2,
            vp.categoria2_id,
            vp.nombre_corto
           FROM (public.inscripciones i
             JOIN public.v_parejas vp ON ((vp.id = i.pareja_id)))) pb(ins_id, id, activa, created_at, jugador1_id, jugador1, categoria1, categoria1_id, jugador2_id, jugador2, categoria2, categoria2_id, nombre_corto) ON ((pb.ins_id = p.pareja_b_id)));


--
-- Name: v_torneo_categorias; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_torneo_categorias AS
 SELECT tc.id,
    tc.torneo_id,
    tc.categoria_id,
    c.nombre AS categoria,
    c.genero,
    c.orden,
    tc.cupo_max,
    tc.cupo_min,
    tc.estado,
        CASE
            WHEN public.es_editor_o_admin() THEN n.cant
            ELSE NULL::integer
        END AS inscriptas,
    (n.cant >= tc.cupo_max) AS cupo_completo,
    c.tipo,
    c.suma
   FROM (((public.torneo_categorias tc
     JOIN public.categorias c ON ((c.id = tc.categoria_id)))
     JOIN public.torneos t ON ((t.id = tc.torneo_id)))
     CROSS JOIN LATERAL ( SELECT (count(*))::integer AS cant
           FROM public.inscripciones i
          WHERE ((i.torneo_categoria_id = tc.id) AND (i.estado = 'activa'::public.estado_inscripcion))) n)
  WHERE ((t.estado <> 'borrador'::public.estado_torneo) OR public.es_admin());


--
-- Name: zona_parejas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zona_parejas (
    zona_id uuid NOT NULL,
    inscripcion_id uuid NOT NULL,
    posicion_sorteo smallint NOT NULL
);


--
-- Name: auditoria auditoria_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auditoria
    ADD CONSTRAINT auditoria_pkey PRIMARY KEY (id);


--
-- Name: canchas canchas_nombre_unico; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.canchas
    ADD CONSTRAINT canchas_nombre_unico UNIQUE (sede_id, nombre);


--
-- Name: canchas canchas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.canchas
    ADD CONSTRAINT canchas_pkey PRIMARY KEY (id);


--
-- Name: categorias categorias_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_nombre_key UNIQUE (nombre);


--
-- Name: categorias categorias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_pkey PRIMARY KEY (id);


--
-- Name: categorias categorias_suma_unica; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_suma_unica UNIQUE (tipo, genero, suma);


--
-- Name: inscripciones inscripciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inscripciones
    ADD CONSTRAINT inscripciones_pkey PRIMARY KEY (id);


--
-- Name: jugador_categoria_historial jugador_categoria_historial_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jugador_categoria_historial
    ADD CONSTRAINT jugador_categoria_historial_pkey PRIMARY KEY (id);


--
-- Name: jugadores jugadores_dni_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jugadores
    ADD CONSTRAINT jugadores_dni_key UNIQUE (dni);


--
-- Name: jugadores jugadores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jugadores
    ADD CONSTRAINT jugadores_pkey PRIMARY KEY (id);


--
-- Name: parejas parejas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parejas
    ADD CONSTRAINT parejas_pkey PRIMARY KEY (id);


--
-- Name: parejas parejas_unicas; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parejas
    ADD CONSTRAINT parejas_unicas UNIQUE (jugador1_id, jugador2_id);


--
-- Name: partidos partidos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partidos
    ADD CONSTRAINT partidos_pkey PRIMARY KEY (id);


--
-- Name: sedes sedes_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sedes
    ADD CONSTRAINT sedes_nombre_key UNIQUE (nombre);


--
-- Name: sedes sedes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sedes
    ADD CONSTRAINT sedes_pkey PRIMARY KEY (id);


--
-- Name: torneo_categorias torneo_categoria_unica; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.torneo_categorias
    ADD CONSTRAINT torneo_categoria_unica UNIQUE (torneo_id, categoria_id);


--
-- Name: torneo_categorias torneo_categorias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.torneo_categorias
    ADD CONSTRAINT torneo_categorias_pkey PRIMARY KEY (id);


--
-- Name: torneos torneos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.torneos
    ADD CONSTRAINT torneos_pkey PRIMARY KEY (id);


--
-- Name: zona_parejas zona_parejas_inscripcion_unica; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zona_parejas
    ADD CONSTRAINT zona_parejas_inscripcion_unica UNIQUE (inscripcion_id);


--
-- Name: zona_parejas zona_parejas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zona_parejas
    ADD CONSTRAINT zona_parejas_pkey PRIMARY KEY (zona_id, inscripcion_id);


--
-- Name: zonas zona_unica; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zonas
    ADD CONSTRAINT zona_unica UNIQUE (torneo_categoria_id, nombre);


--
-- Name: zonas zonas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zonas
    ADD CONSTRAINT zonas_pkey PRIMARY KEY (id);


--
-- Name: auditoria_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auditoria_created_at_idx ON public.auditoria USING btree (created_at DESC);


--
-- Name: auditoria_tipo_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auditoria_tipo_idx ON public.auditoria USING btree (tipo);


--
-- Name: auditoria_usuario_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auditoria_usuario_id_idx ON public.auditoria USING btree (usuario_id);


--
-- Name: inscripciones_pareja_activa_unica; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX inscripciones_pareja_activa_unica ON public.inscripciones USING btree (torneo_categoria_id, pareja_id) WHERE (estado = 'activa'::public.estado_inscripcion);


--
-- Name: inscripciones_pareja_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX inscripciones_pareja_id_idx ON public.inscripciones USING btree (pareja_id);


--
-- Name: jugador_categoria_historial_jugador_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX jugador_categoria_historial_jugador_id_created_at_idx ON public.jugador_categoria_historial USING btree (jugador_id, created_at DESC);


--
-- Name: jugadores_apellido_nombre_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX jugadores_apellido_nombre_idx ON public.jugadores USING btree (apellido, nombre);


--
-- Name: jugadores_categoria_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX jugadores_categoria_id_idx ON public.jugadores USING btree (categoria_id);


--
-- Name: parejas_jugador2_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX parejas_jugador2_id_idx ON public.parejas USING btree (jugador2_id);


--
-- Name: partidos_fecha_hora_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX partidos_fecha_hora_idx ON public.partidos USING btree (fecha_hora);


--
-- Name: partidos_pareja_a_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX partidos_pareja_a_id_idx ON public.partidos USING btree (pareja_a_id);


--
-- Name: partidos_pareja_b_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX partidos_pareja_b_id_idx ON public.partidos USING btree (pareja_b_id);


--
-- Name: partidos_torneo_categoria_id_fase_ronda_orden_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX partidos_torneo_categoria_id_fase_ronda_orden_idx ON public.partidos USING btree (torneo_categoria_id, fase, ronda, orden);


--
-- Name: partidos_zona_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX partidos_zona_id_idx ON public.partidos USING btree (zona_id);


--
-- Name: canchas t_aud_canchas; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_aud_canchas AFTER INSERT OR DELETE OR UPDATE ON public.canchas FOR EACH ROW EXECUTE FUNCTION public.aud_canchas();


--
-- Name: categorias t_aud_categorias; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_aud_categorias AFTER INSERT OR UPDATE ON public.categorias FOR EACH ROW EXECUTE FUNCTION public.aud_categorias();


--
-- Name: inscripciones t_aud_inscripciones; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_aud_inscripciones AFTER INSERT OR UPDATE ON public.inscripciones FOR EACH ROW EXECUTE FUNCTION public.aud_inscripciones();


--
-- Name: jugadores t_aud_jugadores; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_aud_jugadores AFTER UPDATE ON public.jugadores FOR EACH ROW EXECUTE FUNCTION public.aud_jugadores();


--
-- Name: partidos t_aud_partidos; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_aud_partidos AFTER UPDATE ON public.partidos FOR EACH ROW EXECUTE FUNCTION public.aud_partidos();


--
-- Name: sedes t_aud_sedes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_aud_sedes AFTER INSERT OR UPDATE ON public.sedes FOR EACH ROW EXECUTE FUNCTION public.aud_sedes();


--
-- Name: torneo_categorias t_aud_torneo_categorias; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_aud_torneo_categorias AFTER INSERT OR DELETE OR UPDATE ON public.torneo_categorias FOR EACH ROW EXECUTE FUNCTION public.aud_torneo_categorias();


--
-- Name: torneos t_aud_torneos; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_aud_torneos AFTER INSERT OR DELETE OR UPDATE ON public.torneos FOR EACH ROW EXECUTE FUNCTION public.aud_torneos();


--
-- Name: inscripciones t_inscripciones_touch; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_inscripciones_touch BEFORE UPDATE ON public.inscripciones FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: inscripciones t_inscripciones_validar; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_inscripciones_validar BEFORE INSERT OR UPDATE ON public.inscripciones FOR EACH ROW EXECUTE FUNCTION public.inscripciones_validar();


--
-- Name: jugadores t_jugadores_proteger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_jugadores_proteger BEFORE UPDATE ON public.jugadores FOR EACH ROW EXECUTE FUNCTION public.jugadores_proteger();


--
-- Name: jugadores t_jugadores_touch; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_jugadores_touch BEFORE UPDATE ON public.jugadores FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: jugadores t_jugadores_validar_categoria; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_jugadores_validar_categoria BEFORE INSERT OR UPDATE OF categoria_id ON public.jugadores FOR EACH ROW EXECUTE FUNCTION public.jugadores_validar_categoria();


--
-- Name: parejas t_parejas_proteger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_parejas_proteger BEFORE UPDATE ON public.parejas FOR EACH ROW EXECUTE FUNCTION public.parejas_proteger();


--
-- Name: parejas t_parejas_touch; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_parejas_touch BEFORE UPDATE ON public.parejas FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: partidos t_partidos_cancha_de_sede; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_partidos_cancha_de_sede BEFORE INSERT OR UPDATE OF cancha_id, sede_id ON public.partidos FOR EACH ROW EXECUTE FUNCTION public.partidos_cancha_de_sede();


--
-- Name: partidos t_partidos_propagar; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_partidos_propagar AFTER UPDATE ON public.partidos FOR EACH ROW EXECUTE FUNCTION public.partidos_propagar();


--
-- Name: partidos t_partidos_resolver_cuadro; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_partidos_resolver_cuadro AFTER UPDATE ON public.partidos FOR EACH ROW EXECUTE FUNCTION public.partidos_resolver_cuadro();


--
-- Name: partidos t_partidos_touch; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_partidos_touch BEFORE UPDATE ON public.partidos FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: partidos t_partidos_validar; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_partidos_validar BEFORE UPDATE ON public.partidos FOR EACH ROW EXECUTE FUNCTION public.partidos_validar();


--
-- Name: torneos t_torneos_proteger_formato; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_torneos_proteger_formato BEFORE UPDATE OF americano, games_set_unico ON public.torneos FOR EACH ROW EXECUTE FUNCTION public.torneos_proteger_formato();


--
-- Name: torneos t_torneos_touch; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_torneos_touch BEFORE UPDATE ON public.torneos FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: torneos t_torneos_validar_fechas; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER t_torneos_validar_fechas BEFORE INSERT OR UPDATE ON public.torneos FOR EACH ROW EXECUTE FUNCTION public.torneos_validar_fechas();


--
-- Name: auditoria auditoria_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auditoria
    ADD CONSTRAINT auditoria_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.jugadores(id) ON DELETE SET NULL;


--
-- Name: canchas canchas_sede_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.canchas
    ADD CONSTRAINT canchas_sede_id_fkey FOREIGN KEY (sede_id) REFERENCES public.sedes(id) ON DELETE CASCADE;


--
-- Name: inscripciones inscripciones_inscripta_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inscripciones
    ADD CONSTRAINT inscripciones_inscripta_por_fkey FOREIGN KEY (inscripta_por) REFERENCES public.jugadores(id);


--
-- Name: inscripciones inscripciones_pareja_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inscripciones
    ADD CONSTRAINT inscripciones_pareja_id_fkey FOREIGN KEY (pareja_id) REFERENCES public.parejas(id);


--
-- Name: inscripciones inscripciones_torneo_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inscripciones
    ADD CONSTRAINT inscripciones_torneo_categoria_id_fkey FOREIGN KEY (torneo_categoria_id) REFERENCES public.torneo_categorias(id) ON DELETE CASCADE;


--
-- Name: jugador_categoria_historial jugador_categoria_historial_cambiado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jugador_categoria_historial
    ADD CONSTRAINT jugador_categoria_historial_cambiado_por_fkey FOREIGN KEY (cambiado_por) REFERENCES public.jugadores(id);


--
-- Name: jugador_categoria_historial jugador_categoria_historial_categoria_anterior_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jugador_categoria_historial
    ADD CONSTRAINT jugador_categoria_historial_categoria_anterior_id_fkey FOREIGN KEY (categoria_anterior_id) REFERENCES public.categorias(id);


--
-- Name: jugador_categoria_historial jugador_categoria_historial_categoria_nueva_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jugador_categoria_historial
    ADD CONSTRAINT jugador_categoria_historial_categoria_nueva_id_fkey FOREIGN KEY (categoria_nueva_id) REFERENCES public.categorias(id);


--
-- Name: jugador_categoria_historial jugador_categoria_historial_jugador_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jugador_categoria_historial
    ADD CONSTRAINT jugador_categoria_historial_jugador_id_fkey FOREIGN KEY (jugador_id) REFERENCES public.jugadores(id) ON DELETE CASCADE;


--
-- Name: jugadores jugadores_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jugadores
    ADD CONSTRAINT jugadores_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias(id);


--
-- Name: jugadores jugadores_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jugadores
    ADD CONSTRAINT jugadores_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: parejas parejas_creada_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parejas
    ADD CONSTRAINT parejas_creada_por_fkey FOREIGN KEY (creada_por) REFERENCES public.jugadores(id);


--
-- Name: parejas parejas_jugador1_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parejas
    ADD CONSTRAINT parejas_jugador1_id_fkey FOREIGN KEY (jugador1_id) REFERENCES public.jugadores(id) ON DELETE CASCADE;


--
-- Name: parejas parejas_jugador2_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parejas
    ADD CONSTRAINT parejas_jugador2_id_fkey FOREIGN KEY (jugador2_id) REFERENCES public.jugadores(id) ON DELETE CASCADE;


--
-- Name: partidos partidos_cancha_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partidos
    ADD CONSTRAINT partidos_cancha_id_fkey FOREIGN KEY (cancha_id) REFERENCES public.canchas(id) ON DELETE SET NULL;


--
-- Name: partidos partidos_cargado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partidos
    ADD CONSTRAINT partidos_cargado_por_fkey FOREIGN KEY (cargado_por) REFERENCES public.jugadores(id);


--
-- Name: partidos partidos_ganador_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partidos
    ADD CONSTRAINT partidos_ganador_id_fkey FOREIGN KEY (ganador_id) REFERENCES public.inscripciones(id);


--
-- Name: partidos partidos_origen_a_zona_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partidos
    ADD CONSTRAINT partidos_origen_a_zona_id_fkey FOREIGN KEY (origen_a_zona_id) REFERENCES public.zonas(id) ON DELETE SET NULL;


--
-- Name: partidos partidos_origen_b_zona_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partidos
    ADD CONSTRAINT partidos_origen_b_zona_id_fkey FOREIGN KEY (origen_b_zona_id) REFERENCES public.zonas(id) ON DELETE SET NULL;


--
-- Name: partidos partidos_pareja_a_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partidos
    ADD CONSTRAINT partidos_pareja_a_id_fkey FOREIGN KEY (pareja_a_id) REFERENCES public.inscripciones(id);


--
-- Name: partidos partidos_pareja_b_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partidos
    ADD CONSTRAINT partidos_pareja_b_id_fkey FOREIGN KEY (pareja_b_id) REFERENCES public.inscripciones(id);


--
-- Name: partidos partidos_sede_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partidos
    ADD CONSTRAINT partidos_sede_id_fkey FOREIGN KEY (sede_id) REFERENCES public.sedes(id);


--
-- Name: partidos partidos_siguiente_partido_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partidos
    ADD CONSTRAINT partidos_siguiente_partido_id_fkey FOREIGN KEY (siguiente_partido_id) REFERENCES public.partidos(id) ON DELETE SET NULL;


--
-- Name: partidos partidos_torneo_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partidos
    ADD CONSTRAINT partidos_torneo_categoria_id_fkey FOREIGN KEY (torneo_categoria_id) REFERENCES public.torneo_categorias(id) ON DELETE CASCADE;


--
-- Name: partidos partidos_zona_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partidos
    ADD CONSTRAINT partidos_zona_id_fkey FOREIGN KEY (zona_id) REFERENCES public.zonas(id) ON DELETE CASCADE;


--
-- Name: torneo_categorias torneo_categorias_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.torneo_categorias
    ADD CONSTRAINT torneo_categorias_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias(id);


--
-- Name: torneo_categorias torneo_categorias_torneo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.torneo_categorias
    ADD CONSTRAINT torneo_categorias_torneo_id_fkey FOREIGN KEY (torneo_id) REFERENCES public.torneos(id) ON DELETE CASCADE;


--
-- Name: torneos torneos_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.torneos
    ADD CONSTRAINT torneos_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.jugadores(id);


--
-- Name: zona_parejas zona_parejas_inscripcion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zona_parejas
    ADD CONSTRAINT zona_parejas_inscripcion_id_fkey FOREIGN KEY (inscripcion_id) REFERENCES public.inscripciones(id) ON DELETE CASCADE;


--
-- Name: zona_parejas zona_parejas_zona_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zona_parejas
    ADD CONSTRAINT zona_parejas_zona_id_fkey FOREIGN KEY (zona_id) REFERENCES public.zonas(id) ON DELETE CASCADE;


--
-- Name: zonas zonas_torneo_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zonas
    ADD CONSTRAINT zonas_torneo_categoria_id_fkey FOREIGN KEY (torneo_categoria_id) REFERENCES public.torneo_categorias(id) ON DELETE CASCADE;


--
-- Name: auditoria; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.auditoria ENABLE ROW LEVEL SECURITY;

--
-- Name: auditoria auditoria_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY auditoria_select ON public.auditoria FOR SELECT TO authenticated USING (public.es_admin());


--
-- Name: canchas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.canchas ENABLE ROW LEVEL SECURITY;

--
-- Name: canchas canchas_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY canchas_admin ON public.canchas TO authenticated USING (public.es_admin()) WITH CHECK (public.es_admin());


--
-- Name: canchas canchas_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY canchas_select ON public.canchas FOR SELECT TO authenticated USING (true);


--
-- Name: categorias; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.categorias ENABLE ROW LEVEL SECURITY;

--
-- Name: categorias categorias_admin_ins; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY categorias_admin_ins ON public.categorias FOR INSERT TO authenticated WITH CHECK (public.es_admin());


--
-- Name: categorias categorias_admin_upd; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY categorias_admin_upd ON public.categorias FOR UPDATE TO authenticated USING (public.es_admin()) WITH CHECK (public.es_admin());


--
-- Name: categorias categorias_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY categorias_select ON public.categorias FOR SELECT USING (true);


--
-- Name: jugador_categoria_historial historial_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY historial_select ON public.jugador_categoria_historial FOR SELECT TO authenticated USING (((jugador_id = auth.uid()) OR public.es_admin()));


--
-- Name: inscripciones; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.inscripciones ENABLE ROW LEVEL SECURITY;

--
-- Name: inscripciones inscripciones_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY inscripciones_delete ON public.inscripciones FOR DELETE TO authenticated USING (public.es_admin());


--
-- Name: inscripciones inscripciones_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY inscripciones_insert ON public.inscripciones FOR INSERT TO authenticated WITH CHECK ((public.es_miembro_pareja(pareja_id) OR public.es_admin()));


--
-- Name: inscripciones inscripciones_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY inscripciones_select ON public.inscripciones FOR SELECT TO authenticated USING ((public.es_miembro_pareja(pareja_id) OR public.es_admin()));


--
-- Name: inscripciones inscripciones_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY inscripciones_update ON public.inscripciones FOR UPDATE TO authenticated USING ((public.es_miembro_pareja(pareja_id) OR public.es_admin())) WITH CHECK ((public.es_miembro_pareja(pareja_id) OR public.es_admin()));


--
-- Name: jugador_categoria_historial; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.jugador_categoria_historial ENABLE ROW LEVEL SECURITY;

--
-- Name: jugadores; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.jugadores ENABLE ROW LEVEL SECURITY;

--
-- Name: jugadores jugadores_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY jugadores_select ON public.jugadores FOR SELECT TO authenticated USING (((id = auth.uid()) OR public.es_admin()));


--
-- Name: jugadores jugadores_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY jugadores_update ON public.jugadores FOR UPDATE TO authenticated USING (((id = auth.uid()) OR public.es_admin())) WITH CHECK (((id = auth.uid()) OR public.es_admin()));


--
-- Name: parejas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.parejas ENABLE ROW LEVEL SECURITY;

--
-- Name: parejas parejas_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY parejas_select ON public.parejas FOR SELECT TO authenticated USING ((((auth.uid() = jugador1_id) OR (auth.uid() = jugador2_id)) OR public.es_admin()));


--
-- Name: parejas parejas_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY parejas_update ON public.parejas FOR UPDATE TO authenticated USING ((((auth.uid() = jugador1_id) OR (auth.uid() = jugador2_id)) OR public.es_admin())) WITH CHECK ((((auth.uid() = jugador1_id) OR (auth.uid() = jugador2_id)) OR public.es_admin()));


--
-- Name: partidos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.partidos ENABLE ROW LEVEL SECURITY;

--
-- Name: partidos partidos_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY partidos_delete ON public.partidos FOR DELETE TO authenticated USING (public.es_admin());


--
-- Name: partidos partidos_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY partidos_insert ON public.partidos FOR INSERT TO authenticated WITH CHECK (public.es_admin());


--
-- Name: partidos partidos_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY partidos_select ON public.partidos FOR SELECT TO authenticated USING (true);


--
-- Name: partidos partidos_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY partidos_update ON public.partidos FOR UPDATE TO authenticated USING (public.es_editor_o_admin()) WITH CHECK (public.es_editor_o_admin());


--
-- Name: sedes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sedes ENABLE ROW LEVEL SECURITY;

--
-- Name: sedes sedes_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sedes_admin ON public.sedes TO authenticated USING (public.es_admin()) WITH CHECK (public.es_admin());


--
-- Name: sedes sedes_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sedes_select ON public.sedes FOR SELECT TO authenticated USING (true);


--
-- Name: torneo_categorias tc_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tc_admin ON public.torneo_categorias TO authenticated USING (public.es_admin()) WITH CHECK (public.es_admin());


--
-- Name: torneo_categorias tc_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tc_select ON public.torneo_categorias FOR SELECT TO authenticated USING (true);


--
-- Name: torneo_categorias; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.torneo_categorias ENABLE ROW LEVEL SECURITY;

--
-- Name: torneos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.torneos ENABLE ROW LEVEL SECURITY;

--
-- Name: torneos torneos_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY torneos_admin ON public.torneos TO authenticated USING (public.es_admin()) WITH CHECK (public.es_admin());


--
-- Name: torneos torneos_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY torneos_select ON public.torneos FOR SELECT TO authenticated USING (((estado <> 'borrador'::public.estado_torneo) OR public.es_admin()));


--
-- Name: zona_parejas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.zona_parejas ENABLE ROW LEVEL SECURITY;

--
-- Name: zonas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.zonas ENABLE ROW LEVEL SECURITY;

--
-- Name: zonas zonas_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY zonas_admin ON public.zonas TO authenticated USING (public.es_admin()) WITH CHECK (public.es_admin());


--
-- Name: zonas zonas_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY zonas_select ON public.zonas FOR SELECT TO authenticated USING (true);


--
-- Name: zona_parejas zp_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY zp_admin ON public.zona_parejas TO authenticated USING (public.es_admin()) WITH CHECK (public.es_admin());


--
-- Name: zona_parejas zp_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY zp_select ON public.zona_parejas FOR SELECT TO authenticated USING (true);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION admin_inscribir(p_torneo_categoria uuid, p_dni1 text, p_dni2 text, p_horario text, p_pagada boolean); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_inscribir(p_torneo_categoria uuid, p_dni1 text, p_dni2 text, p_horario text, p_pagada boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_inscribir(p_torneo_categoria uuid, p_dni1 text, p_dni2 text, p_horario text, p_pagada boolean) TO authenticated;
GRANT ALL ON FUNCTION public.admin_inscribir(p_torneo_categoria uuid, p_dni1 text, p_dni2 text, p_horario text, p_pagada boolean) TO service_role;


--
-- Name: FUNCTION admin_inscriptos(p_torneo_categoria uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.admin_inscriptos(p_torneo_categoria uuid) TO authenticated;
GRANT ALL ON FUNCTION public.admin_inscriptos(p_torneo_categoria uuid) TO service_role;


--
-- Name: FUNCTION admin_kpis(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_kpis() FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_kpis() TO authenticated;
GRANT ALL ON FUNCTION public.admin_kpis() TO service_role;


--
-- Name: FUNCTION admin_resetear_password(p_jugador uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_resetear_password(p_jugador uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_resetear_password(p_jugador uuid) TO authenticated;
GRANT ALL ON FUNCTION public.admin_resetear_password(p_jugador uuid) TO service_role;


--
-- Name: FUNCTION armar_cuadro(p_torneo_categoria uuid, p_cruces jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.armar_cuadro(p_torneo_categoria uuid, p_cruces jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.armar_cuadro(p_torneo_categoria uuid, p_cruces jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.armar_cuadro(p_torneo_categoria uuid, p_cruces jsonb) TO service_role;


--
-- Name: FUNCTION armar_zonas_manual(p_torneo_categoria uuid, p_zonas jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.armar_zonas_manual(p_torneo_categoria uuid, p_zonas jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.armar_zonas_manual(p_torneo_categoria uuid, p_zonas jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.armar_zonas_manual(p_torneo_categoria uuid, p_zonas jsonb) TO service_role;


--
-- Name: FUNCTION asignar_slot(p_partido uuid, p_slot character, p_inscripcion uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.asignar_slot(p_partido uuid, p_slot character, p_inscripcion uuid) TO authenticated;
GRANT ALL ON FUNCTION public.asignar_slot(p_partido uuid, p_slot character, p_inscripcion uuid) TO service_role;


--
-- Name: FUNCTION aud_canchas(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.aud_canchas() TO anon;
GRANT ALL ON FUNCTION public.aud_canchas() TO authenticated;
GRANT ALL ON FUNCTION public.aud_canchas() TO service_role;


--
-- Name: FUNCTION aud_categorias(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.aud_categorias() TO anon;
GRANT ALL ON FUNCTION public.aud_categorias() TO authenticated;
GRANT ALL ON FUNCTION public.aud_categorias() TO service_role;


--
-- Name: FUNCTION aud_inscripcion(p uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.aud_inscripcion(p uuid) TO anon;
GRANT ALL ON FUNCTION public.aud_inscripcion(p uuid) TO authenticated;
GRANT ALL ON FUNCTION public.aud_inscripcion(p uuid) TO service_role;


--
-- Name: FUNCTION aud_inscripciones(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.aud_inscripciones() TO anon;
GRANT ALL ON FUNCTION public.aud_inscripciones() TO authenticated;
GRANT ALL ON FUNCTION public.aud_inscripciones() TO service_role;


--
-- Name: FUNCTION aud_jugadores(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.aud_jugadores() TO anon;
GRANT ALL ON FUNCTION public.aud_jugadores() TO authenticated;
GRANT ALL ON FUNCTION public.aud_jugadores() TO service_role;


--
-- Name: FUNCTION aud_nombre_torneo(p uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.aud_nombre_torneo(p uuid) TO anon;
GRANT ALL ON FUNCTION public.aud_nombre_torneo(p uuid) TO authenticated;
GRANT ALL ON FUNCTION public.aud_nombre_torneo(p uuid) TO service_role;


--
-- Name: TABLE partidos; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.partidos TO anon;
GRANT ALL ON TABLE public.partidos TO authenticated;
GRANT ALL ON TABLE public.partidos TO service_role;


--
-- Name: FUNCTION aud_partido(p public.partidos); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.aud_partido(p public.partidos) TO anon;
GRANT ALL ON FUNCTION public.aud_partido(p public.partidos) TO authenticated;
GRANT ALL ON FUNCTION public.aud_partido(p public.partidos) TO service_role;


--
-- Name: FUNCTION aud_partidos(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.aud_partidos() TO anon;
GRANT ALL ON FUNCTION public.aud_partidos() TO authenticated;
GRANT ALL ON FUNCTION public.aud_partidos() TO service_role;


--
-- Name: FUNCTION aud_sedes(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.aud_sedes() TO anon;
GRANT ALL ON FUNCTION public.aud_sedes() TO authenticated;
GRANT ALL ON FUNCTION public.aud_sedes() TO service_role;


--
-- Name: FUNCTION aud_tc(p uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.aud_tc(p uuid) TO anon;
GRANT ALL ON FUNCTION public.aud_tc(p uuid) TO authenticated;
GRANT ALL ON FUNCTION public.aud_tc(p uuid) TO service_role;


--
-- Name: FUNCTION aud_torneo_categorias(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.aud_torneo_categorias() TO anon;
GRANT ALL ON FUNCTION public.aud_torneo_categorias() TO authenticated;
GRANT ALL ON FUNCTION public.aud_torneo_categorias() TO service_role;


--
-- Name: FUNCTION aud_torneos(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.aud_torneos() TO anon;
GRANT ALL ON FUNCTION public.aud_torneos() TO authenticated;
GRANT ALL ON FUNCTION public.aud_torneos() TO service_role;


--
-- Name: FUNCTION auditoria_omitir(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.auditoria_omitir() TO anon;
GRANT ALL ON FUNCTION public.auditoria_omitir() TO authenticated;
GRANT ALL ON FUNCTION public.auditoria_omitir() TO service_role;


--
-- Name: FUNCTION auditoria_usuarios(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.auditoria_usuarios() FROM PUBLIC;
GRANT ALL ON FUNCTION public.auditoria_usuarios() TO authenticated;
GRANT ALL ON FUNCTION public.auditoria_usuarios() TO service_role;


--
-- Name: FUNCTION buscar_jugador_por_dni(p_dni text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.buscar_jugador_por_dni(p_dni text) TO authenticated;
GRANT ALL ON FUNCTION public.buscar_jugador_por_dni(p_dni text) TO service_role;


--
-- Name: FUNCTION categorias_habilitadas_pareja(p_pareja uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.categorias_habilitadas_pareja(p_pareja uuid) TO authenticated;
GRANT ALL ON FUNCTION public.categorias_habilitadas_pareja(p_pareja uuid) TO service_role;


--
-- Name: FUNCTION clasificado_zona(p_zona uuid, p_pos smallint); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.clasificado_zona(p_zona uuid, p_pos smallint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.clasificado_zona(p_zona uuid, p_pos smallint) TO authenticated;
GRANT ALL ON FUNCTION public.clasificado_zona(p_zona uuid, p_pos smallint) TO service_role;


--
-- Name: FUNCTION crear_pareja(p_dni_companero text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.crear_pareja(p_dni_companero text) TO authenticated;
GRANT ALL ON FUNCTION public.crear_pareja(p_dni_companero text) TO service_role;


--
-- Name: FUNCTION crear_partidos_zona(p_tc uuid, p_zona uuid, p_parejas uuid[]); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.crear_partidos_zona(p_tc uuid, p_zona uuid, p_parejas uuid[]) FROM PUBLIC;
GRANT ALL ON FUNCTION public.crear_partidos_zona(p_tc uuid, p_zona uuid, p_parejas uuid[]) TO authenticated;
GRANT ALL ON FUNCTION public.crear_partidos_zona(p_tc uuid, p_zona uuid, p_parejas uuid[]) TO service_role;


--
-- Name: FUNCTION dni_disponible(p_dni text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.dni_disponible(p_dni text) TO authenticated;
GRANT ALL ON FUNCTION public.dni_disponible(p_dni text) TO service_role;
GRANT ALL ON FUNCTION public.dni_disponible(p_dni text) TO anon;


--
-- Name: FUNCTION es_admin(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.es_admin() TO authenticated;
GRANT ALL ON FUNCTION public.es_admin() TO service_role;


--
-- Name: FUNCTION es_editor_o_admin(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.es_editor_o_admin() TO authenticated;
GRANT ALL ON FUNCTION public.es_editor_o_admin() TO service_role;


--
-- Name: FUNCTION es_miembro_inscripcion(p_inscripcion uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.es_miembro_inscripcion(p_inscripcion uuid) TO authenticated;
GRANT ALL ON FUNCTION public.es_miembro_inscripcion(p_inscripcion uuid) TO service_role;


--
-- Name: FUNCTION es_miembro_pareja(p_pareja uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.es_miembro_pareja(p_pareja uuid) TO authenticated;
GRANT ALL ON FUNCTION public.es_miembro_pareja(p_pareja uuid) TO service_role;


--
-- Name: FUNCTION es_sistema_o_admin(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.es_sistema_o_admin() TO authenticated;
GRANT ALL ON FUNCTION public.es_sistema_o_admin() TO service_role;


--
-- Name: FUNCTION generar_playoff(p_torneo_categoria uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.generar_playoff(p_torneo_categoria uuid) TO authenticated;
GRANT ALL ON FUNCTION public.generar_playoff(p_torneo_categoria uuid) TO service_role;


--
-- Name: FUNCTION generar_zonas(p_torneo_categoria uuid, p_cantidad_zonas integer, p_aleatorio boolean); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.generar_zonas(p_torneo_categoria uuid, p_cantidad_zonas integer, p_aleatorio boolean) TO authenticated;
GRANT ALL ON FUNCTION public.generar_zonas(p_torneo_categoria uuid, p_cantidad_zonas integer, p_aleatorio boolean) TO service_role;


--
-- Name: FUNCTION handle_new_user(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.handle_new_user() TO authenticated;
GRANT ALL ON FUNCTION public.handle_new_user() TO service_role;


--
-- Name: FUNCTION inscripciones_no_elegibles(p_jugador uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.inscripciones_no_elegibles(p_jugador uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.inscripciones_no_elegibles(p_jugador uuid) TO authenticated;
GRANT ALL ON FUNCTION public.inscripciones_no_elegibles(p_jugador uuid) TO service_role;


--
-- Name: FUNCTION inscripciones_validar(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.inscripciones_validar() TO authenticated;
GRANT ALL ON FUNCTION public.inscripciones_validar() TO service_role;


--
-- Name: FUNCTION intercambiar_parejas_zona(p_ins1 uuid, p_ins2 uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.intercambiar_parejas_zona(p_ins1 uuid, p_ins2 uuid) TO authenticated;
GRANT ALL ON FUNCTION public.intercambiar_parejas_zona(p_ins1 uuid, p_ins2 uuid) TO service_role;


--
-- Name: FUNCTION jugadores_proteger(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.jugadores_proteger() TO authenticated;
GRANT ALL ON FUNCTION public.jugadores_proteger() TO service_role;


--
-- Name: FUNCTION jugadores_validar_categoria(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.jugadores_validar_categoria() TO authenticated;
GRANT ALL ON FUNCTION public.jugadores_validar_categoria() TO service_role;


--
-- Name: FUNCTION marcar_password_cambiada(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.marcar_password_cambiada() FROM PUBLIC;
GRANT ALL ON FUNCTION public.marcar_password_cambiada() TO authenticated;
GRANT ALL ON FUNCTION public.marcar_password_cambiada() TO service_role;


--
-- Name: FUNCTION mi_rol(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.mi_rol() TO authenticated;
GRANT ALL ON FUNCTION public.mi_rol() TO service_role;


--
-- Name: FUNCTION mis_inscripciones(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.mis_inscripciones() TO authenticated;
GRANT ALL ON FUNCTION public.mis_inscripciones() TO service_role;


--
-- Name: FUNCTION nivel_efectivo(p_cat_jugador smallint, p_cat_torneo smallint); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.nivel_efectivo(p_cat_jugador smallint, p_cat_torneo smallint) TO authenticated;
GRANT ALL ON FUNCTION public.nivel_efectivo(p_cat_jugador smallint, p_cat_torneo smallint) TO service_role;


--
-- Name: FUNCTION nombre_fase(p_tamano integer); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.nombre_fase(p_tamano integer) TO authenticated;
GRANT ALL ON FUNCTION public.nombre_fase(p_tamano integer) TO service_role;


--
-- Name: FUNCTION pareja_puede_jugar(p_pareja uuid, p_categoria smallint); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.pareja_puede_jugar(p_pareja uuid, p_categoria smallint) TO authenticated;
GRANT ALL ON FUNCTION public.pareja_puede_jugar(p_pareja uuid, p_categoria smallint) TO service_role;


--
-- Name: FUNCTION parejas_proteger(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.parejas_proteger() TO authenticated;
GRANT ALL ON FUNCTION public.parejas_proteger() TO service_role;


--
-- Name: FUNCTION participaciones(p_jugador uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.participaciones(p_jugador uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.participaciones(p_jugador uuid) TO authenticated;
GRANT ALL ON FUNCTION public.participaciones(p_jugador uuid) TO service_role;


--
-- Name: FUNCTION partidos_cancha_de_sede(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.partidos_cancha_de_sede() FROM PUBLIC;
GRANT ALL ON FUNCTION public.partidos_cancha_de_sede() TO authenticated;
GRANT ALL ON FUNCTION public.partidos_cancha_de_sede() TO service_role;


--
-- Name: FUNCTION partidos_propagar(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.partidos_propagar() TO authenticated;
GRANT ALL ON FUNCTION public.partidos_propagar() TO service_role;


--
-- Name: FUNCTION partidos_resolver_cuadro(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.partidos_resolver_cuadro() TO anon;
GRANT ALL ON FUNCTION public.partidos_resolver_cuadro() TO authenticated;
GRANT ALL ON FUNCTION public.partidos_resolver_cuadro() TO service_role;


--
-- Name: FUNCTION partidos_validar(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.partidos_validar() TO authenticated;
GRANT ALL ON FUNCTION public.partidos_validar() TO service_role;


--
-- Name: FUNCTION posiciones_zona(p_zona uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.posiciones_zona(p_zona uuid) TO authenticated;
GRANT ALL ON FUNCTION public.posiciones_zona(p_zona uuid) TO service_role;


--
-- Name: FUNCTION registrar(p_tipo text, p_movimiento text, p_entidad uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.registrar(p_tipo text, p_movimiento text, p_entidad uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.registrar(p_tipo text, p_movimiento text, p_entidad uuid) TO service_role;


--
-- Name: FUNCTION resolver_cuadro(p_torneo_categoria uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.resolver_cuadro(p_torneo_categoria uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.resolver_cuadro(p_torneo_categoria uuid) TO authenticated;
GRANT ALL ON FUNCTION public.resolver_cuadro(p_torneo_categoria uuid) TO service_role;


--
-- Name: FUNCTION set_unico_valido(a smallint, b smallint, p_games smallint); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.set_unico_valido(a smallint, b smallint, p_games smallint) TO authenticated;
GRANT ALL ON FUNCTION public.set_unico_valido(a smallint, b smallint, p_games smallint) TO service_role;


--
-- Name: FUNCTION set_valido(a smallint, b smallint, p_super boolean); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.set_valido(a smallint, b smallint, p_super boolean) TO authenticated;
GRANT ALL ON FUNCTION public.set_valido(a smallint, b smallint, p_super boolean) TO service_role;


--
-- Name: FUNCTION torneos_proteger_formato(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.torneos_proteger_formato() TO authenticated;
GRANT ALL ON FUNCTION public.torneos_proteger_formato() TO service_role;


--
-- Name: FUNCTION torneos_validar_fechas(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.torneos_validar_fechas() FROM PUBLIC;
GRANT ALL ON FUNCTION public.torneos_validar_fechas() TO service_role;


--
-- Name: FUNCTION touch_updated_at(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.touch_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.touch_updated_at() TO service_role;


--
-- Name: TABLE auditoria; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE public.auditoria TO anon;
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE public.auditoria TO authenticated;
GRANT ALL ON TABLE public.auditoria TO service_role;


--
-- Name: SEQUENCE auditoria_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE public.auditoria_id_seq TO anon;
GRANT ALL ON SEQUENCE public.auditoria_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.auditoria_id_seq TO service_role;


--
-- Name: TABLE canchas; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.canchas TO anon;
GRANT ALL ON TABLE public.canchas TO authenticated;
GRANT ALL ON TABLE public.canchas TO service_role;


--
-- Name: TABLE categorias; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.categorias TO anon;
GRANT ALL ON TABLE public.categorias TO authenticated;
GRANT ALL ON TABLE public.categorias TO service_role;


--
-- Name: SEQUENCE categorias_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE public.categorias_id_seq TO anon;
GRANT ALL ON SEQUENCE public.categorias_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.categorias_id_seq TO service_role;


--
-- Name: TABLE inscripciones; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.inscripciones TO anon;
GRANT ALL ON TABLE public.inscripciones TO authenticated;
GRANT ALL ON TABLE public.inscripciones TO service_role;


--
-- Name: TABLE jugador_categoria_historial; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.jugador_categoria_historial TO anon;
GRANT ALL ON TABLE public.jugador_categoria_historial TO authenticated;
GRANT ALL ON TABLE public.jugador_categoria_historial TO service_role;


--
-- Name: SEQUENCE jugador_categoria_historial_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON SEQUENCE public.jugador_categoria_historial_id_seq TO anon;
GRANT ALL ON SEQUENCE public.jugador_categoria_historial_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.jugador_categoria_historial_id_seq TO service_role;


--
-- Name: TABLE jugadores; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.jugadores TO anon;
GRANT ALL ON TABLE public.jugadores TO authenticated;
GRANT ALL ON TABLE public.jugadores TO service_role;


--
-- Name: TABLE parejas; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.parejas TO anon;
GRANT ALL ON TABLE public.parejas TO authenticated;
GRANT ALL ON TABLE public.parejas TO service_role;


--
-- Name: TABLE sedes; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.sedes TO anon;
GRANT ALL ON TABLE public.sedes TO authenticated;
GRANT ALL ON TABLE public.sedes TO service_role;


--
-- Name: TABLE torneo_categorias; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.torneo_categorias TO anon;
GRANT ALL ON TABLE public.torneo_categorias TO authenticated;
GRANT ALL ON TABLE public.torneo_categorias TO service_role;


--
-- Name: TABLE torneos; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.torneos TO anon;
GRANT ALL ON TABLE public.torneos TO authenticated;
GRANT ALL ON TABLE public.torneos TO service_role;


--
-- Name: TABLE v_parejas; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_parejas TO authenticated;
GRANT ALL ON TABLE public.v_parejas TO service_role;


--
-- Name: TABLE v_inscripciones; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_inscripciones TO authenticated;
GRANT ALL ON TABLE public.v_inscripciones TO service_role;


--
-- Name: TABLE v_jugadores; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_jugadores TO authenticated;
GRANT ALL ON TABLE public.v_jugadores TO service_role;


--
-- Name: TABLE zonas; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.zonas TO anon;
GRANT ALL ON TABLE public.zonas TO authenticated;
GRANT ALL ON TABLE public.zonas TO service_role;


--
-- Name: TABLE v_partidos; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_partidos TO authenticated;
GRANT ALL ON TABLE public.v_partidos TO service_role;


--
-- Name: TABLE v_torneo_categorias; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_torneo_categorias TO authenticated;
GRANT ALL ON TABLE public.v_torneo_categorias TO service_role;


--
-- Name: TABLE zona_parejas; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.zona_parejas TO anon;
GRANT ALL ON TABLE public.zona_parejas TO authenticated;
GRANT ALL ON TABLE public.zona_parejas TO service_role;

-- =====================================================================
--  ALTA DE JUGADORES: trigger sobre auth.users (el dump de public no lo trae)
-- =====================================================================
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =====================================================================
--  CONFIGURACIÓN: sedes, canchas y categorías de El Clásico
-- =====================================================================
insert into public.sedes (id, nombre, direccion, activa, created_at) values
  ('68dec3d0-24b9-47c6-ae44-91267e9e6df5', 'El Clásico', 'Malaspina, Villa Ramallo', 't', '2026-10-01 11:59:44.250647+00'),
  ('56f3ca12-63db-4acf-8881-bb1a8ce88cf4', 'El Clásico 2', null, 't', '2026-10-01 11:59:44.250647+00');

insert into public.canchas (id, sede_id, nombre, orden, activa, created_at) values
  ('3476ae73-e283-4d06-a148-51747269894e', '68dec3d0-24b9-47c6-ae44-91267e9e6df5', 'BX1', '1', 't', '2026-10-01 11:59:44.250647+00'),
  ('9df2e0dd-bc7d-4763-b29c-ba08d14b1de8', '68dec3d0-24b9-47c6-ae44-91267e9e6df5', 'BX2', '2', 't', '2026-10-01 11:59:44.250647+00'),
  ('71464af0-b63d-482b-8cb4-efb1b3206850', '68dec3d0-24b9-47c6-ae44-91267e9e6df5', 'C1', '3', 't', '2026-10-01 11:59:44.250647+00'),
  ('a0ff6475-08f0-4cc1-93ec-3bb40072b652', '56f3ca12-63db-4acf-8881-bb1a8ce88cf4', 'BX1', '1', 't', '2026-10-01 11:59:44.250647+00');

insert into public.categorias (id, nombre, genero, nivel, orden, tipo, suma, activa) values
  ('1', '3ra Caballeros', 'caballeros', '3', '1', 'nivel', null, 't'),
  ('2', '4ta Caballeros', 'caballeros', '4', '2', 'nivel', null, 't'),
  ('3', '5ta Caballeros', 'caballeros', '5', '3', 'nivel', null, 't'),
  ('4', '6ta Caballeros', 'caballeros', '6', '4', 'nivel', null, 't'),
  ('5', '7ma Caballeros', 'caballeros', '7', '5', 'nivel', null, 't'),
  ('6', '4ta Damas', 'damas', '4', '6', 'nivel', null, 't'),
  ('7', '5ta Damas', 'damas', '5', '7', 'nivel', null, 't'),
  ('8', '6ta Damas', 'damas', '6', '8', 'nivel', null, 't'),
  ('9', '7ma Damas', 'damas', '7', '9', 'nivel', null, 't'),
  ('12', 'Suma 10 Caballeros', 'caballeros', null, '110', 'suma', '10', 't'),
  ('13', 'Suma 11 Caballeros', 'caballeros', null, '111', 'suma', '11', 't'),
  ('14', 'Suma 12 Caballeros', 'caballeros', null, '112', 'suma', '12', 't'),
  ('15', 'Suma 13 Caballeros', 'caballeros', null, '113', 'suma', '13', 't'),
  ('21', 'Suma 12 Damas', 'damas', null, '132', 'suma', '12', 't'),
  ('22', 'Suma 13 Damas', 'damas', null, '133', 'suma', '13', 't'),
  ('23', 'Suma 14 Damas', 'damas', null, '134', 'suma', '14', 't'),
  ('26', 'Suma 10 Mixto', 'mixto', null, '150', 'suma', '10', 't'),
  ('28', 'Suma 12 Mixto', 'mixto', null, '152', 'suma', '12', 't'),
  ('29', 'Suma 13 Mixto', 'mixto', null, '153', 'suma', '13', 't'),
  ('10', 'Suma 8 Caballeros', 'caballeros', null, '108', 'suma', '8', 't'),
  ('11', 'Suma 9 Caballeros', 'caballeros', null, '109', 'suma', '9', 't'),
  ('16', 'Suma 14 Caballeros', 'caballeros', null, '114', 'suma', '14', 't'),
  ('17', 'Suma 8 Damas', 'damas', null, '128', 'suma', '8', 't'),
  ('18', 'Suma 9 Damas', 'damas', null, '129', 'suma', '9', 't'),
  ('19', 'Suma 10 Damas', 'damas', null, '130', 'suma', '10', 't'),
  ('20', 'Suma 11 Damas', 'damas', null, '131', 'suma', '11', 't'),
  ('24', 'Suma 8 Mixto', 'mixto', null, '148', 'suma', '8', 't'),
  ('25', 'Suma 9 Mixto', 'mixto', null, '149', 'suma', '9', 't'),
  ('27', 'Suma 11 Mixto', 'mixto', null, '151', 'suma', '11', 't'),
  ('30', 'Suma 14 Mixto', 'mixto', null, '154', 'suma', '14', 't');

select pg_catalog.setval('public.categorias_id_seq', 30, true);

-- =====================================================================
--  CONTROL
-- =====================================================================
select 'tablas' as que, count(*)::text as cantidad from information_schema.tables
  where table_schema = 'public' and table_type = 'BASE TABLE'
union all select 'tablas reservas_* (tiene que ser 0)', count(*)::text from information_schema.tables
  where table_schema = 'public' and table_name like 'reservas%'
union all select 'funciones', count(*)::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public'
union all select 'funciones reservas_* (tiene que ser 0)', count(*)::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname like 'reservas%'
union all select 'categorías', count(*)::text from public.categorias
union all select 'sedes', string_agg(nombre, ', ' order by nombre) from public.sedes
union all select 'canchas', count(*)::text from public.canchas
union all select 'trigger alta de jugadores', count(*)::text from pg_trigger where tgname = 'on_auth_user_created';

commit;