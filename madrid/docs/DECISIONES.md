# Decisiones de diseño

> Registro breve del porqué, no del qué (eso está en `docs/MODELO-DATOS.md`
> y `docs/ARQUITECTURA.md`). Se va añadiendo una entrada por cada decisión de
> diseño importante, no por cada función construida.

## Principios generales del proyecto

- **No construir por si acaso.** Varias funciones (avisos de eventos
  próximos, categorías de calendario completas, importador de zapatillas) se
  han dejado pendientes conscientemente hasta que el uso real las pida.
- **Reutilizar antes que duplicar.** El componente de selección múltiple de
  variantes (`renderTablaMultiVariante`) se construyó una vez y se reutilizó
  en tres sitios (cajas nuevas, cajas existentes, salidas) en vez de
  escribirlo tres veces.
- **Honestidad sobre incertidumbre.** Cuando algo no se puede verificar con
  evidencia directa (como el motivo exacto de la tabla `historial`), se
  documenta como hipótesis, no como hecho.
- **Arquitectura de archivo único.** Estado actual, verificable en el
  código: sin framework ni build, HTML+JS vanilla. No hay evidencia directa
  de que este formato se eligiera en su momento específicamente por ser
  manejable para una persona no programadora — esa sería una atribución de
  motivo histórico que no podemos demostrar. Lo que sí es una decisión
  actual, tomada en estas sesiones: no migrarlo a otra arquitectura
  mientras no exista una necesidad real que lo justifique.

## Fichaje: solo-añadir, nunca editar ni borrar

Los fichajes no se editan ni se eliminan jamás, ni siquiera por un admin.
Las correcciones (olvidos o datos incorrectos) son **solicitudes** que, al
aprobarse, generan un **registro nuevo** enlazado al original mediante
`fichaje_original_id` — el fichaje original permanece intacto para siempre.
Motivo: es un registro con implicaciones legales (control horario), y la
trazabilidad completa (quién pidió qué, quién lo aprobó, por qué) importa
más que la comodidad de editar directamente.

La hora de cada fichaje la pone el servidor (`now()` dentro de la función
`fichar()`), nunca el navegador del usuario.

## Calendario: etiqueta y color sueltos en vez de un sistema de categorías

Cuando se pidió poder crear categorías tipo "Eventos ASICS" con su propio
color, se valoraron dos caminos: un sistema completo de categorías
reutilizables (tabla propia, pantalla de gestión, selector) o un campo de
etiqueta + color libre por evento. Se eligió la segunda opción porque, con
un solo caso de uso conocido en el momento, el coste de construir y
mantener una lista reutilizable no se justificaba. Si en el futuro aparecen
varias categorías que se repiten mucho, está documentado como candidato a
convertirse en un sistema completo.

## Colores del calendario configurables desde la app, no solo en código

Los 5 colores fijos (Salida/Devolución/Recepción/Evento/Participas) se
sacaron del CSS y se guardaron en `calendario_config` (una fila única en
Supabase), con un panel de edición accesible a gestor+. Motivo: la persona
que gestiona el calendario del día a día no es quien mantiene el código.

## Recepciones: desglose por línea es opcional, no obligatorio

Al añadir `recepcion_lineas` (producto/variante/cantidad esperada y
recibida), se decidió explícitamente que las recepciones sin desglosar
siguieran funcionando exactamente igual que antes, con sus botones
manuales de "recibido correctamente"/"parcial". El desglose por línea solo
sustituye ese flujo cuando la recepción tiene líneas asociadas. Motivo: no
romper el flujo que el equipo ya usaba a diario por construir el nuevo.

## Multi-variante: casillas con relleno al máximo, no solo cantidades a mano

Al construir la selección múltiple de variantes para cajas y salidas, se
añadió una casilla "seleccionar todas (con su máximo)" y casillas por fila
que autorrellenan con el disponible real, en vez de obligar a escribir cada
cantidad a mano. Motivo directo: el caso real reportado de 62 pares de
zapatillas que se acabaron anotando como nota de texto por lo tedioso de
meterlos uno a uno.

## Sistema de roles en 3 capas, no solo en el cliente

Ocultar botones y páginas en el navegador nunca es suficiente por sí solo
(cualquiera podría saltárselo). Por eso cada capacidad de escritura
importante está también protegida por RLS en Supabase, usando funciones
(`es_min_operario()`, `es_min_responsable()`, `es_min_gestor()`,
`es_admin()`) independientes de lo que el cliente decida mostrar u ocultar.

## Bloque 0 de consolidación: por qué tan conservador

Madrid ya vive dentro del repositorio `equipo47-web`, con historial previo
— el Bloque 0 no crea ningún repositorio, consolida y documenta el estado
actual. Aun así, se decidió separar explícitamente cuatro fases (baseline →
versionado → correcciones → mejoras) y no mezclar
ninguna corrección de bugs, por pequeña que sea, con la preparación del
baseline — incluido el bug ya conocido de `exportarCSV`. Motivo: la app está
en producción con operativa real del equipo, y mezclar "ordenar el proyecto"
con "cambiar cómo funciona" dificulta saber, si algo se rompe, cuál de las
dos cosas lo causó.

## Admin bypass por email sustituido por el sistema normal de roles

Dos cuentas estaban "blindadas" por email, en `mi_rol()` y en `admin.html`
(`ADMINS_BLINDADOS`), y eran admin con independencia de `personas_equipo`.
Se sustituyó por el mecanismo normal: las dos cuentas son `admin` activas en
`personas_equipo` y el rol de todo el mundo sale de esa tabla. Motivos: una
única fuente de verdad para los roles, y sacar emails reales del código que
llega al navegador y del cuerpo de una función. Se aplicó en orden (datos →
frontend → lógica), cada paso con respaldo y rollback, de modo que nadie
perdiera acceso en ningún momento. Coste asumido: ya no hay red de seguridad
por email, así que perder al último administrador solo se arregla desde el SQL
Editor; ese riesgo y la semántica de `activo=false` quedan como deuda
registrada (`docs/DEUDA-TECNICA.md`), no resueltos. Detalle en
`docs/SEGURIDAD.md`.
