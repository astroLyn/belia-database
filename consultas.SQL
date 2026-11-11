--LOGIN--
CREATE OR REPLACE FUNCTION sp_iniciar_sesion(
    p_correo VARCHAR
) RETURNS TABLE (
    id_usuario INT,
    nombre_completo VARCHAR,
    rol VARCHAR,
    password_hash VARCHAR,
    estado VARCHAR
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.id_empleado AS id_usuario,
        e.nombre_completo,
        e.rol,
        e.password AS password_hash,
        es.nombre::VARCHAR AS estado
    FROM empleado e
    JOIN estado es ON e.estado_id = es.id_estado
    WHERE e.correo = TRIM(p_correo)
      -- Una medida de seguridad vital: solo permitir acceso a personal activo
      AND es.nombre = 'Activo'; 
END;
$$;
SELECT * FROM sp_iniciar_sesion(p_correo := 'mariana.silva@belia.com');

--DASHBOARDS--
--Vista para los Indicadores Superiores
CREATE OR REPLACE VIEW vw_dashboard_kpis AS
SELECT 
    -- Tarjeta 1: Citas totales y confirmadas de hoy
    (SELECT COUNT(*) FROM citas WHERE DATE(fecha_hora_inicio) = CURRENT_DATE) AS citas_totales_hoy,
    (SELECT COUNT(*) FROM citas c JOIN estado e ON c.estado_id = e.id_estado WHERE DATE(c.fecha_hora_inicio) = CURRENT_DATE AND e.nombre = 'Confirmada') AS citas_confirmadas_hoy,
    COALESCE((
        SELECT SUM(s.duracion_estimada) / 60.0 
        FROM citas c
        JOIN servicios s ON c.servicio_id = s.id_servicio
        WHERE DATE(c.fecha_hora_inicio) = CURRENT_DATE
        AND c.estado_id NOT IN (SELECT id_estado FROM estado WHERE nombre = 'Cancelada')
    ), 0) AS horas_agendadas_hoy,
    (SELECT COUNT(*) FROM clientes) AS clientes_activos_total,
    (SELECT COUNT(DISTINCT cliente_id) FROM citas WHERE EXTRACT(WEEK FROM fecha_hora_inicio) = EXTRACT(WEEK FROM CURRENT_DATE)) AS clientes_esta_semana,
    (SELECT COUNT(*) FROM inventario WHERE cantidad_existente <= 10) AS alertas_stock;
SELECT * FROM vw_dashboard_kpis;

--Vista para el Panel de Inventario General
CREATE OR REPLACE VIEW vw_dashboard_inventario AS
SELECT 
    i.id_producto,
    i.nombre AS producto,
    c.nombre AS categoria,
    p.nombre AS presentacion,
    um.nombre AS unidad,
    i.cantidad_existente,
    CASE 
        WHEN i.cantidad_existente <= 3 THEN 'Crítico' 
        WHEN i.cantidad_existente <= 10 THEN 'Bajo'   
        ELSE 'Óptimo'                                 
    END AS estado_stock
FROM inventario i
JOIN categorias c ON i.categoria_id = c.id_categoria
LEFT JOIN presentacion p ON i.presentacion_id = p.id_presentacion
LEFT JOIN unidad_medida um ON i.unidad_id = um.id_unidad
ORDER BY i.cantidad_existente ASC;

SELECT * FROM vw_dashboard_inventario;

--Vista para la Agenda Global del Salón
CREATE OR REPLACE VIEW vw_dashboard_agenda_hoy AS
SELECT 
    c.id_cita,
    c.fecha_hora_inicio::time AS hora_inicio,
    c.fecha_hora_fin::time AS hora_fin,
    s.nombre AS servicio,
    cl.nombre_completo AS cliente,
    e.nombre_completo AS estilista,
    es.nombre AS estado
FROM citas c
JOIN servicios s ON c.servicio_id = s.id_servicio
JOIN clientes cl ON c.cliente_id = cl.id_cliente
JOIN empleado e ON c.empleado_id = e.id_empleado
JOIN estado es ON c.estado_id = es.id_estado
WHERE DATE(c.fecha_hora_inicio) = CURRENT_DATE
ORDER BY c.fecha_hora_inicio ASC;
SELECT * FROM vw_dashboard_agenda_hoy;

--SERVICIOS--
--Vista para el Catálogo de Servicios
CREATE OR REPLACE VIEW vw_catalogo_servicios AS
SELECT 
    s.id_servicio,
    s.nombre AS servicio,
    s.notas_detalles AS descripcion,
    c.nombre AS categoria,
    s.precio,
    e.nombre AS estado
FROM servicios s
JOIN categorias c ON s.categoria_id = c.id_categoria
JOIN estado e ON s.estado_id = e.id_estado
ORDER BY c.nombre ASC, s.nombre ASC;
SELECT * FROM vw_catalogo_servicios;

--Vista para el Catálogo de Paquetes
CREATE OR REPLACE VIEW vw_catalogo_paquetes AS
SELECT 
    p.id_paquete,
    p.nombre AS paquete,
    p.descripcion,
    p.precio,
    p.fecha_inicio,
    p.fecha_fin,
    e.nombre AS estado,
    (
        SELECT string_agg(s.nombre, ', ') 
        FROM paquete_servicios ps 
        JOIN servicios s ON ps.id_servicio = s.id_servicio 
        WHERE ps.id_paquete = p.id_paquete
    ) AS servicios_incluidos
FROM paquetes p
JOIN estado e ON p.estado_id = e.id_estado
ORDER BY p.id_paquete ASC;
SELECT * FROM vw_catalogo_paquetes;

--Procedimiento Almacenado: Guardar Promoción Completa
CREATE OR REPLACE FUNCTION sp_crear_paquete_promocion(
    p_nombre VARCHAR,
    p_descripcion TEXT,
    p_precio NUMERIC,
    p_fecha_inicio DATE,
    p_fecha_fin DATE,
    p_estado_id INT,
    p_servicios_ids INT[]
) RETURNS INT 
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_paquete INT;
    v_servicio_id INT;
BEGIN
    INSERT INTO paquetes (nombre, descripcion, precio, fecha_inicio, fecha_fin, estado_id)
    VALUES (p_nombre, p_descripcion, p_precio, p_fecha_inicio, p_fecha_fin, p_estado_id)
    RETURNING id_paquete INTO v_id_paquete;

    IF p_servicios_ids IS NOT NULL THEN
        FOREACH v_servicio_id IN ARRAY p_servicios_ids
        LOOP
            INSERT INTO paquete_servicios (id_paquete, id_servicio)
            VALUES (v_id_paquete, v_servicio_id);
        END LOOP;
    END IF;

    RETURN v_id_paquete;
END;
$$;
SELECT sp_crear_paquete_promocion(
    'Glow de temporada', 
    'Limpieza facial y diseño de cejas.', 
    899.00, 
    '2026-11-01', 
    '2026-11-30', 
    1, 
    ARRAY[1, 2]::INT[]
);

--Procedimiento Almacenado: Guardar Servicio Completo
CREATE OR REPLACE FUNCTION sp_crear_servicio(
    p_nombre VARCHAR,
    p_categoria_id INT,
    p_precio NUMERIC,
    p_duracion_estimada INT,
    p_notas_detalles TEXT,
    p_estado_id INT
) RETURNS INT 
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_servicio INT;
BEGIN
    IF p_precio < 0 THEN
        RAISE EXCEPTION 'El precio del servicio no puede ser negativo.';
    END IF;
    
    IF p_duracion_estimada <= 0 THEN
        RAISE EXCEPTION 'La duración estimada debe ser mayor a 0 minutos.';
    END IF;

    INSERT INTO servicios (
        nombre, 
        categoria_id, 
        precio, 
        duracion_estimada, 
        notas_detalles, 
        estado_id
    ) VALUES (
        TRIM(p_nombre),
        p_categoria_id,
        p_precio,
        p_duracion_estimada,
        TRIM(p_notas_detalles),
        p_estado_id
    )
    RETURNING id_servicio INTO v_id_servicio;
    RETURN v_id_servicio;
END;
$$;
SELECT sp_crear_servicio(
    p_nombre := 'Lifting de pestañas', 
    p_categoria_id := 3, 
    p_precio := 650.00, 
    p_duracion_estimada := 45,
    p_notas_detalles := 'Curvatura y tinte semipermanente', 
    p_estado_id := 1
);

--INVENTARIO--
--Vista para el Catálogo de Inventario
CREATE OR REPLACE VIEW vw_tabla_inventario AS
SELECT 
    i.id_producto,
    i.imagen_url,
    i.nombre AS producto,
    p.nombre || ' ' || um.nombre AS presentacion_unidad,
    i.cantidad_existente AS cantidad_disponible,
    c.nombre AS categoria,
    CASE 
        WHEN i.cantidad_existente <= 3 THEN 'Crítico' 
        WHEN i.cantidad_existente <= 10 THEN 'Bajo'   
        ELSE 'Óptimo'                                 
    END AS estado_stock
FROM inventario i
JOIN categorias c ON i.categoria_id = c.id_categoria
LEFT JOIN presentacion p ON i.presentacion_id = p.id_presentacion
LEFT JOIN unidad_medida um ON i.unidad_id = um.id_unidad
ORDER BY i.cantidad_existente ASC;
select * from vw_tabla_inventario;

--Procedimiento Almacenado: Agregar Producto al Inventario
CREATE OR REPLACE FUNCTION sp_crear_producto_inventario(
    p_nombre VARCHAR,
    p_categoria_id INT,
    p_presentacion_id INT,
    p_unidad_id INT,
    p_cantidad_existente NUMERIC,
    p_imagen_url TEXT DEFAULT NULL
) RETURNS INT 
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_producto INT;
BEGIN
    -- Validaciones
    IF p_cantidad_existente < 0 THEN
        RAISE EXCEPTION 'El stock inicial no puede ser negativo.';
    END IF;
        INSERT INTO inventario (
        nombre, 
        categoria_id, 
        presentacion_id, 
        unidad_id, 
        cantidad_existente, 
        imagen_url
    ) VALUES (
        TRIM(p_nombre),
        p_categoria_id,
        p_presentacion_id,
        p_unidad_id,
        p_cantidad_existente,
        p_imagen_url
    )
    RETURNING id_producto INTO v_id_producto;

    RETURN v_id_producto;
END;
$$;
SELECT sp_crear_producto_inventario(
    p_nombre := 'Aceite de Argán Premium',
    p_categoria_id := 1,
    p_presentacion_id := 3,
    p_unidad_id := 2,
    p_cantidad_existente := 24,
    p_imagen_url := 'https://ejemplo.com/aceite_argan.png'
);

--EMPLEADOS--
--Vista para el Directorio de Empleados
CREATE VIEW vw_directorio_empleados AS
SELECT 
    e.id_empleado,
    e.nombre_completo AS empleado,
    e.telefono,
    e.correo,
    e.especialidad,
    (
        SELECT 
            CASE MIN(h.dia) WHEN 1 THEN 'Lun' WHEN 2 THEN 'Mar' WHEN 3 THEN 'Mié' WHEN 4 THEN 'Jue' WHEN 5 THEN 'Vie' WHEN 6 THEN 'Sáb' WHEN 0 THEN 'Dom' END || ' - ' ||
            CASE MAX(h.dia) WHEN 1 THEN 'Lun' WHEN 2 THEN 'Mar' WHEN 3 THEN 'Mié' WHEN 4 THEN 'Jue' WHEN 5 THEN 'Vie' WHEN 6 THEN 'Sáb' WHEN 0 THEN 'Dom' END || ' · ' ||
            TO_CHAR(MIN(h.hora_entrada), 'HH24:MI') || ' - ' || TO_CHAR(MAX(h.hora_salida), 'HH24:MI')
        FROM horarios h
        WHERE h.empleado_id = e.id_empleado
    ) AS horario_resumen,
    es.nombre AS estado
FROM empleado e
JOIN estado es ON e.estado_id = es.id_estado
WHERE es.nombre != 'Cancelada'
ORDER BY e.nombre_completo ASC;
SELECT * FROM vw_directorio_empleados;

--Agregar un nuevo empleado
CREATE OR REPLACE FUNCTION sp_crear_empleado(
    p_nombre_completo VARCHAR,
    p_telefono VARCHAR,
    p_correo VARCHAR,
    p_especialidad VARCHAR,
    p_rol VARCHAR,
    p_dias_laborales SMALLINT[], 
    p_hora_entrada TIME,
    p_hora_salida TIME
) RETURNS INT 
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_empleado INT;
    v_dia SMALLINT;
BEGIN
    IF p_hora_entrada >= p_hora_salida THEN
        RAISE EXCEPTION 'La hora de entrada debe ser anterior a la hora de salida.';
    END IF;
    INSERT INTO empleado (nombre_completo, telefono, correo, especialidad, rol, password, estado_id)
    VALUES (
        TRIM(p_nombre_completo), 
        TRIM(p_telefono), 
        TRIM(p_correo), 
        p_especialidad, 
        TRIM(p_rol),
        'por_definir', 
        1
    )
    RETURNING id_empleado INTO v_id_empleado;

    IF p_dias_laborales IS NOT NULL THEN
        FOREACH v_dia IN ARRAY p_dias_laborales
        LOOP
            INSERT INTO horarios (empleado_id, dia, hora_entrada, hora_salida)
            VALUES (v_id_empleado, v_dia, p_hora_entrada, p_hora_salida);
        END LOOP;
    END IF;

    RETURN v_id_empleado;
END;
$$;
SELECT sp_crear_empleado(
    p_nombre_completo := 'Valeria Torres',
    p_telefono := '6641122334',
    p_correo := 'valeria@belia.com',
    p_especialidad := 'Estilista senior (Cabello)',
    p_dias_laborales := ARRAY[1, 2, 3, 4, 5]::SMALLINT[],
    p_hora_entrada := '09:00:00',
    p_hora_salida := '18:00:00'
);
SELECT sp_crear_empleado(
    p_nombre_completo := 'Camila Rojas',
    p_telefono := '6649988776',
    p_correo := 'camila@belia.com',
    p_especialidad := 'Especialista en mirada',
    p_dias_laborales := ARRAY[5, 6, 0]::SMALLINT[],
    p_hora_entrada := '10:00:00',
    p_hora_salida := '15:00:00'
); 

--Editar información de un empleado
CREATE OR REPLACE FUNCTION sp_editar_empleado(
    p_id_empleado INT,
    p_nombre_completo VARCHAR,
    p_telefono VARCHAR,
    p_correo VARCHAR,
    p_especialidad VARCHAR,
    p_estado_id INT,
    p_dias_laborales SMALLINT[],
    p_hora_entrada TIME,
    p_hora_salida TIME
) RETURNS VOID 
LANGUAGE plpgsql
AS $$
DECLARE
    v_dia SMALLINT;
BEGIN
    IF p_hora_entrada >= p_hora_salida THEN
        RAISE EXCEPTION 'La hora de entrada debe ser anterior a la hora de salida.';
    END IF;
    UPDATE empleado
    SET nombre_completo = TRIM(p_nombre_completo),
        telefono = TRIM(p_telefono),
        correo = TRIM(p_correo),
        especialidad = p_especialidad,
        estado_id = p_estado_id
    WHERE id_empleado = p_id_empleado;
    DELETE FROM horarios WHERE empleado_id = p_id_empleado;
    IF p_dias_laborales IS NOT NULL THEN
        FOREACH v_dia IN ARRAY p_dias_laborales
        LOOP
            INSERT INTO horarios (empleado_id, dia, hora_entrada, hora_salida)
            VALUES (p_id_empleado, v_dia, p_hora_entrada, p_hora_salida);
        END LOOP;
    END IF;
END;
$$;
SELECT sp_editar_empleado(
    p_id_empleado := 1,
    p_nombre_completo := 'Mariana Silva',
    p_telefono := '55 1298 7781',
    p_correo := 'mariana.silva@belia.com',
    p_especialidad := 'Colorista experta',
    p_estado_id := 1,
    p_dias_laborales := ARRAY[2, 3, 4, 5, 6]::SMALLINT[],
    p_hora_entrada := '10:00:00',
    p_hora_salida := '19:00:00'
);

--"Desactivar un empleado" (cambiar su estado a Pendiente)
CREATE OR REPLACE FUNCTION sp_desactivar_empleado(p_id_empleado INT) 
RETURNS VOID 
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE empleado 
    SET estado_id = 2 
    WHERE id_empleado = p_id_empleado;
    DELETE FROM horarios WHERE empleado_id = p_id_empleado;
END;
$$;
SELECT sp_desactivar_empleado(p_id_empleado := 3);

--"Eliminar a un empleado" (cambiar su estado a Inactivo y quita su vista de la tabla principal)
CREATE OR REPLACE FUNCTION sp_eliminar_empleado(p_id_empleado INT) 
RETURNS VOID 
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE empleado 
    SET estado_id = 5 
    WHERE id_empleado = p_id_empleado;
    DELETE FROM horarios WHERE empleado_id = p_id_empleado;
END;
$$;

--Reactivar a un empleado (cambiar su estado a Activo y reestablecer su horario)
CREATE OR REPLACE FUNCTION sp_reactivar_empleado(
    p_id_empleado INT,
    p_dias_laborales SMALLINT[],
    p_hora_entrada TIME,
    p_hora_salida TIME
) RETURNS VOID 
LANGUAGE plpgsql
AS $$
DECLARE
    v_dia SMALLINT;
BEGIN
    IF p_hora_entrada >= p_hora_salida THEN
        RAISE EXCEPTION 'La hora de entrada debe ser anterior a la hora de salida.';
    END IF;
    UPDATE empleado 
    SET estado_id = 1 
    WHERE id_empleado = p_id_empleado;
    DELETE FROM horarios WHERE empleado_id = p_id_empleado;
    IF p_dias_laborales IS NOT NULL THEN
        FOREACH v_dia IN ARRAY p_dias_laborales
        LOOP
            INSERT INTO horarios (empleado_id, dia, hora_entrada, hora_salida)
            VALUES (p_id_empleado, v_dia, p_hora_entrada, p_hora_salida);
        END LOOP;
    END IF;
END;
$$;
SELECT sp_reactivar_empleado(
    p_id_empleado := 3,
    p_dias_laborales := ARRAY[3, 4, 5, 6, 0]::SMALLINT[], -- 3=Mié, 4=Jue, 5=Vie, 6=Sáb, 0=Dom
    p_hora_entrada := '10:00:00',
    p_hora_salida := '17:00:00'
);

--Historial de servicios realizados por un empleado
CREATE OR REPLACE VIEW vw_historial_empleado AS
SELECT 
    c.id_cita,
    c.empleado_id,
    s.nombre AS servicio,
    cat.nombre AS categoria,
    es.nombre AS estado_cita,
    s.precio,
    CASE 
        WHEN DATE(c.fecha_hora_inicio) = CURRENT_DATE THEN 'Hoy'
        ELSE TO_CHAR(c.fecha_hora_inicio, 'DD mon YYYY')
    END || ', ' || TO_CHAR(c.fecha_hora_inicio, 'HH24:MI') || ' - ' || TO_CHAR(c.fecha_hora_fin, 'HH24:MI') || ' hrs' AS fecha_horario,
    cl.nombre_completo AS cliente_atendido,
    cl.telefono AS telefono_cliente,
    -- Si tuvieras un campo de especificaciones por cita, iría aquí. Por ahora usamos las notas del servicio.
    s.notas_detalles AS especificacion 
FROM citas c
JOIN servicios s ON c.servicio_id = s.id_servicio
JOIN categorias cat ON s.categoria_id = cat.id_categoria
JOIN estado es ON c.estado_id = es.id_estado
JOIN clientes cl ON c.cliente_id = cl.id_cliente
ORDER BY c.fecha_hora_inicio DESC;
SELECT * FROM vw_historial_empleado;

--CLIENTES--
--Vista para el Directorio de Clientes
CREATE OR REPLACE VIEW vw_directorio_clientes AS
SELECT 
    cl.id_cliente,
    cl.nombre_completo AS cliente,
    cl.telefono,
    cl.correo,
    (
        SELECT s.nombre 
        FROM citas c 
        JOIN servicios s ON c.servicio_id = s.id_servicio 
        WHERE c.cliente_id = cl.id_cliente 
          AND c.estado_id NOT IN (SELECT id_estado FROM estado WHERE nombre = 'Cancelada')
        ORDER BY c.fecha_hora_inicio DESC 
        LIMIT 1
    ) AS ultimo_servicio,
    (
        SELECT TO_CHAR(c.fecha_hora_inicio, 'DD mon YYYY, HH24:MI')
        FROM citas c 
        WHERE c.cliente_id = cl.id_cliente 
          AND c.estado_id NOT IN (SELECT id_estado FROM estado WHERE nombre = 'Cancelada')
        ORDER BY c.fecha_hora_inicio DESC 
        LIMIT 1
    ) AS ultima_visita,
    es.nombre AS estado
FROM clientes cl
JOIN estado es ON cl.estado_id = es.id_estado
WHERE es.nombre = 'Activo'
ORDER BY cl.nombre_completo ASC;
SELECT * FROM vw_directorio_clientes;

--Proceso para la creación de un nuevo cliente
CREATE OR REPLACE FUNCTION sp_crear_o_reactivar_cliente(
    p_nombre_completo VARCHAR,
    p_telefono VARCHAR,
    p_correo VARCHAR,
    p_notas_preferencias TEXT,
    p_servicio_id INT DEFAULT NULL,
    p_empleado_id INT DEFAULT NULL,
    p_fecha_hora_visita TIMESTAMP DEFAULT NULL
) RETURNS INT 
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_cliente INT;
    v_estado_actual INT;
BEGIN
    SELECT id_cliente, estado_id INTO v_id_cliente, v_estado_actual 
    FROM clientes 
    WHERE telefono = TRIM(p_telefono);

    IF FOUND THEN
        UPDATE clientes 
        SET nombre_completo = TRIM(p_nombre_completo),
            correo = TRIM(p_correo),
            notas_preferencias = TRIM(p_notas_preferencias),
            estado_id = 1
        WHERE id_cliente = v_id_cliente;
    ELSE
        INSERT INTO clientes (nombre_completo, telefono, correo, notas_preferencias, estado_id)
        VALUES (TRIM(p_nombre_completo), TRIM(p_telefono), TRIM(p_correo), TRIM(p_notas_preferencias), 1)
        RETURNING id_cliente INTO v_id_cliente;
    END IF;

    IF p_servicio_id IS NOT NULL AND p_empleado_id IS NOT NULL AND p_fecha_hora_visita IS NOT NULL THEN
        INSERT INTO citas (empleado_id, servicio_id, cliente_id, fecha_hora_inicio, fecha_hora_fin, estado_id)
        SELECT p_empleado_id, p_servicio_id, v_id_cliente, p_fecha_hora_visita, 
               p_fecha_hora_visita + (duracion_estimada || ' minutes')::interval, 1
        FROM servicios WHERE id_servicio = p_servicio_id;
    END IF;

    RETURN v_id_cliente;
END;
$$;
SELECT sp_crear_o_reactivar_cliente(
    p_nombre_completo := 'Sofía Mendoza',
    p_telefono := '5512346678',
    p_correo := 'sofia.m@email.com',
    p_notas_preferencias := 'Prefiere productos libres de sulfatos y secado con temperatura media.'
);
SELECT sp_crear_o_reactivar_cliente(
    p_nombre_completo := 'Camila Ruiz',
    p_telefono := '5534679012',
    p_correo := 'camila.r@email.com',
    p_notas_preferencias := 'Alergia al acrílico, prefiere gelish.',
    p_servicio_id := 2, -- Asumiendo que 2 es "Manicura Gelish"
    p_empleado_id := 2, -- Asumiendo que 2 es "Laura Manicurista"
    p_fecha_hora_visita := '2026-11-15 10:30:00'
);
SELECT sp_crear_o_reactivar_cliente(
    p_nombre_completo := 'Sofía Mendoza',
    p_telefono := '5512346678', -- Este teléfono es la llave mágica
    p_correo := 'sofia.nuevo@email.com',
    p_notas_preferencias := 'Cliente reactivada. Regresó al salón.'
);

-- Procedimiento para editar cliente
CREATE OR REPLACE FUNCTION sp_editar_cliente(
    p_id_cliente INT,
    p_nombre_completo VARCHAR,
    p_telefono VARCHAR,
    p_correo VARCHAR,
    p_notas_preferencias TEXT
) RETURNS VOID 
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE clientes 
    SET nombre_completo = TRIM(p_nombre_completo),
        telefono = TRIM(p_telefono),
        correo = TRIM(p_correo),
        notas_preferencias = TRIM(p_notas_preferencias)
    WHERE id_cliente = p_id_cliente;
END;
$$;
SELECT sp_editar_cliente(
    p_id_cliente := 5,
    p_nombre_completo := 'Sofía Mendoza',
    p_telefono := '5512346678',
    p_correo := 'sofia.nuevo@email.com', -- Correo actualizado
    p_notas_preferencias := 'Prefiere productos libres de sulfatos. Ojo: Sensibilidad en cuero cabelludo.'
);

--"Eliminar" a un cliente (cambia su estado a Inactivo)
CREATE OR REPLACE FUNCTION sp_eliminar_cliente(p_id_cliente INT) 
RETURNS VOID 
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE clientes 
    SET estado_id = 2 
    WHERE id_cliente = p_id_cliente;
END;
$$;
SELECT sp_eliminar_cliente(p_id_cliente := 5);

--Vista para el Historial de Servicios de un Cliente
CREATE OR REPLACE VIEW vw_historial_cliente AS
SELECT 
    c.id_cita,
    c.cliente_id,
    s.nombre AS servicio,
    cat.nombre AS categoria,
    es.nombre AS estado_cita,
    s.precio,
    CASE 
        WHEN DATE(c.fecha_hora_inicio) = CURRENT_DATE THEN 'Hoy'
        ELSE TO_CHAR(c.fecha_hora_inicio, 'DD mon YYYY')
    END || ', ' || TO_CHAR(c.fecha_hora_inicio, 'HH24:MI') || ' - ' || TO_CHAR(c.fecha_hora_fin, 'HH24:MI') || ' hrs' AS fecha_horario,
    e.nombre_completo AS empleado_atendio,
    s.notas_detalles AS especificacion
FROM citas c
JOIN servicios s ON c.servicio_id = s.id_servicio
JOIN categorias cat ON s.categoria_id = cat.id_categoria
JOIN estado es ON c.estado_id = es.id_estado
JOIN empleado e ON c.empleado_id = e.id_empleado
ORDER BY c.fecha_hora_inicio DESC;
SELECT * FROM vw_historial_cliente;