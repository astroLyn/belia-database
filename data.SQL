-- Active: 1791930914633@@127.0.0.1@5432@gloss_db
-- Inserción de estados básicos
INSERT INTO estado (nombre) VALUES 
('Activo'), ('Inactivo'), ('Por Completar'), ('Completada'), ('Cancelada');

-- Inserción de clientes
INSERT INTO clientes (nombre_completo, telefono, correo, estado_id) VALUES 
('Camila Fernández López', '6641234567', 'camila.fernandez@email.com', 1),
('María González', '6649876543', 'maria.gonzalez@email.com', 1);

-- Inserción de empleados
INSERT INTO empleado (nombre_completo, telefono, correo, password, especialidad, rol, estado_id) VALUES 
('Ana Estilista', '6645551122', 'ana@aura.com', '$2b$12$hashgenerado123', 'Cabello', 'Administrador', 1),
('Laura Manicurista', '6645553344', 'laura@aura.com', '$2b$12$hashgenerado456', 'Uñas', 'Empleado', 1);

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

-- Inserción de servicios (Se agregó 'estado_id')
INSERT INTO servicios (nombre, categoria_id, precio, duracion_estimada, notas_detalles, estado_id) VALUES 
('Corte de cabello para mujer', 1, 350.00, 45, 'Incluye lavado y secado rápido', 1),
('Manicura Gelish', 2, 280.00, 60, 'Color sólido, diseño básico', 1);
INSERT INTO servicios (nombre, categoria_id, precio, duracion_estimada, notas_detalles, estado_id) VALUES 
('Corte despunte + brushing', 1, 450.00, 60, 'Lavado, corte y peinado', 1),
('Coloración completa', 1, 1250.00, 120, 'Diagnóstico, tinte y secado', 1);

INSERT INTO presentacion (nombre) VALUES 
('Botella'), ('Tubo'), ('Frasco'), ('Tarro'), ('Caja'), ('Bolsa'), ('Ampolleta'), ('Sobre');
INSERT INTO unidad_medida (nombre) VALUES 
('Litros'), ('Mililitros'), ('Gramos'), ('Kilogramos'), ('Onzas'), ('Piezas');
-- Inserción de inventario (Se agregó 'presentacion' e 'imagen_url')
-- Inserción de inventario actualizada con llaves foráneas (presentacion_id, unidad_id)
INSERT INTO inventario (nombre, precio, cantidad_existente, presentacion_id, unidad_id, imagen_url, categoria_id) VALUES 
('Shampoo matizador', 120.50, 5.00, 1, 1, 'https://ejemplo.com/shampoo.png', 1),
('Esmalte rojo clásico', 80.00, 12.00, 3, 2, 'https://ejemplo.com/esmalte.png', 2),
('Shampoo hidratante', 250.00, 18.00, 1, 1, 'https://ejemplo.com/shampoo_hidratante.png', 1),
('Tinte profesional #7.1', 150.00, 6.00, 2, 2, 'https://ejemplo.com/tinte_profesional.png', 1),
('Esmalte gel nude', 120.00, 12.00, 3, 2, 'https://ejemplo.com/esmalte_gel_nude.png', 2),
('Mascarilla reparadora', 200.00, 9.00, 4, 2, 'https://ejemplo.com/mascarilla_reparadora.png', 1);

-- Inserción de citas de prueba manuales
INSERT INTO citas (empleado_id, servicio_id, cliente_id, fecha_hora_inicio, fecha_hora_fin, estado_id) VALUES 
(1, 1, 1, '2026-10-15 10:00:00', '2026-10-15 10:45:00', 3);
INSERT INTO citas (empleado_id, servicio_id, cliente_id, fecha_hora_inicio, fecha_hora_fin, estado_id) VALUES 
(2, 1, 2, '2026-10-15 10:00:00', '2026-10-15 10:45:00', 3);
INSERT INTO citas (empleado_id, servicio_id, cliente_id, fecha_hora_inicio, fecha_hora_fin, estado_id) VALUES 
-- Cita 1: Hoy a las 10:00 (Confirmada - 1 hora)
(2, 1, 1, CURRENT_DATE + TIME '10:00:00', CURRENT_DATE + TIME '11:00:00', 1),
-- Cita 2: Hoy a las 11:30 (Confirmada - 45 min)
(2, 3, 2, CURRENT_DATE + TIME '11:30:00', CURRENT_DATE + TIME '12:15:00', 1),
-- Cita 3: Hoy a las 13:00 (Pendiente - 2 horas)
(2, 2, 2, CURRENT_DATE + TIME '13:00:00', CURRENT_DATE + TIME '15:00:00', 3),
-- Cita 4: Mañana a las 10:00 (Confirmada - No debe salir en métricas de 'Hoy')
(2, 1, 1, CURRENT_DATE + INTERVAL '1 day' + TIME '10:00:00', CURRENT_DATE + INTERVAL '1 day' + TIME '11:00:00', 1);

-- Inserción de un paquete promocional (Se agregó 'nombre', 'fecha_inicio' y 'fecha_fin')
INSERT INTO paquetes (nombre, descripcion, precio, fecha_inicio, fecha_fin, estado_id) VALUES 
('Paquete Renovación Total', 'Corte + Gelish a precio especial', 500.00, CURRENT_DATE, '2026-12-31', 1);

-- Vinculación del paquete con los servicios
INSERT INTO paquete_servicios (id_servicio, id_paquete, notas) VALUES 
(1, 1, 'Aplicable con Ana'),
(2, 1, 'Aplicable con Laura');

-- Inserción de horarios laborales de Laura
INSERT INTO horarios (empleado_id, dia, hora_entrada, hora_salida) VALUES 
(2, 1, '09:00:00', '17:00:00'),
(2, 2, '09:00:00', '17:00:00'),
(2, 3, '09:00:00', '17:00:00'),
(2, 4, '09:00:00', '17:00:00'),
(2, 5, '09:00:00', '17:00:00');

-- Pruebas de asignación dinámica (Procedimiento almacenado)
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

-- Inserción manual para forzar balanceo de cargas
INSERT INTO citas (empleado_id, servicio_id, cliente_id, fecha_hora_inicio, fecha_hora_fin, estado_id) 
VALUES (1, 1, 1, '2026-10-16 09:00:00', '2026-10-16 09:45:00', 3);

SELECT * FROM sp_crear_cita_iot_dinamica(
    p_cliente_id := 2, 
    p_servicio_id := 1, 
    p_fecha_hora_inicio := '2026-10-16 12:00:00'
);