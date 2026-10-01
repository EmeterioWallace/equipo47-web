# App Inventario Almacén — Equipo 47 (Madrid)

Aplicación web de gestión de inventario, fichaje de jornada, calendario de eventos
y portal de clientes para el almacén de Equipo 47 en Madrid. En producción, con
datos reales del equipo.

> 📌 Este README se generó durante el **BLOQUE 0 — Baseline de
> consolidación** del proyecto (octubre 2026). Madrid **ya forma parte**
> del repositorio Git `equipo47-web` (GitHub + Netlify), con historial
> previo — el Bloque 0 no crea ningún repositorio, consolida y documenta el
> estado actual de una aplicación ya versionada. El resto de documentación
> vive en `docs/`.

## Qué es esto

- **`admin.html`** — panel de administración completo, con roles (consulta → operario → responsable → gestor → admin). Aquí vive el 95% de la funcionalidad.
- **`index.html`** — vista pública de solo lectura (Productos, Cajas, Palés, Salidas, Buscar), sin ninguna operación de escritura.
- **`portal.html`** — portal externo para clientes: catálogo y solicitudes de material, autenticado con Supabase Auth, todas sus escrituras pasan por funciones RPC (nunca acceso directo a tablas).
- **`js/supabase.js`** — cliente de Supabase + funciones auxiliares (ver aviso en `docs/DEUDA-TECNICA.md`: gran parte no se usa).
- **`js/utils.js`** — utilidades (toast, fechas, exportar CSV, etc.).

## Stack técnico

- Sin build ni framework: HTML + CSS + JavaScript vanilla.
- Backend: Supabase (PostgreSQL con Row Level Security).
- SDK de Supabase cargado desde CDN (`cdn.jsdelivr.net`), sin `package.json`.
- Hosting: Netlify. El código de este proyecto vive dentro de un
  repositorio Git ya existente (`equipo47-web`, en GitHub), que cubre varias
  propiedades web de Equipo 47 (esta app vive en su carpeta `madrid/`, junto
  a `asics/` y `producciones/`). `git push` a ese repositorio dispara el
  deploy en Netlify — confirmado tanto por la documentación propia del
  proyecto como por el uso repetido de ese flujo a lo largo del desarrollo.

## Cómo arrancar en local

No hay proceso de build. Basta con servir la carpeta con cualquier servidor
estático y abrir `index.html` o `admin.html`. Necesita un archivo de
configuración con las credenciales de Supabase — ver `docs/sql/README.md` y
`docs/DEUDA-TECNICA.md` para el estado actual de esto (hoy las credenciales
están incrustadas directamente en `js/supabase.js`, pendiente de separar en un
bloque posterior a este baseline).

## Documentación

| Documento | Contenido |
|---|---|
| `docs/ESTADO-ACTUAL.md` | Qué funciona hoy, qué está pendiente, qué está desactivado a propósito |
| `docs/ARQUITECTURA.md` | Mapa funcional, páginas, roles, cómo se relacionan los 3 frontales |
| `docs/MODELO-DATOS.md` | Las 29 tablas reales, columnas, relaciones, funciones RPC |
| `docs/DEUDA-TECNICA.md` | Bugs conocidos, código legacy, inconsistencias |
| `docs/DECISIONES.md` | Por qué se construyó cada cosa como se construyó |
| `docs/SEGURIDAD.md` | RLS, grants, funciones `SECURITY DEFINER`, elementos sensibles |
| `docs/sql/README.md` | Qué representa cada SQL, cómo se obtuvo, cómo reproducirlo |

## Equipo

Guillermo (admin, responsable del proyecto) y Alejandro (admin/socio), con
Fátima, Angely, Miriam, Miguel, Jose y Pedro como usuarios del día a día, cada
uno con su rol correspondiente.

## Estado de control de versiones

Madrid vive dentro del repositorio Git general `equipo47-web` (GitHub),
junto a `asics/` y `producciones/` como carpetas hermanas, con historial
previo de commits — no es un proyecto sin versionar. El repositorio es el
que ya se usa para desplegar en Netlify (`git push` dispara el deploy).

Lo que no existía hasta el Bloque 0 era esta documentación (`docs/`) ni un
`.gitignore` pensado para el proyecto. El Bloque 0 es, por tanto, un
**baseline de consolidación y documentación** sobre una aplicación ya
versionada — no la creación de un repositorio nuevo ni un primer commit
histórico. El "commit de consolidación" que prepara este bloque añade la
documentación y los ajustes de higiene (`.gitignore`, retirada de la
contraseña legacy) al historial ya existente.
