# Equipo 47 — equipo47.com

Sitio estático en Netlify + GitHub. Usuario: Guille (coordina). Idioma de trabajo: español.

## Estructura relevante
- `producciones/admin.html`: app interna de Producciones (HTML + CSS + JS vanilla en un solo archivo, Supabase). La usa Fátima.
- `tienda.html` / `tienda-prototipo.html`: tienda pública. El prototipo lee datos reales de Supabase.
- `INTEGRACION_PRODUCCIONES.md`: **fuente única de verdad** entre el trabajo de Producciones y el de la web. Léelo al empezar y añade ahí lo que decidas o necesites del otro lado, con fecha. Guille no reenvía mensajes entre chats.
- `asics/`: otra app. No tocar.
- `madrid/`: app del almacén de Madrid. La lleva el chat de Madrid (rediseño en curso en la rama `rediseno-madrid`). Desde el chat de la web o el de Producciones, no tocar.

## Reglas
- Supabase proyecto `e47-producciones` (`ciszgyorsveumnrtcejn`). La clave anon va embebida en el HTML y es pública; la seguridad está en RLS. No cambiar URL ni claves sin coordinarlo en el buzón.
- La tienda lee solo la vista `catalogo_web` y la función `calcular_precio_publico`. Nunca se expone coste ni margen.
- Regla para publicar un producto (`publicado_validation`): título público, `moq > 0` y categoría (`categoria_id`, desde el script 36). La imagen NO es obligatoria.
- El script SQL `24_tienda_catalogo_completo.sql` está desactualizado: no ejecutarlo.
- La fórmula de precio en SQL debe copiar fielmente la de `calcularPrecioSugerido` en JS (margen por tramo + redondeo a ,95 / ,99 / múltiplo de 5 céntimos).
- Tramos de cantidad: 50, 100, 500, 1000, 5000, 10000 (+ modo general). El 10 está pendiente de que Fátima dé los márgenes.
- La web no toca `producciones/`; Producciones no toca la tienda sin avisar en el buzón.

## Flujo de despliegue
0. Hay varias copias del repo (la local de Guille en `D:\E47\Web\equipo47` y las de cada chat). **Antes de tocar nada, `git pull`. Antes de subir, `git pull` otra vez** y resolver lo que haya cambiado.
1. SQL primero, ejecutado a mano por Guille en el SQL Editor de Supabase.
2. Después el HTML.
3. Después `git add .`, `git commit`, `git push` desde la raíz del repo.
Cada push gasta créditos de Netlify: acumular varios cambios en un solo commit.
Si no se ve un cambio, casi siempre es la caché: Ctrl+Shift+R.

## Patrones de la app de Producciones
- Inputs decimales como `type="text"` con `normalizarComaInput` (admiten coma).
- No reconstruir tablas en cada tecla (se pierde el foco): actualizar solo las celdas de resultado.
- Botones de guardar con bloqueo anti doble clic.
- Sincronizaciones de listas: borrar → actualizar → insertar.
- Limpiar el ruido de coma flotante con `limpioDecimal` (6 decimales) en los cálculos de precio.
- Estilo: tema oscuro por defecto, Bebas Neue (títulos) y DM Sans (cuerpo), sin emojis excesivos.
