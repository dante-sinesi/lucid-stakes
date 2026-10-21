# Plan: generador de salas con bloques especiales

Parte del generador que ya funciona (`native/salas_nuevas.cpp`, ver `docs/progreso_salas_nuevas.md`). Sin bombas por ahora. Este documento es un plan para revisar, no código.

## 1. Por qué el generador actual casi no hay que cambiarlo

La construcción de una sala es hacia atrás: cada paso es un estado desde el cual UNA acción del motor lleva al actual, comprobado simulando hacia adelante con las reglas del juego. Eso significa que **el generador no conoce las reglas**: las reglas de cada bloque especial ya están en el motor (`salas_nuevas/motor.gd` y `native/salas_nuevas.cpp`) y la comprobación hacia adelante las respeta sola. Lo que hace falta es:

1. **Armar la sala resuelta con especiales** de modo que la solución los use (hoy es una escalera de bloques comunes).
2. **Dejar que el desordenado los entienda** (en tres casos hay que agregar candidatos de estados anteriores que hoy no se generan: ver cada bloque).
3. **Mutaciones** de la escalada local que cambien el tipo de un bloque.
4. **Prueba de necesidad**: un especial vale sólo si cambiarlo por un bloque común cambia la solución (más larga, o sin solución). Ya hay una versión en la búsqueda de módulos del cilindro (`cilindro/modulos.gd`, `necesidad`); hay que pasarla al ejecutable nativo.
5. **Pruebas del motor para cada tipo** (hoy los especiales del motor nuevo no tienen pruebas propias: se copiaron del juego actual).
6. **Métrica** (`--medir`): ya cuenta los movimientos legales de cualquier tipo; sólo hay que confirmar que los especiales entran bien (por ejemplo, el hielo agrega movimientos que resbalan).

## 2. Los tipos, del más fácil al más difícil

Orden propuesto (distinto al tuyo en un punto: pinchos antes que el trampolín, porque no necesitan generar candidatos nuevos hacia atrás):

| # | Bloque | Qué cambia para el generador | Esfuerzo | Riesgo |
|---|---|---|---|---|
| 1 | **Pesado** | Nada hacia atrás: es un bloque quieto. Sólo hay que dejarlo sin mover al desordenar y en las mutaciones. | bajo | casi nada |
| 2 | **Pinchos** | Nada hacia atrás: se empujan y se tiran como un común y se pierde al pisarlos. Sólo hay que ponerlos y comprobar que importan. | bajo | que sobren (decorado) |
| 3 | **Agrietado (arenisca)** | Hacia atrás hay un candidato nuevo: el estado anterior tiene el bloque agrietado debajo de donde estaba parado el jugador (el motor lo rompe al bajarse). | medio | que rompa la solvencia sin que se note |
| 4 | **Trampolín (catapulta)** | Hacia atrás hay un candidato nuevo importante: el estado anterior es con el jugador parado al lado de la catapulta, varios pisos más abajo. Además hay que diseñar el borde donde se agarra arriba. | medio-alto | alturas y bordes; el solucionador por lonjas |
| 5 | **Hielo** | Hacia atrás hay dos candidatos nuevos: el bloque o el jugador estaban en cualquier celda de la línea por la que se deslizó. | alto | caídas fuera de la torre, mucha explosión de estados |

Trampa (la marca roja) y arenisca: asumo que "arenisca" es el bloque agrietado del juego (se rompe al bajarte); si es otra cosa, avisame.

### 2.1 Pesado (bloque que no se mueve)
- **Sala resuelta:** a algunos bloques de la escalera o del material extra se les cambia el tipo a pesado. Se puede trepar por encima y sostiene lo que toca igual que un común.
- **Qué lo hace útil:** limita la libertad: el material pesado no se puede traer ni llevar, así que define la forma de la sala; una columna de pesados sirve de pilar o de pared.
- **Desordenado:** los pesados no se mueven (igual que el checkpoint de entrada). La escalada tampoco los mueve; sí puede cambiar un común por uno pesado como mutación.
- **Necesidad:** sacarle la propiedad (volverlo común) debe acortar la solución o abrir otra; si no, es decorado.
- **Primer experimento:** 3x3 y 5x3 con 1 a 3 pesados, comparar complejidad con y sin ellos.

### 2.2 Pinchos
- **Sala resuelta:** se agregan como material extra en lugares donde el camino más corto habría pisado de no estar (celdas prohibidas). La solución tiene que esquivarlos (colgándose de ellos, o moviendo bloques para pasar por otro lado).
- **Hacia atrás:** sin cambios; los pinchos se mueven como un común.
- **Necesidad:** cambiarlos por común debe acortar la solución. El generador puede elegir la celda de los pinchos mirando por dónde pasa el camino más corto: es la técnica de Catherine de usar bloques hostiles como obstáculo (colgarse de ellos no los activa).
- **Riesgo:** que sean decorado (fuera del camino): se descartan con la prueba de necesidad.

### 2.3 Agrietado (arenisca)
- **Efecto del motor:** se rompe al bajarte de él (queda un hueco) y lo que se apoyaba en él cae por falta de apoyo.
- **Sala resuelta:** un tramo de la escalera es de agrietado: sólo se puede pisar una vez, así que el recorrido tiene un sentido y el jugador no puede volver sobre sus pasos.
- **Hacia atrás:** candidato nuevo: el estado anterior es "el mismo estado pero con un bloque agrietado en la celda de abajo de donde estaba parado el jugador antes de bajarse". Se genera con las celdas vecinas del jugador y se comprueba hacia adelante como todos.
- **Necesidad:** cambiarlo por común debe permitir un camino más corto (por ejemplo, ir y volver).

### 2.4 Trampolín (catapulta)
- **Efecto del motor:** al quedar parado sobre una catapulta el jugador sube 4 celdas (más hasta 2 buscando agarre) y se cuelga del costado de un bloque que tenga el borde de arriba libre.
- **Sala resuelta (tu idea):** se toma un tramo de la escalera de unos 4 a 6 pisos y se lo reemplaza por la catapulta en la base y un bloque de llegada arriba con el borde libre. Para que parezca que se puede subir en escalera se dejan algunos bloques sueltos en esos niveles que no alcanzan para armar una (por ejemplo, cortados o desconectados): el jugador cree que tiene material, y en realidad la única solución es saltar. Se completa con la prueba de necesidad (cambiar la catapulta por un común deja la sala sin solución).
- **Hacia atrás:** candidato nuevo: el estado anterior al despegue tiene al jugador parado al lado de la catapulta (en la celda desde la que camina hacia ella) y no donde quedó colgado. Se generan, para cada catapulta, las 4 celdas vecinas.
- **Solucionador:** la heurística ya considera la catapulta (pisos que faltan divididos por 7). Las lonjas de 3 pisos funcionan porque el salto cumple el subobjetivo; hay que probarlo.
- **Decisiones tuyas:** cuántas celdas sube (hoy 4 + 2 de alcance), si el borde de llegada puede estar en cualquier lado, cuántas catapultas por sala.

### 2.5 Hielo
- **Efecto del motor:** el bloque de hielo empujado resbala hasta chocar; el jugador que llega parado sobre hielo sigue resbalando; no se puede colgar de su borde; salir de la torre al resbalar es perder.
- **Hacia atrás:** dos candidatos nuevos: un bloque de hielo estaba en cualquier celda de la línea por la que llegó a donde está, y el jugador estaba en cualquier celda de la línea por la que resbaló.
- **Riesgo:** la cantidad de estados crece mucho (cada empuje de hielo mueve un bloque varias celdas); las salas con hielo van a ser más difíciles de demostrar.
- **Recomendación:** dejarlo para el final, cuando ya esté probado todo lo demás.

## 3. Pasos de trabajo propuestos
1. **Pruebas del motor por tipo** en `salas_nuevas/` (GDScript y nativo, mismas respuestas): una sala chica por cada especial con su camino conocido.
2. **Pesado**: parámetro `especiales=h:2` en el generador, el desordenado y la escalada lo respetan, y prueba de necesidad en el ejecutable (`--necesidad`). Medir con la métrica.
3. **Pinchos**, igual que el pesado; se elige la celda mirando el camino más corto.
4. **Agrietado**: candidato nuevo hacia atrás + prueba de necesidad.
5. **Trampolín**: candidato nuevo hacia atrás y armado de la sala resuelta con el tramo de escalera reemplazado y los bloques señuelo.
6. **Hielo**.
7. En cada paso: capturas desde el Estudio (el Estudio ya dibuja todos los tipos con los modelos del juego), salas guardadas con el campo `especiales`, y niveles de dificultad por la misma métrica.

## 4. Qué hay que decidir con vos antes de empezar
- ¿Pesados, pinchos, agrietados, trampolines y hielo, en ese orden? ¿O querés el trampolín antes?
- Cantidad de especiales por sala y por nivel de dificultad (por ejemplo: ninguno en tutorial, 1 en fácil, hasta 3 en pesadilla).
- ¿"Arenisca" es el agrietado?
- Si los especiales tienen que aparecer de a uno por etapa del juego (así se enseñan) o mezclados desde la primera pesadilla.
