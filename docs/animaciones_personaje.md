# Animaciones del personaje

`scripts/personajes/animacion.gd` (un `Node` hijo del nodo del personaje; lo crea `torre_juego.gd`). Mueve las partes del modelo (`pata_i/d`, `brazo_i/d`) y el modelo mismo (giro, altura, escala).

## Cómo funciona

- Una **pose** es una función del tiempo normalizado `k` (0 a 1): `Animacion.pose(modelo, tipo, k, amp, deforma)`. Las acciones recorren la pose con un tween; la foto de poses (`tests/capturas/shot_poses.gd`) la usa directamente.
- `torre_juego.gd` elige la animación según lo que pasó en la acción (`_tipo_animacion`): desactivar una bomba, catapulta, resbalar, tirar, empujar, colgarse, desplazarse colgado, trepar, bajar o caminar. La duración sale del movimiento o de `DURACION_ANIM`.
- Estados que se quedan: **colgado** (brazos arriba, patitas que se balancean) y **asustado** (dentro de la zona de una bomba: tiembla con los brazos medio levantados).
- **Quieto:** respira y, tras 3 segundos, hace un pasatiempo al azar (mirar, estirarse, rascarse, saludar).

## Estilo (Opciones > General > Animaciones del personaje)

- **Exageradas** (por defecto): poses grandes, saltitos y, al agacharse (trepar, catapulta), el cuerpo se aplasta.
- **Sutiles:** poses al 45 %, sin saltitos ni deformar el cuerpo. Ajuste `animaciones_exageradas`.

## Poses

| Acción | Qué hace |
|---|---|
| Caminar | Paso de siempre (patas y brazos cruzados) y un rebotito |
| Empujar | Se inclina hacia el bloque con los brazos estirados y las patas de esfuerzo |
| Tirar | Alcanza con las dos manos y se echa hacia atrás con las patas separadas |
| Trepar | Se agacha, salta con los brazos arriba (abiertos) y aterriza |
| Bajar | Saltito con los brazos abiertos para equilibrarse |
| Colgarse | Se agarra con un saltito y los brazos arriba |
| Desplazarse colgado | Mano tras mano, con las patas balanceándose |
| Resbalar | Patina con los brazos abiertos, las patas juntas y bamboleándose |
| Catapulta | Se agacha y sale disparado con los brazos arriba |
| Desactivar | Se seca la frente, aliviado |

Con los brazos muy arriba se abren un poco hacia afuera: pegados al cuerpo quedan dentro de la cabeza.
