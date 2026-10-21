# Cilindro: reglas del modelo aislado

Módulo propio en `cilindro/` (no importa nada de `tower_logic.gd`, `solver.gd` ni `room_lib.gd`). Las reglas se escriben acá primero.

## Espacio
- Grilla de 8x8 celdas (x, z en 0..7) y niveles y = 0..H.
- **Anillo de piso**: las 28 celdas del borde de la 8x8, a y = 0. Es suelo sólido: se puede pisar y los bloques se apoyan encima. NO es fijo.
- **Masa**: el 6x6 interior (x, z en 1..6) menos el pozo de 2x2 del centro (x, z en 3..4): 32 celdas por nivel. El pozo está vacío y no tiene piso.
- **Cima**: el borde del 6x6 en el nivel H, de 1 bloque de espesor (20 celdas; el hueco del medio es de 4x4). Es lo ÚNICO fijo.
- Lo que cae por debajo del nivel del anillo (y < 0), o fuera del anillo, se pierde.

## Sostén (como en Catherine)
- Dos bloques "se tocan" si comparten una cara o una arista HORIZONTAL (14 vecinos: 4 laterales, 2 verticales y 8 diagonales en un plano vertical). Compartir solo una esquina no cuenta.
- Un bloque está **anclado** si es de la cima o toca (simétrico, sin distinguir arriba de abajo) a un bloque anclado: propagación desde la cima.
- Un bloque no anclado se sostiene sólo si apoya por abajo (cara) sobre el anillo o sobre un bloque que se sostiene.
- Todo lo demás cae en línea recta hasta apoyarse en el anillo o en un bloque que se sostiene. Si no hay nada abajo, se pierde.
- Resultado: una escalera diagonal de H bloques colgando de la cima se sostiene sin bloques extra.

## Movimientos (copiados del juego actual, `cilindro/motor.gd`)
- Caminar: a una celda con piso (bloque o anillo), o bajar un escalón; trepar un bloque si no hay nada encima de él ni sobre vos.
- Agarrar (Shift): empujar un bloque (o una fila de hasta 3; no si es fijo o pesado), tirar de un bloque, o colgarse yendo hacia atrás si no hay piso. El hielo se desliza al empujarlo.
- Colgarse (Espacio + dirección): pasar el borde y quedar colgado del bloque donde estabas. Colgado: avanzar por el borde (recto, esquina hacia adentro y hacia afuera, también hacia un bloque con otro encima), trepar (no si hay algo encima) o soltarse.
- Tipos: común, hielo (resbala), pesado (no se mueve), agrietado (se rompe al bajarte), trampa (se desarma al pisarla), pinchos (pierden), catapulta (lanza hacia arriba). Las bombas todavía no.
- Victoria: estar parado sobre un bloque de la cima. Perder: caer al vacío (fuera del anillo, sin piso debajo) o pisar pinchos.
- Las escaleras se construyen en la fila exterior (z = 0, encima del anillo de piso) y se enganchan a la cima por arista.

## Pendiente
- Solucionador propio (primero en GDScript para validar, después C++), generador (escalera, raíces, desordenador por contra-movimientos), visor.
