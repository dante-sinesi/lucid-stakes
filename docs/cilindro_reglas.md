# Cilindro: reglas del modelo aislado

Módulo propio en `cilindro/` (no importa nada de `tower_logic.gd`, `solver.gd` ni `room_lib.gd`). Las reglas se escriben acá primero.

## Espacio
- Grilla de 8x8 celdas (x, z en 0..7) y niveles y = 0..H.
- **Anillo de piso**: las 28 celdas del borde de la 8x8, a y = 0. Es suelo sólido: se puede pisar y los bloques se apoyan encima. NO es fijo.
- **Masa**: el 6x6 interior (x, z en 1..6) menos el pozo de 2x2 del centro (x, z en 3..4): 32 celdas por nivel. El pozo está vacío y no tiene piso.
- **Cima**: las 32 celdas de la masa en el nivel H. Es lo ÚNICO fijo (se asume que todas existen como bloques fijos; se confirma con el usuario).
- Lo que cae por debajo del nivel del anillo (y < 0), o fuera del anillo, se pierde.

## Sostén (como en Catherine)
- Dos bloques "se tocan" si comparten una cara o una arista HORIZONTAL (14 vecinos: 4 laterales, 2 verticales y 8 diagonales en un plano vertical). Compartir solo una esquina no cuenta.
- Un bloque está **anclado** si es de la cima o toca (simétrico, sin distinguir arriba de abajo) a un bloque anclado: propagación desde la cima.
- Un bloque no anclado se sostiene sólo si apoya por abajo (cara) sobre el anillo o sobre un bloque que se sostiene.
- Todo lo demás cae en línea recta hasta apoyarse en el anillo o en un bloque que se sostiene. Si no hay nada abajo, se pierde.
- Resultado: una escalera diagonal de H bloques colgando de la cima se sostiene sin bloques extra.

## Pendiente de definir (se agrega acá cuando se confirme)
- Movimientos del jugador (empujar, tirar, colgarse, bordear, trepar).
- Condición de victoria.
