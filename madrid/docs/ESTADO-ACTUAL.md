# Estado actual del proyecto

> Generado en el Bloque 0 de consolidación (octubre 2026). Cruza el código
> (`admin.html`, `index.html`, `portal.html`, `js/*.js`) con el esquema real
> de Supabase extraído el mismo mes (ver `docs/sql/README.md`).

## En producción, funcionando

- **Inventario**: productos con variantes (2 ejes), categorías/subcategorías, ubicaciones, palés, cajas, material suelto. Modelo de stock: `variantes.stock_total` es la fuente de verdad; la tabla `stock` son colocaciones (variante + cantidad + dónde).
- **Salidas**: carrito de artículos, plantillas reutilizables, estados (preparando → preparado → fuera → devuelta), multi-variante (varias tallas a la vez).
- **Recepciones**: cabecera con datos del envío, desglose opcional por línea de producto (cantidad esperada vs. recibida), suma automática al inventario al completar, con control de "sumar o no" por línea.
- **Fichaje de jornada**: registro de entrada/salida/pausas, solo-añadir (nunca se edita ni se borra un fichaje), corrección de olvidos y de datos incorrectos vía solicitudes aprobables, calendario mensual, vista de equipo con filtros y exportar CSV. **Construido pero deliberadamente desactivado para el equipo** — pendiente de consulta con la asesoría laboral (RGPD, si los admins también fichan, formalización de correcciones).
- **Calendario de eventos**: hora de inicio opcional, colores de los 5 tipos (Salida/Devolución/Recepción/Evento/Participas) editables desde la propia app por gestor+, etiqueta y color sueltos por evento (ej. "ASICS") como alternativa ligera a un sistema de categorías completo.
- **Clientes y portal externo**: ficha de cliente, visibilidad de catálogo por cliente con tope de unidades, solicitudes de material con comprobación de disponibilidad por rango de fechas — todo vía funciones RPC `SECURITY DEFINER`, nunca acceso directo a tablas desde `portal.html`.
- **Roles**: 5 niveles (consulta/operario/responsable/gestor/admin), aplicados en 3 capas (menú oculto, botones ocultos por clase CSS, RLS en Supabase).

## Desactivado a propósito (no es un fallo)

- El sistema de fichaje no está activo para el equipo — es una decisión consciente, no algo a medio construir.

## Pendiente, ya conocido antes de este bloque

- Backups reales de Supabase (hoy depende de una Raspberry Pi casera, provisional).
- Consulta con la asesoría laboral sobre el fichaje.
- Configuración SMTP propia en Supabase.
- Chuleta de una página para el equipo de almacén.
- Clonado del calendario al año siguiente.
- Registro de vacaciones/ausencias en el calendario (si el uso real lo pide).
- Decisión sobre un importador de zapatillas.
- Pulido del tema claro.

## Nuevo en este bloque: deuda técnica confirmada

Ver `docs/DEUDA-TECNICA.md` para el detalle completo. Lo más relevante:

- ~~Bug confirmado en `exportarCSV` (recursión infinita)~~ — **corregido** en el commit `39db3e2`; estaba fuera del alcance del Bloque 0.
- Código legacy sin uso en `js/supabase.js` y `js/utils.js`, de una versión anterior del proyecto.
- Una tabla (`historial`) en el esquema real de Supabase sin ningún punto de acceso en el código actual — todo apunta a que es la predecesora de `actividad`.
- ~~8 políticas RLS (de 102) con el rol aplicado como `{public}`~~ — **resuelto en el núcleo del Bloque 1B** (octubre 2026), junto con el `search_path` de 11 funciones y el recorte de privilegios de tabla de `anon` y `authenticated`. Pendiente para 1B-bis: `EXECUTE`/`PUBLIC` de las funciones. Ver `docs/SEGURIDAD.md` y `docs/DEUDA-TECNICA.md`.

## El repositorio Git ya existe — el Bloque 0 no lo crea

Madrid vive dentro del repositorio general `equipo47-web` (GitHub,
desplegado vía Netlify), con historial previo de commits, junto a `asics/`
y `producciones/`. El Bloque 0 no es la preparación de un primer commit
histórico: es un baseline de consolidación y documentación sobre una
aplicación que ya estaba versionada. Lo que aporta de nuevo es la
documentación de `docs/`, el `.gitignore` del proyecto, y la retirada de la
contraseña legacy de `js/utils.js` — contenido pendiente de incorporarse al
historial ya existente, no de fundarlo.
