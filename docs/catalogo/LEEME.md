# Catálogo del juego

Estos archivos listan, en texto, todo lo que es "contenido" del juego, tal como está hoy en el código. La idea: **los editás vos** (cambiar un texto o un número, agregar una entrada nueva, borrar una) y después me pedís **"leé el catálogo y aplicá mis cambios"**: yo comparo los archivos con el código y paso las diferencias (crear, modificar o eliminar), con sus tests y traducciones.

| Archivo | Qué tiene |
|---|---|
| `escenarios.md` | Escenarios: entrada en Luz, multiplicador, pruebas que pueden salir, habilidades que se ganan, reglas especiales |
| `pruebas.md` | Pruebas (etapas especiales cada 3 etapas): su regla y su sesgo de bloques |
| `habilidades_persistentes.md` | Habilidades que se conservan para siempre y en qué escenario se ganan |
| `boosts_y_consumibles.md` | Premios del casino: boosts, consumibles y bolsas de claridad, por nivel |
| `casinos.md` | Salas por nivel, reglas de la casa, servicios, ruleta, tragamonedas, blackjack y dados del tabernero |
| `personajes_y_cosmeticos.md` | Personajes (animalitos), gorros y prendas, con su rareza |
| `bloques.md` | Tipos de bloque de la torre, cuándo aparecen y los ritmos de caída |

## Cómo está escrito cada archivo

- Cada entrada empieza con `## id - Nombre` y sigue con líneas `- clave: valor`.
- Las listas van separadas por comas (por ejemplo `pruebas: niebla, oscuridad`) y usan los **ids** de las otras entradas.
- `true` / `false` para sí / no. Un campo vacío significa "ninguno" o "el de siempre".
- Lo que está escrito entre párrafos arriba de las entradas (las explicaciones de los campos) es referencia: no hace falta tocarlo.

## Cómo editarlos

- **Cambiar un valor o un texto**: editá la línea y listo.
- **Agregar algo nuevo**: copiá una entrada, dale un id nuevo (en minúsculas, con guiones bajos) y completá los campos. Si necesita un efecto que no existe todavía (un boost con una regla nueva, una prueba con una mecánica nueva), escribilo en la descripción con tus palabras: yo lo implemento.
- **Borrar**: borrá la entrada entera (o marcala con `ELIMINAR` en el título).
- **Cambiar un id**: pedímelo aparte: el id se usa en el código, en los guardados y en las traducciones.
- Después decime qué archivos tocaste (o "todos") y yo los leo, detecto las diferencias con el código y lo aplico.

## Regenerarlos desde el código

Si el código cambió y querés una versión nueva de los archivos, se vuelven a escribir con `tests/export_catalog.gd` (ver el encabezado del script). **No pisa archivos que ya existen**, justamente para no perder tus cambios; para regenerarlos hay que pasar `CATALOG_FORCE=1` (hacé antes una copia de lo que quieras conservar).
