# Torres con ideas: borrador de diseño (sin código)

Estado: **borrador para conversar**. Nada de esto está implementado. Sirve para decidir qué es una torre "viva" y cómo se mide, antes de tocar el generador.

## 1. El problema

El generador actual produce torres correctas pero repetitivas: casi toda solución es "mover el bloque de abajo y armar una escalera", con alguna vuelta de más. Hay tres repeticiones distintas:

1. **De técnica**: siempre se resuelve igual.
2. **Visual**: las formas se parecen.
3. **De ritmo**: todas las filas piden un esfuerzo parecido; no hay respiros ni picos.

Una biblioteca finita de piezas no lo arregla: quien la aprende ve siempre lo mismo, y aunque cambie el orden se nota. Lo que hay que variar es **qué hay que pensar**, no solo la forma. Un jugador puede aprender las *ideas* (eso es la habilidad, como en Catherine), pero no debería poder memorizar *soluciones*.

## 2. La unidad: la "idea"

Cada idea es un puzzle con:

- **Premisa**: lo que el jugador tiene que descubrir (el "ajá").
- **Técnica**: lo que hace para resolverlo.
- **Giros**: variantes que **cambian la solución**, no solo la forma (más largo, otra cantidad, otro orden, otro bloque suelto).
- **Profundidad**: cuántos pasos de planificación pide.
- **Composiciones**: con qué otras ideas se puede combinar.

Una torre es una secuencia de ideas con giros, armada con ritmo (ver 4). La frescura sale de: ideas × giros × composiciones × parámetros que se sortean al armar.

## 3. Cómo se mide la dificultad de una sección

Idea de Dante: la dificultad depende de **cuántos movimientos pide** y de **cuántas formas hay de resolverla**.

Se mide, con el solucionador, sobre la sección sola:

- **M** = mínimo de movimientos para resolverla.
- **S** = cuántas soluciones distintas hay (distintas = otra técnica o otro orden de lo importante, no un paso de más al costado).
- **T** = tolerancia a errores: de todos los estados a los que se puede llegar en los primeros movimientos, qué fracción todavía permite resolverla (1 = no se puede arruinar; bajo = castiga).
- **I** = puntos sin retorno: cuántas decisiones son irreversibles (cruzar la arenisca, hacer explotar la bomba, soltarse).

Dificultad ≈ sube con M, baja con S, sube cuando T es baja y sube con I. Ejemplos:

- 2 movimientos, 3 formas → muy fácil.
- 5 movimientos, 1 forma → difícil.
- 5 movimientos, 1 forma y sin margen de error (T baja, con puntos sin retorno) → la más difícil.

Los pesos se calibran jugando (ver 6). Este número también sirve para ordenar los tramos de una torre y para ajustar a cada etapa.

## 4. Ritmo de una torre

Una torre no es una pared pareja de dificultad. Cada torre tiene un **arco**:

- **Respiros**: secciones fáciles (pocos movimientos, varias formas) después de una difícil.
- **Puzzles medios y altos**, intercalados, con la dificultad base subiendo con la etapa.
- **Tramos grandes**: cada cierto tiempo una sección larga y memorable (5 a 7 pisos), con una idea protagonista y, a veces, dos compuestas. Se reconocen a simple vista (una forma propia de la torre).
- **Tensión**: la única presión de tiempo es la caída de la fila de abajo. Algunos tramos grandes están hechos para jugar con eso (largos, que exigen ir sin dudar).

## 5. Un primer catálogo de ideas (para cortar, cambiar o agregar)

Pensadas con las mecánicas que ya existen: empujar y tirar (hasta 3 bloques en fila), colgarse y moverse por cornisas, hielo, catapulta (sube 4 y se agarra de un borde), agrietados, pesados, bombas con cuenta, trampas, pinchos, y la caída de la fila de abajo.

1. **Cruce sin retorno (arenisca).** *Premisa*: cruzar rompe el puente; lo que necesites del otro lado tiene que estar preparado antes. *Técnica*: planificar qué dejar listo. *Giros*: cuántos agrietados, qué falta al otro lado (un escalón, un freno), si el borde de llegada es alto. *Profundidad*: media. *Composición*: con hielo (resbalar sobre el puente) o con bomba.
2. **Hielo y freno.** *Premisa*: deslizarse hasta el borde y caer; hay que poner antes un bloque que frene en la celda exacta. *Técnica*: colocar el freno y entrar por el carril correcto. *Giros*: dos carriles con frenos distintos, el vacío de un lado, un bloque pesado como freno fijo. *Profundidad*: media-alta.
3. **Trampolín y pared.** *Premisa*: la catapulta solo llega si hay un borde justo a la altura del salto. *Técnica*: preparar la pared (empujar columnas) y entrar con el ángulo correcto. *Giros*: altura de la pared, qué lado tiene el borde, un techo que corta el salto. *Profundidad*: media.
4. **Cornisa.** *Premisa*: el camino está pegado a la pared y solo se avanza colgado. *Técnica*: colgarse, rodear esquinas hacia adentro y hacia afuera, trepar. *Giros*: huecos entre columnas, esquinas dobles, un tramo de hielo que no se puede agarrar. *Profundidad*: baja-media (técnica de manos).
5. **Pared pesada.** *Premisa*: lo pesado no se mueve; hay que descubrir cuál de varios bloques sí. *Técnica*: leer el entorno y buscar el suelto. *Giros*: cuántos pesados, dónde está el suelto, si hace falta empujar dos en cadena. *Profundidad*: baja-media.
6. **Cuenta de bomba.** *Premisa*: la bomba cuenta cada movimiento a su altura; hay que llegar justo para desactivarla. *Técnica*: planificar el camino exacto. *Giros*: la cuenta, desvíos obligatorios, una segunda bomba. *Profundidad*: media.
7. **Lectura de trampas y pinchos.** *Premisa*: el camino seguro existe pero no es el recto. *Técnica*: leer y rodear. *Giros*: pinchos a ras del piso, cruces rojas en cadena, el camino seguro más largo. *Profundidad*: baja (pero castiga).
8. **Fila exacta.** *Premisa*: se empuja una fila de bloques a un hueco; si la fila es más larga que el hueco, sobra; si es más corta, no llega. *Técnica*: contar. *Giros*: largo de la fila y ancho del hueco, un bloque pesado en medio. *Profundidad*: media.
9. **El orden.** *Premisa*: dos bloques que hay que mover en un orden preciso; el contrario los traba. *Técnica*: planificar la secuencia. *Giros*: tres bloques, un carril compartido. *Profundidad*: alta.
10. **Atajo tentador.** *Premisa*: una escalera evidente lleva a un callejón sin salida; el camino correcto es más largo. *Técnica*: desconfiar. *Giros*: qué tan evidente es el atajo y dónde se descubre el error. *Profundidad*: media (castiga).
11. **Bajar para subir.** *Premisa*: hay que descender por una cornisa a un rincón bajo, tirar de un bloque y subir por otro lado. *Técnica*: pensar al revés (bajar es parte del camino). *Giros*: cuánto se baja, qué hay abajo. *Profundidad*: alta.
12. **La carrera (tramo grande).** *Premisa*: un tramo largo con varias ideas encadenadas y la fila de abajo cerca: no hay tiempo de dudar. *Técnica*: conocer las ideas y ejecutarlas sin pausa. *Giros*: qué ideas se encadenan. *Profundidad*: alta, pero cada paso es conocido.

Composiciones que valen la pena: hielo + arenisca, trampolín + cornisa, bomba + fila exacta, orden + pesado, atajo tentador + cualquiera.

## 6. Cómo se aprende y cómo se evita la repetición

- **Escalera de ideas**: cada idea se presenta "pura" cuando se desbloquea su bloque (hielo en la etapa 2, pesado en la 3, etc.), después aparece con giros, y mucho más tarde combinada.
- **Memoria de lo visto**: el perfil guarda las últimas ideas con su giro; no se repite la misma idea con el mismo giro seguida, ni dos veces la misma idea seguidas en una torre, y cada torre intenta traer al menos una idea que no apareció en las últimas.
- **Parámetros que se sortean al armar**: posición en la huella, simetría, largo, cuenta de bombas, cuál bloque es el suelto, dónde van los señuelos. Una misma idea con distinto giro pide otra solución.

## 7. Qué se verifica de cada sección (para que cumpla lo previsto)

Cada idea declara qué promete. Se verifica con el solucionador, y si no cumple, la sección se descarta:

- **El bloque protagonista es necesario**: tratarlo como común cambia o rompe la solución.
- **La técnica protagonista es la que se usa** (no cae en "armar una escalera").
- **La dificultad medida (M, S, T, I) cae en el rango pedido** por el lugar del ritmo donde se la quiere poner.
- **No hay solución trivial** (que se salte la idea).
- **Se puede perder, pero no por azar**: los errores son legibles (se ve por qué fallaste).

## 8. Calibrar "divertido" jugando

Las medidas anteriores son un sustituto de lo divertido. Para ajustarlas: se generan unas 30 secciones que cubran distintos valores de M, S, T, I, se juegan y se puntúan (1 a 5 con una etiqueta: aburrida, frustrante, buena, brillante), y se ajustan los pesos para que el puntaje de la máquina prediga el gusto del jugador.

## 9. Preguntas abiertas

- ¿Cuánto debería durar una sección en tiempo y movimientos? (pensar + ejecutar)
- ¿Qué porcentaje de una torre son respiros, puzzles y tramos grandes?
- ¿Qué momentos de Catherine son el modelo a seguir?
- ¿Qué ideas del catálogo se cortan y cuáles faltan?
- ¿Cuánto castigo es aceptable (reintentos) cuando una sección no admite fallas?

## 10. Reglas de composición v0 (implementadas en el prototipo)

Con una sola idea hecha (la pared de pinchos) y los respiros del generador de siempre, más fáciles:

1. Una torre de 25 pisos es una secuencia de tramos: **respiros** (1 a 3 pisos) y **tramos de idea** (4 pisos).
2. Cuántos tramos de idea: de 2 (etapa 1) a 5 (etapa 15), `2 + dificultad * 3`.
3. Nunca dos ideas seguidas; los dos primeros pisos son respiro.
4. La dificultad pedida a las ideas (rango de movimientos) sube de una a la siguiente.
5. Cada tramo de idea termina en una plataforma de salida de 3 o 4 celdas, para que el siguiente tramo empiece sobre ella.
6. Cada tramo se verifica en su contexto con el solucionador (se resuelve, hay que mover bloques, la solución mueve pinchos); si no cumple se sortea otro, y si ninguno cumple ese lugar queda como respiro.
7. La torre completa se cierra como siempre (portal, margen de la caída de la fila de abajo).

Comando de prueba: `idea_torre [semilla]` (consola F1) arma una torre completa con estas reglas.
