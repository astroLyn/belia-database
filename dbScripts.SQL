-- Tabla: estado
CREATE TABLE estado (
    id_estado SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL
);

-- Tabla: clientes
CREATE TABLE clientes (
    id_cliente SERIAL PRIMARY KEY,
    nombre_completo VARCHAR(150) NOT NULL,
    telefono VARCHAR(15) UNIQUE NOT NULL,
    correo VARCHAR(100) UNIQUE
);

-- Tabla: empleado
CREATE TABLE empleado (
    id_empleado SERIAL PRIMARY KEY,
    nombre_completo VARCHAR(150) NOT NULL,
    telefono VARCHAR(15),
    correo VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    especialidad VARCHAR(100),
    rol VARCHAR(50) NOT NULL
);

-- Tabla: horarios
CREATE TABLE horarios (
    id_horario SERIAL PRIMARY KEY,
    empleado_id INT NOT NULL REFERENCES empleado(id_empleado) ON DELETE CASCADE,
    dia SMALLINT NOT NULL CHECK (dia BETWEEN 0 AND 6), -- 0=Domingo, 6=Sábado
    hora_entrada TIME NOT NULL,
    hora_salida TIME NOT NULL,
    CONSTRAINT check_horario_logico CHECK (hora_entrada < hora_salida)
);

-- Tabla: categorias
CREATE TABLE categorias (
    id_categoria SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    estado_id INT NOT NULL REFERENCES estado(id_estado)
);

-- Tabla: servicios
CREATE TABLE servicios (
    id_servicio SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    categoria_id INT NOT NULL REFERENCES categorias(id_categoria),
    precio NUMERIC(10,2) NOT NULL CHECK (precio >= 0),
    duracion_estimada SMALLINT NOT NULL CHECK (duracion_estimada > 0), -- En minutos
    notas_detalles TEXT,
    estado_id INT NOT NULL REFERENCES estado(id_estado)
);

-- Tabla: inventario
CREATE TABLE inventario (
    id_producto SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    precio NUMERIC(10,2) CHECK (precio >= 0),
    cantidad_existente NUMERIC(10,2) NOT NULL CHECK (cantidad_existente >= 0),
    unidad VARCHAR(20) NOT NULL,
    presentacion VARCHAR(50),
    imagen_url TEXT,
    categoria_id INT NOT NULL REFERENCES categorias(id_categoria)
);

-- Tabla: citas
CREATE TABLE citas (
    id_cita SERIAL PRIMARY KEY,
    empleado_id INT NOT NULL REFERENCES empleado(id_empleado),
    servicio_id INT NOT NULL REFERENCES servicios(id_servicio),
    cliente_id INT NOT NULL REFERENCES clientes(id_cliente),
    fecha_hora_inicio TIMESTAMP NOT NULL,
    fecha_hora_fin TIMESTAMP NOT NULL,
    estado_id INT NOT NULL REFERENCES estado(id_estado),
    CONSTRAINT check_fechas_logicas CHECK (fecha_hora_inicio < fecha_hora_fin)
);

-- Tabla: paquetes
CREATE TABLE paquetes (
    id_paquete SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT NOT NULL,
    precio NUMERIC(10,2) NOT NULL CHECK (precio >= 0),
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    estado_id INT NOT NULL REFERENCES estado(id_estado)
);

-- Tabla: paquete_servicios (Tabla pivote M:N)
CREATE TABLE paquete_servicios (
    id_servicio INT NOT NULL REFERENCES servicios(id_servicio) ON DELETE CASCADE,
    id_paquete INT NOT NULL REFERENCES paquetes(id_paquete) ON DELETE CASCADE,
    notas TEXT,
    PRIMARY KEY (id_servicio, id_paquete)
);

CREATE TABLE presentacion (
    id_presentacion SERIAL PRIMARY KEY,
    nombre VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE unidad_medida (
    id_unidad SERIAL PRIMARY KEY,
    nombre VARCHAR(50) UNIQUE NOT NULL
);

ALTER TABLE inventario 
DROP COLUMN presentacion CASCADE,
DROP COLUMN unidad CASCADE;

ALTER TABLE inventario 
ADD COLUMN presentacion_id INT REFERENCES presentacion(id_presentacion),
ADD COLUMN unidad_id INT REFERENCES unidad_medida(id_unidad);