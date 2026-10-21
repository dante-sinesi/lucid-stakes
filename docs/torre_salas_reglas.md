# Torre de salas sin núcleo sólido: reglas propuestas (para revisar, sin código)

Rama de diseño: `diseno/torre-salas-sin-nucleo`. Nace de lo conversado tras archivar el cilindro (`experimento/cilindro`, ver `docs/progreso_cilindro.md`).
Todo lo de acá es propuesta hasta que el usuario lo confirme.

## 1. La torre

- Un anillo de 11x11 alrededor de un **vacío de 5x5** (sin núcleo sólido, sin suelo). El vacío existe para que no se pueda puentear por el medio: 5 celdas de vacío no se cruzan con filas de hasta 3 bloques, ni con bloques que tienen que engancharse a algo.
- Las salas se apilan hacia arriba, **cada una en su propio tramo de altura** (dos salas nunca comparten altura). Una sala empieza abajo y termina algo más arriba.
- Tamaños de sala: 3x3 (esquina), 5x3 (un lado) y 8x3 (un lado más una esquina). Altura máxima = cantidad de celdas de la huella (escalera de un bloque por piso): 9, 15 y 24.
- La sala se crea dentro de su huella, pero **para resolverla se puede usar todo el espacio libre** del anillo a esa altura y el vacío del medio. Un bloque que sale de la huella no se pierde: sigue siendo un bloque (si no tiene sostén cae).

## 2. Sostén (regla común a todo el juego)

- Dos bloques se tocan por cara o por arista horizontal (14 vecinos). La propagación es simétrica (no importa si el vecino está arriba o abajo).
- Un bloque está anclado si es un bloque de salida (fijo) o toca, en cadena, a uno anclado. Lo que no está anclado cae en línea recta hasta apoyarse en otro bloque sostenido; si no hay nada debajo, se pierde. No hay suelo.
- **Cada sala se sostiene sólo de su bloque de salida.** El bloque de salida de una sala es el bloque de llegada de la anterior (se empieza parado sobre él). Es fijo, un bloque común en apariencia, y flota en el aire.
- Una sala se puede sostener y comprobar por separado de todas las demás. Al mover un bloque sólo hay que revisar la conectividad de él y de sus vecinos (reacción en cadena que termina en los bordes de la sala).

## 3. Movimientos

Los del juego actual (caminar, trepar, empujar y tirar de a un bloque o fila de hasta 3, colgarse, avanzar colgado por el borde y doblar esquinas), más:
- **Colgado, se avanza hacia bloques que tienen otro encima** (se agarra de su costado; no se puede trepar ahí).

## 4. Presión y muerte

- **Temporizador:** cada cierto número de movimientos desaparece la fila más baja (la presión que empuja al jugador a subir). Cuántos movimientos y cómo se aplica a cada sala está por definir (ver 6).
- **Caer al vacío es morir**, por cualquier motivo: colgarse sobre el vacío sin salida, perder la plataforma por el temporizador, mover el último bloque que sostenía lo que pisabas, etc.
- **Al morir se pierde una vida y se vuelve al checkpoint** (el bloque de salida de la última sala completada) **con la torre reconstruida virgen**: todas las salas vuelven a su diseño original.
- Todas las salas tienen la misma tensión: ni siquiera la primera tiene suelo.

## 5. Qué es una buena sala (para medir)

- Con bloques básicos (por ahora sin hielo, pesados, agrietados, trampas, pinchos, catapultas ni bombas).
- **Bloques distintos movidos:** como mínimo 3 o 4 por cada 3 pisos (lo que pide Catherine). No cuenta empujar el mismo bloque en fila.
- Que el camino más corto quepa en el presupuesto de movimientos del temporizador, con margen.
- Caminos alternativos **dentro de la misma sala**: una forma menos óptima de resolverla. Medida posible: la diferencia entre el camino óptimo y el mejor camino cuando se prohíbe un bloque clave del óptimo.
- Cuántos movimientos legales dejan la sala sin solución (el riesgo).

## 6. Pendiente de definir

- Cada cuántos movimientos cae la fila de abajo, si es lo mismo para todas las salas, y si el conteo arranca al entrar a la sala.
- Qué fila cae: la más baja del tramo de la sala actual.
- Posición exacta del bloque de salida dentro de la huella y de dónde se arranca en la sala siguiente.
- Qué pasa con la altura máxima en las salas más altas (el temporizador y el presupuesto de movimientos).

## 7. Cómo se verificaría (ideas, sin implementar)

- **3x3:** análisis exhaustivo hacia atrás desde la sala resuelta (distancia exacta de todos los estados alcanzables). Sin heurística, con control total de la dificultad.
- **5x3 y 8x3:** resolución por lonjas de 5 pisos con el jugador al centro (dos filas hacia arriba y dos hacia abajo). La concatenación de las soluciones locales es una solución válida; no garantiza que no haya atajos con material de fuera de la ventana. Se mide con lonjas que se solapan y se contrasta con el solucionador exacto en salas chicas. Los trampolines (catapulta) quedan fuera por ahora.
- El solucionador tiene que llevar la cuenta del temporizador en el estado (la configuración más el nivel que ya cayó).
- La biblioteca de salas actual (`data/salas.rooms`) se hizo con otras reglas (pilar de hierro, sostén direccional): hay que regenerarla.
