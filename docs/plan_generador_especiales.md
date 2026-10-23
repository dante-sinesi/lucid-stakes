# Plan: generador de salas con bloques especiales

Parte del generador que ya funciona (`native/salas.cpp`, ver `docs/progreso_salas_nuevas.md`). Sin bombas por ahora. Este documento es un plan para revisar, no código.

## 1. Por qué el generador actual casi no hay que cambiarlo

La construcción de una sala es hacia atrás: cada paso es un estado desde el cual UNA acción del motor lleva al actual, comprobado simulando hacia adelante con las reglas del juego. Eso significa que **el generador no conoce las reglas**: las reglas de cada bloque especial ya están en el motor (`torre/motor.gd` y `native/salas.cpp`) y la comprobación hacia adelante las respeta sola. Lo que hace falta es:

1. **Armar la sala resuelta con especiales** de modo que la solución los use (hoy es una escalera de bloques comunes).
2. **Dejar que el desordenado los entienda** (en tres casos hay que agregar candidatos de estados anteriores que hoy no se generan: ver cada bloque).
3. **Mutaciones** de la escalada local que cambien el tipo de un bloque.
4. **Prueba de necesidad**: un especial vale sólo si cambiarlo por un bloque común cambia la solución (más larga, o sin solución). Ya hay una versión en la búsqueda de módulos del cilindro (`cilindro/modulos.gd`, `necesidad`); hay que pasarla al ejecutable nativo.
5. **Pruebas del motor para cada tipo** (hoy los especiales del motor nuevo no tienen pruebas propias: se copiaron del juego actual).
6. **Métrica** (`--medir`): ya cuenta los movimientos legales de cualquier tipo; sólo hay que confirmar que los especiales entran bien (por ejemplo, el hielo agrega movimientos que resbalan).

**Comprobado (paso 1 del plan, hecho):** `torre/test_especiales.gd` arma salas chicas al azar con cada tipo y compara el motor de GDScript con el nativo: 87 salas comparadas (pesado, agrietado, pinchos, trampa, hielo y catapulta), 0 diferencias en la solución, y los caminos nativos ganan jugados en GDScript. Es poca muestra para el hielo y la catapulta (los casos más delicados): conviene repetirla con más salas antes de usarlos.

## 1b. Los especiales son verbos, no cantidades (corrección del usuario)

Un especial no se agrega "porque sí" ni por cantidad: **cambia cómo se juega la sala**. Cada tipo tiene un papel, y el generador lo pone **por propósito** y lo valida con una prueba de efecto:

| Bloque | Papel (qué le hace al jugador) | Cómo se coloca | Prueba de que cumple su papel |
|---|---|---|---|
| **Pesado** | molestar y limitar: no se puede traer ni llevar | se mira la solución de la sala sin especiales y se vuelve pesado un bloque que ESA solución movía (o el que ocupaba una celda clave): obliga a rodear, colgarse o usar otro material | con el pesado la solución exacta es más larga o usa otros bloques; si cambiarlo por común no cambia nada, es decorado y se descarta |
| **Agrietado** (arenisca) | que cada decisión tenga consecuencia: se pisa una vez | se vuelven agrietados los escalones que la solución pisa y deja atrás: ya no se puede volver ni reconsiderar | sube el peligro medido (bits de peligro, movimientos letales) sin que la sala deje de tener solución; sacarle lo agrietado permite un camino más corto o con vuelta atrás |
| **Hielo** | cuidado al resbalar, pero también transporte si hay línea | una línea de hielo de 2 o más celdas donde deslizarse ahorra pasos, con un borde cerca donde un resbalón es letal | la solución exacta USA un deslizamiento (de 2 o más celdas) y hay movimientos letales por resbalar; si cambiarlo por común acorta o alarga la solución, es útil |
| **Trampolín** | atajo vertical que hay que ganarse: salto, no escalera | un tramo de escalera se reemplaza por la catapulta y se dejan bloques señuelo que parecen servir para escalar y no alcanzan | con el trampolín la sala se resuelve; cambiado por común no tiene solución (o es mucho más larga) |
| **Pinchos** | celdas prohibidas: obligan a rodear o a colgarse | se ponen donde el camino más corto habría pisado | cambiados por común, la solución se acorta |

**Cómo sale la cantidad:** no se decide de antemano. La colocación es un bucle "adversario": (1) se resuelve la sala; (2) se pone el especial en el lugar que le rompe el paso más barato a esa solución; (3) se vuelve a resolver con el solucionador exacto; (4) se acepta si sigue teniendo solución y la prueba de efecto da positivo; (5) se repite mientras cada especial nuevo sume. Cuantos especiales aguanta una sala es un resultado, no un parámetro.

**Estructura de la herramienta:** un segundo paso sobre salas ya generadas (`salas.exe --especializar rol=pesado ...`), no un generador distinto: la sala base sigue saliendo del generador que ya funciona y la especialización la modifica y la vuelve a verificar. Así lo ya validado no se toca.

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
1. **Pruebas del motor por tipo** en `torre/` (GDScript y nativo, mismas respuestas): una sala chica por cada especial con su camino conocido.
2. **Pesado**: parámetro `especiales=h:2` en el generador, el desordenado y la escalada lo respetan, y prueba de necesidad en el ejecutable (`--necesidad`). Medir con la métrica.
3. **Pinchos**, igual que el pesado; se elige la celda mirando el camino más corto.
4. **Agrietado**: candidato nuevo hacia atrás + prueba de necesidad.
5. **Trampolín**: candidato nuevo hacia atrás y armado de la sala resuelta con el tramo de escalera reemplazado y los bloques señuelo.
6. **Hielo**.
7. En cada paso: capturas desde el Estudio (el Estudio ya dibuja todos los tipos con los modelos del juego), salas guardadas con el campo `especiales`, y niveles de dificultad por la misma métrica.

## 4. Decisiones
- "Arenisca" es el bloque agrietado (confirmado).
- La cantidad de especiales no es un parámetro: sale del bucle de colocación por propósito (sección 1b).
- Pendiente: en qué etapas del juego aparece cada tipo (así se enseñan de a uno) y cómo entran en la escalera de dificultad.
