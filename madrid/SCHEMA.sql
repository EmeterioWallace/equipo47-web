-- ============================================
-- ALMACÉN MADRID v2 - SCHEMA SUPABASE
-- ============================================

-- PRODUCTOS
CREATE TABLE productos (
  id BIGINT PRIMARY KEY DEFAULT extract(epoch from now())::bigint * 1000,
  nombre TEXT NOT NULL,
  descripcion TEXT,
  categoria_id BIGINT,
  subcategoria_id BIGINT,
  foto_url TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- CATEGORÍAS
CREATE TABLE categorias (
  id BIGINT PRIMARY KEY DEFAULT extract(epoch from now())::bigint * 1000,
  nombre TEXT UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- SUBCATEGORÍAS
CREATE TABLE subcategorias (
  id BIGINT PRIMARY KEY DEFAULT extract(epoch from now())::bigint * 1000,
  categoria_id BIGINT REFERENCES categorias(id),
  nombre TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- VARIANTES (talla, color, etc)
CREATE TABLE variantes (
  id BIGINT PRIMARY KEY DEFAULT extract(epoch from now())::bigint * 1000,
  producto_id BIGINT REFERENCES productos(id) ON DELETE CASCADE,
  tipo TEXT,
  valor TEXT,
  stock_total INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- PALÉS
CREATE TABLE pales (
  id BIGINT PRIMARY KEY DEFAULT extract(epoch from now())::bigint * 1000,
  codigo TEXT UNIQUE NOT NULL,
  ubicacion TEXT,
  descripcion TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- UBICACIONES (del almacén)
CREATE TABLE ubicaciones (
  id BIGINT PRIMARY KEY DEFAULT extract(epoch from now())::bigint * 1000,
  codigo TEXT UNIQUE NOT NULL,
  nombre TEXT NOT NULL,
  descripcion TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- CAJAS
CREATE TABLE cajas (
  id BIGINT PRIMARY KEY DEFAULT extract(epoch from now())::bigint * 1000,
  variante_id BIGINT REFERENCES variantes(id) ON DELETE CASCADE,
  codigo TEXT UNIQUE NOT NULL,
  cantidad INT DEFAULT 0,
  pale_id BIGINT REFERENCES pales(id),
  es_suelto BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- SALIDAS (préstamos, eventos, etc)
CREATE TABLE salidas (
  id BIGINT PRIMARY KEY DEFAULT extract(epoch from now())::bigint * 1000,
  tipo TEXT, -- 'prestamo', 'evento', 'devolucion', 'otro'
  destinatario TEXT,
  fecha_salida DATE,
  fecha_devolucion DATE,
  estado TEXT DEFAULT 'pendiente', -- 'pendiente', 'confirmada', 'entregada', 'devuelta'
  notas TEXT,
  usuario TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- LÍNEAS DE SALIDA (items dentro de una salida)
CREATE TABLE salida_lineas (
  id BIGINT PRIMARY KEY DEFAULT extract(epoch from now())::bigint * 1000,
  salida_id BIGINT REFERENCES salidas(id) ON DELETE CASCADE,
  variante_id BIGINT REFERENCES variantes(id),
  cantidad INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW()
);

-- HISTORIAL (log de movimientos)
CREATE TABLE historial (
  id BIGINT PRIMARY KEY DEFAULT extract(epoch from now())::bigint * 1000,
  tipo TEXT, -- 'crear_caja', 'mover_stock', 'salida', 'entrada', 'reorganizar'
  tabla TEXT,
  tabla_id BIGINT,
  descripcion TEXT,
  usuario TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- ÍNDICES PARA PERFORMANCE
-- ============================================

CREATE INDEX idx_variantes_producto ON variantes(producto_id);
CREATE INDEX idx_cajas_variante ON cajas(variante_id);
CREATE INDEX idx_cajas_pale ON cajas(pale_id);
CREATE INDEX idx_salida_lineas_salida ON salida_lineas(salida_id);
CREATE INDEX idx_salida_lineas_variante ON salida_lineas(variante_id);
CREATE INDEX idx_salidas_estado ON salidas(estado);
CREATE INDEX idx_salidas_fecha ON salidas(fecha_salida);

-- ============================================
-- RLS (Row Level Security) - Opcional
-- ============================================

-- Por ahora deshabilitamos RLS ya que es solo acceso interno con contraseña
-- Si quieres implementarlo después, me avisas

-- ============================================
-- DATOS INICIALES (Opcional)
-- ============================================

-- Puedes descomentar estos si quieres datos de prueba:
/*
INSERT INTO categorias (nombre) VALUES
  ('Running'),
  ('Fitness'),
  ('Merchandising');

INSERT INTO pales (codigo, ubicacion, descripcion) VALUES
  ('PAL-001', 'Zona A1', 'Palé 1'),
  ('PAL-002', 'Zona A2', 'Palé 2');

INSERT INTO ubicaciones (codigo, nombre, descripcion) VALUES
  ('UB-001', 'Zona A', 'Primera zona'),
  ('UB-002', 'Zona B', 'Segunda zona');
*/
