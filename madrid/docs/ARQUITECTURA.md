# Arquitectura y mapa funcional

## Visión general

Arquitectura de archivo único por frontal, sin build ni framework. Tres
páginas HTML independientes comparten la misma base de datos Supabase, cada
una con un nivel de acceso distinto:

```
equipo47.com/madrid/
├── index.html         933 líneas  — solo lectura, sin roles
├── admin.html       8.954 líneas  — panel completo, con roles (núcleo del proyecto)
├── portal.html         500 líneas  — portal de clientes, vía RPC únicamente
├── js/
│   ├── supabase.js     306 líneas  — cliente Supabase + funciones auxiliares
│   └── utils.js         308 líneas  — toast, fechas, CSV, etc.
```

Las tres páginas cargan el SDK de Supabase desde CDN
(`cdn.jsdelivr.net/npm/@supabase/supabase-js@2`). `admin.html` además carga
una librería de generación de QR desde `cdnjs.cloudflare.com`. No hay gestor
de paquetes ni `package.json` en el proyecto.

## Los tres frontales, por nivel de exposición

| Frontal | Quién lo usa | Autenticación | Acceso a datos |
|---|---|---|---|
| `admin.html` | Equipo interno, con rol | Supabase Auth (email+contraseña) | Directo: `sb.from(tabla).insert/update/delete()`, protegido por RLS + `exigeCap()` en el cliente |
| `index.html` | Equipo interno, consulta rápida | Supabase Auth | Solo lectura, sin ninguna escritura |
| `portal.html` | Clientes externos | Supabase Auth (cuenta de cliente) | **Nunca** toca tablas directamente — todo vía funciones RPC `SECURITY DEFINER` |

Este patrón (cuanto más expuesta la superficie, más se apoya en funciones de
servidor en vez de en permisos de tabla) es consistente y deliberado: el
fichaje sigue el mismo principio que el portal.

## Sistema de roles (`admin.html`)

5 niveles jerárquicos, aplicados en 3 capas:

1. **Menú**: cada página tiene un nivel mínimo (`NIVEL_PAGINA`); las páginas por debajo del rol del usuario no aparecen.
2. **Botones**: clases CSS `acc-inv` (operario+), `acc-ops` (responsable+), `acc-cli` (gestor+) que el body oculta según el rol.
3. **Base de datos**: RLS en Supabase, usando funciones como `es_min_operario()`, `es_min_responsable()`, `es_min_gestor()`, `es_admin()` (confirmadas existentes y correctamente definidas — ver `docs/SEGURIDAD.md`).

```
NIVEL_PAGINA = {
  dashboard:1, fichar:1, calendario:1, productos:1, zapatillas:1,
  ubicaciones:1, pales:1, cajas:1, sueltos:1,
  salidas:2, recepciones:2, solicitudes:2,
  actividad:4, clientes:4,
  equipo:5, importar:5, exportar:5, configuracion:5
}
```

Dos cuentas "blindadas" de fábrica están hardcodeadas por email directamente
en `admin.html` (`ADMINS_BLINDADOS`) y siempre son admin, pase lo que pase en
la tabla `personas_equipo`.

## Páginas de `admin.html`

17 secciones/páginas, 325 funciones JavaScript en total.

## Flujo de autenticación real

Las tres páginas usan `sb.auth.signInWithPassword()` con cuentas reales en
Supabase Auth, más un flujo de invitación/recuperación de contraseña
(`PASSWORD_RECOVERY`, pantalla "crea tu contraseña"). Esto es independiente
de un sistema de autenticación anterior, ya inactivo — ver
`docs/DEUDA-TECNICA.md`.

## Qué parte del proyecto conozco mejor, y cuál menos

Por cómo hemos trabajado hasta ahora, el fichaje, las recepciones con líneas,
el calendario y la reorganización del menú son áreas que se construyeron en
conversación directa, documentadas con detalle. El **portal de clientes**
(`portal.html` + sus 6 funciones RPC) existía ya construido y no se ha tocado
en estas sesiones — su documentación en este bloque viene de leer el código y
las funciones reales, no de haberlo diseñado en conversación.
