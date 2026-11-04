-- Active: 1791930914633@@127.0.0.1@5432@gloss_db
-- Inserción de estados básicos
INSERT INTO estado (nombre) VALUES 
('Activo'), ('Inactivo'), ('Por Completar'), ('Completada'), ('Cancelada');

-- Inserción de clientes
INSERT INTO clientes (nombre_completo, telefono) VALUES 
('Camila Fernández López', '6641234567'),
('María González', '6649876543');

-- Inserción de empleados
INSERT INTO empleado (nombre_completo, telefono, correo, password, especialidad, rol) VALUES 
('Ana Estilista', '6645551122', 'ana@aura.com', '$2b$12$hashgenerado123', 'Cabello', 'Administrador'),
('Laura Manicurista', '6645553344', 'laura@aura.com', '$2b$12$hashgenerado456', 'Uñas', 'Empleado');

-- Inserción de horarios laborales (Ejemplo: Ana trabaja Lunes a Viernes de 9 AM a 5 PM)
INSERT INTO horarios (empleado_id, dia, hora_entrada, hora_salida) VALUES 
(1, 1, '09:00:00', '17:00:00'),
(1, 2, '09:00:00', '17:00:00'),
(1, 3, '09:00:00', '17:00:00'),
(1, 4, '09:00:00', '17:00:00'),
(1, 5, '09:00:00', '17:00:00');

-- Inserción de categorías
INSERT INTO categorias (nombre, estado_id) VALUES 
('Cortes y Peinados', 1),
('Cuidado de Uñas', 1);

-- Inserción de servicios
INSERT INTO servicios (nombre, categoria_id, precio, duracion_estimada, notas_detalles) VALUES 
('Corte de cabello para mujer', 1, 350.00, 45, 'Incluye lavado y secado rápido'),
('Manicura Gelish', 2, 280.00, 60, 'Color sólido, diseño básico');

-- Inserción de inventario
INSERT INTO inventario (nombre, precio, cantidad_existente, unidad, categoria_id) VALUES 
('Shampoo matizador', 120.50, 5.00, 'Litros', 1),
('Esmalte rojo clásico', 80.00, 12.00, 'Piezas', 2);

-- Inserción de una cita de prueba (Pendiente: estado_id = 3)
INSERT INTO citas (empleado_id, servicio_id, cliente_id, fecha_hora_inicio, fecha_hora_fin, estado_id) VALUES 
(1, 1, 1, '2026-10-15 10:00:00', '2026-10-15 10:45:00', 3);
INSERT INTO citas (empleado_id, servicio_id, cliente_id, fecha_hora_inicio, fecha_hora_fin, estado_id) VALUES 
(1, 1, 2, '2026-10-15 10:00:00', '2026-10-16 10:45:00', 3);

-- Inserción de un paquete promocional
INSERT INTO paquetes (descripcion, precio, vigencia, estado_id) VALUES 
('Paquete Renovación Total (Corte + Gelish)', 500.00, '2026-12-31', 1);

-- Vinculación del paquete con los servicios
INSERT INTO paquete_servicios (id_servicio, id_paquete, notas) VALUES 
(1, 1, 'Aplicable con Ana'),
(2, 1, 'Aplicable con Laura');

INSERT INTO horarios (empleado_id, dia, hora_entrada, hora_salida) VALUES 
(2, 1, '09:00:00', '17:00:00'),
(2, 2, '09:00:00', '17:00:00'),
(2, 3, '09:00:00', '17:00:00'),
(2, 4, '09:00:00', '17:00:00'),
(2, 5, '09:00:00', '17:00:00');

SELECT * FROM sp_crear_cita_iot_dinamica(
    p_cliente_id := 1, 
    p_servicio_id := 1, 
    p_fecha_hora_inicio := '2026-10-16 10:00:00'
);
SELECT * FROM sp_crear_cita_iot_dinamica(
    p_cliente_id := 2, 
    p_servicio_id := 1, 
    p_fecha_hora_inicio := '2026-10-16 10:00:00'
);
INSERT INTO citas (empleado_id, servicio_id, cliente_id, fecha_hora_inicio, fecha_hora_fin, estado_id) 
VALUES (1, 1, 1, '2026-10-16 09:00:00', '2026-10-16 09:45:00', 3);

SELECT * FROM sp_crear_cita_iot_dinamica(
    p_cliente_id := 2, 
    p_servicio_id := 1, 
    p_fecha_hora_inicio := '2026-10-16 12:00:00'
);

ALTER TABLE clientes
ADD COLUMN correo VARCHAR(100) UNIQUE;

ALTER TABLE servicios
ADD COLUMN estado_id INT REFERENCES estado(id_estado);

UPDATE servicios SET estado_id = 1 WHERE estado_id IS NULL;

ALTER TABLE servicios
ALTER COLUMN estado_id SET NOT NULL;

-- Agregar la columna para la presentación (medida/volumen)
ALTER TABLE inventario
ADD COLUMN presentacion VARCHAR(50);

-- Agregar la columna para guardar la ruta de la imagen del producto
ALTER TABLE inventario
ADD COLUMN imagen_url TEXT;

-- Agregar el nombre del paquete
ALTER TABLE paquetes
ADD COLUMN nombre VARCHAR(150);

ALTER TABLE paquetes
RENAME COLUMN vigencia TO fecha_fin;

ALTER TABLE paquetes
ADD COLUMN fecha_inicio DATE;

-- Llenar datos de prueba para evitar valores nulos en el nuevo campo nombre
UPDATE paquetes 
SET nombre = 'Paquete Renovación Total', 
    fecha_inicio = CURRENT_DATE 
WHERE id_paquete = 1;