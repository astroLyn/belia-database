--Proceso para registar un cliente
CREATE OR REPLACE FUNCTION sp_registrar_cliente_iot(
    p_nombre_completo VARCHAR,
    p_telefono VARCHAR
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_cliente INT;
BEGIN
    INSERT INTO clientes (nombre_completo, telefono)
    VALUES (TRIM(p_nombre_completo), TRIM(p_telefono))
    ON CONFLICT (telefono) 
    DO UPDATE SET nombre_completo = EXCLUDED.nombre_completo
    RETURNING id_cliente INTO v_id_cliente;
    RETURN v_id_cliente;
END;
$$;
SELECT sp_registrar_cliente_iot('Carlos Mendoza', '6641112233') AS id_cliente_asignado;
--Proceso para crear una cita desde el agente IoT
CREATE OR REPLACE FUNCTION sp_crear_cita_iot_dinamica(
    p_cliente_id INT,
    p_servicio_id INT,
    p_fecha_hora_inicio TIMESTAMP,
    p_empleado_id INT DEFAULT NULL, -- Parámetro opcional de entrada
    OUT r_id_cita INT,              -- Parámetro de salida 1
    OUT r_empleado_asignado INT     -- Parámetro de salida 2
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_duracion SMALLINT;
    v_fecha_hora_fin TIMESTAMP;
    v_estado_pendiente_id INT;
    v_empalmes INT;
BEGIN
    -- 1. Calcular la duración y la hora exacta de fin
    SELECT duracion_estimada INTO v_duracion
    FROM servicios
    WHERE id_servicio = p_servicio_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El servicio especificado no existe en el catálogo.';
    END IF;
    v_fecha_hora_fin := p_fecha_hora_inicio + (v_duracion || ' minutes')::interval;
    r_empleado_asignado := NULL;
    -- 2. Intento A: Si el cliente solicitó un estilista en específico
    IF p_empleado_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_empalmes
        FROM citas c
        JOIN estado e ON c.estado_id = e.id_estado
        WHERE c.empleado_id = p_empleado_id
          AND e.nombre != 'Cancelada'
          AND (p_fecha_hora_inicio < c.fecha_hora_fin AND v_fecha_hora_fin > c.fecha_hora_inicio);
        -- Si el estilista está libre, se le asigna. Si está ocupado, la variable sigue siendo NULL.
        IF v_empalmes = 0 THEN
            r_empleado_asignado := p_empleado_id;
        END IF;
    END IF;
    -- 3. Intento B: El escenario que mencionas (No pidió a nadie o el que pidió estaba ocupado)
    IF r_empleado_asignado IS NULL THEN
        SELECT e.id_empleado INTO r_empleado_asignado
        FROM empleado e
        JOIN horarios h ON e.id_empleado = h.empleado_id
        WHERE h.dia = EXTRACT(DOW FROM p_fecha_hora_inicio)::SMALLINT
          AND p_fecha_hora_inicio::time >= h.hora_entrada
          AND v_fecha_hora_fin::time <= h.hora_salida
          AND NOT EXISTS (
              SELECT 1
              FROM citas c
              JOIN estado es ON c.estado_id = es.id_estado
              WHERE c.empleado_id = e.id_empleado
                AND es.nombre != 'Cancelada'
                AND (p_fecha_hora_inicio < c.fecha_hora_fin AND v_fecha_hora_fin > c.fecha_hora_inicio)
          )
        ORDER BY (
            SELECT COUNT(*)
            FROM citas c2
            JOIN estado es2 ON c2.estado_id = es2.id_estado
            WHERE c2.empleado_id = e.id_empleado
              AND es2.nombre != 'Cancelada'
              AND DATE(c2.fecha_hora_inicio) = DATE(p_fecha_hora_inicio)
        ) ASC
        LIMIT 1;
    END IF;
    -- 4. Si después del filtro el ID sigue nulo, el salón está lleno en ese horario
    IF r_empleado_asignado IS NULL THEN
        RAISE EXCEPTION 'No hay ningún estilista disponible en ese horario.';
    END IF;
    -- 5. Insertar la nueva cita
    INSERT INTO citas (
        empleado_id, 
        servicio_id, 
        cliente_id, 
        fecha_hora_inicio, 
        fecha_hora_fin, 
        estado_id
    ) VALUES (
        r_empleado_asignado,
        p_servicio_id,
        p_cliente_id,
        p_fecha_hora_inicio,
        v_fecha_hora_fin,
        1
    )
    RETURNING id_cita INTO r_id_cita;
END;
$$;
--El empleado 1 está libre el 15 de octubre a las 11:00 am, ya que su cita anterior termina a las 10:45 am.
SELECT * FROM sp_crear_cita_iot_dinamica(
    p_cliente_id := 2, 
    p_servicio_id := 1, 
    p_fecha_hora_inicio := '2026-10-16 11:00:00', 
    p_empleado_id := 1
);
--Se intenta agendar a las 10:20 am. El empleado 1 ya tiene una cita de 10:00 a 10:45 am.
SELECT * FROM sp_crear_cita_iot_dinamica(
    p_cliente_id := 2, 
    p_servicio_id := 1, 
    p_fecha_hora_inicio := '2026-10-16 10:20:00', 
    p_empleado_id := 1
);
--El cliente llama al agente IoT, pero no pide a nadie en particular. Se intenta agendar a las 2:00 pm. El motor buscará quién trabaja ese día y está libre.
SELECT * FROM sp_crear_cita_iot_dinamica(
    p_cliente_id := 2, 
    p_servicio_id := 1, 
    p_fecha_hora_inicio := '2026-10-16 14:00:00'
);
--El empleado 1 trabaja estrictamente de 09:00:00 a 17:00:00. Se intenta agendar una cita a las 08:00 am
SELECT * FROM sp_crear_cita_iot_dinamica(
    p_cliente_id := 2, 
    p_servicio_id := 1, 
    p_fecha_hora_inicio := '2026-10-15 08:00:00'
);
--El empleado 1 trabaja en los días 1 a 5 (lunes a viernes). Se intenta agendar el 18 de octubre de 2026
SELECT * FROM sp_crear_cita_iot_dinamica(
    p_cliente_id := 2, 
    p_servicio_id := 1, 
    p_fecha_hora_inicio := '2026-10-18 12:00:00'
);