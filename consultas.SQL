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

--INFO EMPLEADOS--
CREATE OR REPLACE VIEW vw_directorio_empleados AS
SELECT 
    e.id_empleado,
    e.nombre_completo AS empleado,
    e.rol,
    e.especialidad,
    e.telefono,
    e.correo,
    -- Extrae la hora de entrada y salida formateada a HH:MM
    (
        SELECT TO_CHAR(MIN(h.hora_entrada), 'HH24:MI') || ' - ' || TO_CHAR(MAX(h.hora_salida), 'HH24:MI')
        FROM horarios h
        WHERE h.empleado_id = e.id_empleado
    ) AS horario_resumen
FROM empleado e
ORDER BY e.nombre_completo ASC;
SELECT * FROM vw_directorio_empleados;