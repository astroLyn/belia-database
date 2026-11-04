--1. Agenda diaria de citas
-- Muestra todas las citas programadas para el día actual, incluyendo detalles del cliente, servicio
SELECT 
    c.id_cita, 
    c.fecha_hora_inicio::time AS hora_inicio, 
    cl.nombre_completo AS cliente, 
    s.nombre AS servicio, 
    e.nombre_completo AS atendido_por, 
    es.nombre AS estado
FROM citas c
JOIN clientes cl ON c.cliente_id = cl.id_cliente
JOIN servicios s ON c.servicio_id = s.id_servicio
JOIN empleado e ON c.empleado_id = e.id_empleado
JOIN estado es ON c.estado_id = es.id_estado
WHERE DATE(c.fecha_hora_inicio) = CURRENT_DATE
ORDER BY c.fecha_hora_inicio ASC;

--2. Historial de servicios por cliente
--Extrae todos los servicios que un cliente específico ha recibido en el pasado, útil para la retención y seguimiento.
SELECT 
    c.fecha_hora_inicio::date AS fecha, 
    s.nombre AS servicio_realizado, 
    e.nombre_completo AS estilista, 
    es.nombre AS estado
FROM citas c
JOIN servicios s ON c.servicio_id = s.id_servicio
JOIN empleado e ON c.empleado_id = e.id_empleado
JOIN estado es ON c.estado_id = es.id_estado
WHERE c.cliente_id = 1 
  AND es.nombre IN ('Completada', 'Cancelada')
ORDER BY c.fecha_hora_inicio DESC;

--3. Alerta de inventario bajo
--Filtra los insumos que están por agotarse para que la administradora sepa exactamente qué productos resurtir.
SELECT 
    i.nombre AS producto, 
    i.cantidad_existente, 
    i.unidad, 
    cat.nombre AS categoria
FROM inventario i
JOIN categorias cat ON i.categoria_id = cat.id_categoria
WHERE i.cantidad_existente <= 10.00
ORDER BY i.cantidad_existente ASC;

--4. Validación de empalme de horarios
--Esta es la consulta lógica que utilizará tu backend en FastAPI o el agente loT para verificar si un empleado ya tiene una cita asignada en el bloque de tiempo solicitado antes de insertar una nueva.
SELECT 
    id_cita, 
    fecha_hora_inicio, 
    fecha_hora_fin, 
    estado_id
FROM citas
WHERE empleado_id = 1
  AND estado_id NOT IN (SELECT id_estado FROM estado WHERE nombre = 'Cancelada')
  AND (
      ('2026-10-15 10:30:00' < fecha_hora_fin) AND 
      ('2026-10-15 11:15:00' > fecha_hora_inicio)
  );

--5. Catálogo de paquetes promocionales activos
--Muestra los paquetes disponibles junto con los servicios exactos que incluye cada uno, conectando la tabla pivote de relaciones muchos a muchos.
SELECT 
    p.descripcion AS paquete, 
    p.precio AS precio_total, 
    p.vigencia, 
    s.nombre AS servicio_incluido, 
    ps.notas AS restricciones
FROM paquetes p
JOIN paquete_servicios ps ON p.id_paquete = ps.id_paquete
JOIN servicios s ON ps.id_servicio = s.id_servicio
JOIN estado es ON p.estado_id = es.id_estado
WHERE es.nombre = 'Activo' 
  AND p.vigencia >= CURRENT_DATE
ORDER BY p.id_paquete;