# Torre de salas sin núcleo sólido: reglas propuestas (para revisar, sin código)

Rama de diseño: `diseno/torre-salas-sin-nucleo`. Nace de lo conversado tras archivar el cilindro (`experimento/cilindro`, ver `docs/progreso_cilindro.md`).
Todo lo de acá es propuesta hasta que el usuario lo confirme. Segunda versión, con las correcciones del usuario.

## 1. La torre

- Un anillo de 11x11 alrededor de un **vacío de 5x5** (sin núcleo sólido, sin suelo). El vacío existe para que no se pueda puentear por el medio.
- Las salas se apilan hacia arriba, **cada una en su propio tramo de altura** (dos salas nunca comparten altura). Una sala empieza abajo y termina algo más arriba.
- Tamaños de sala: 3x3 (esquina), 5x3 (un lado) y 8x3 (un lado más una esquina). Altura máxima = cantidad de celdas de la huella: 9, 15 y 24.
- La sala se crea dentro de su huella, pero **para resolverla se puede usar todo el espacio libre** del anillo a esa altura y el vacío del medio.

## 2. Sostén (una sola cadena para toda la torre)

- Dos bloques se tocan por cara o por arista horizontal (14 vecinos); la propagación es simétrica.
- **Hay un único bloque fijo: el portal de salida de la torre** (arriba de todo). Está anclado; todo lo demás está anclado sólo si toca, en cadena, a un bloque anclado.
- Lo que no está anclado cae en línea recta hasta apoyarse en otro bloque sostenido; si no hay nada, se pierde. No hay suelo.
- Los "bloques de salida" de cada sala son **bloques comunes** (se pueden mover): conceptualmente son el final de una sala y el comienzo de la siguiente, en la práctica nada los distingue. Una sala se sostiene a través de su bloque de salida, que a su vez se sostiene de la sala siguiente, y así hasta el portal.
- **La reacción en cadena no se frena en la sala**: si un movimiento afecta al bloque de salida, éste también cae, y la caída puede seguir hacia abajo por toda la torre.

## 3. Movimientos

Los del juego actual (caminar, trepar, empujar y tirar de a un bloque o fila de hasta 3, colgarse, avanzar colgado por el borde y doblar esquinas), más:
- **Colgado, se avanza hacia bloques que tienen otro encima** (se agarra de su costado; no se puede trepar ahí).

## 4. Temporizador, checkpoint y muerte

- El temporizador cuenta **movimientos, no tiempo**. Cada sala tiene un máximo de movimientos y a medida que se gastan va desapareciendo la fila más baja de la sala.
- **El solucionador manda, el temporizador obedece:** el solucionador da el mínimo de movimientos de la sala y el máximo se calcula sobre eso: una etapa temprana deja más movimientos de más, una avanzada menos. El temporizador nunca condiciona al solucionador.
- Interpretación a confirmar: el camino mínimo marca para cada fila la última vez que se usa un bloque de esa fila o se pisa; la fila no puede desaparecer antes de eso más el margen de la etapa. Así el camino mínimo siempre cabe.
- **Checkpoint:** al llegar al bloque de salida de una sala (el comienzo de la siguiente), **toda la sala anterior cae** y el temporizador arranca de cero con los movimientos máximos de la sala actual.
- **Caer al vacío es morir**, por cualquier motivo: quedar colgado sobre el vacío, perder la plataforma por el temporizador, mover el último bloque que sostenía lo que pisabas, etc.
- **Al morir se pierde una vida y se vuelve al checkpoint con la torre reconstruida virgen** (las salas vuelven a su diseño original).
- Todas las salas tienen la misma tensión: ni siquiera la primera tiene suelo.

## 5. Qué es una buena sala (para medir)

- Con bloques básicos (por ahora sin hielo, pesados, agrietados, trampas, pinchos, catapultas ni bombas).
- **Bloques distintos movidos:** como mínimo 3 o 4 por cada 3 pisos (lo que pide Catherine). No cuenta empujar el mismo bloque en fila.
- Caminos alternativos **dentro de la misma sala**: una forma menos óptima de resolverla (por ejemplo, la diferencia entre el camino óptimo y el mejor cuando se prohíbe un bloque clave del óptimo).
- Cuántos movimientos legales dejan la sala sin solución (el riesgo).

## 6. Cómo se verificaría (ideas, sin implementar)

- **Contrato de empalme:** como las salas ya no son independientes, cada sala se verifica con un bloque de salida anclado por un "ancla de verificación": bloques fijos que representan lo que toca ese bloque en la sala de arriba. Si el jugador lo mueve, deja de estar anclado y puede caer, igual que en la torre real. La sala siguiente hace lo mismo con su bloque de llegada (que es el de salida de ésta) y sus propios bloques como sostén.
- **3x3:** análisis exhaustivo hacia atrás desde la sala resuelta (distancia exacta de todos los estados alcanzables).
- **5x3 y 8x3, primera fase:** resolución por lonjas de 5 pisos con el jugador al centro (dos filas hacia arriba y dos hacia abajo). Sirve para saber que la sala **se puede resolver**; se guarda como siempre. Hasta el mínimo exacto, el camino de la lonja es una cota superior y se usa para el máximo de movimientos con margen de sobra.
- **Segunda fase (más adelante):** un ejecutable aparte, con un árbol de búsqueda optimizado, que busque el mínimo real de cada sala ya guardada y corrija el máximo de movimientos.
- Los trampolines (catapulta) quedan fuera por ahora.
- La biblioteca de salas actual (`data/salas.rooms`) se hizo con otras reglas (pilar de hierro, sostén direccional): hay que regenerarla.

## 7. Pendiente de definir

- Dónde queda el bloque de salida dentro de la huella y qué anclas de verificación lo sostienen.
- Cuántos movimientos de margen por etapa (la tabla de dificultad).
- Si al morir también se reconstruye la sala anterior (la que cayó al llegar al checkpoint) o queda caída.
- Qué altura máxima real tiene cada tamaño de sala una vez que el temporizador esté en juego.
