# Evaluación del generador de torres: alternativas y cómo validarlas con datos

Documento de planificación (no se programó nada). Objetivo: elegir el camino para un generador que dé torres **del calibre de Catherine**, que **no tarde años** en generar y que **le guste al jugador**, decidiendo con mediciones y no con intuición.

## 1. Qué significa "buen generador": tres ejes medibles

| Eje | Pregunta | Cómo se mide | Quién mide |
|---|---|---|---|
| **Rendimiento** | ¿Cuánto cuesta producir una sala/torre válida? | ms por sala aceptada (mediana y p95), rendimiento (aceptadas / intentadas), tiempo por torre por etapa, determinismo por semilla | Máquina (banco de pruebas) |
| **Dificultad** | ¿La sala pide trabajo de verdad y no tiene atajos? | Con el solucionador completo: bloques distintos movidos, agarres, largo del camino más corto, relación óptimo / plantado, costo de errores (callejones), caminos distintos. Con un "jugador de miras cortas" (búsqueda limitada): ¿la resuelve? ¿en cuántos pasos? | Máquina |
| **Atractivo** | ¿Se siente como un puzzle, es variado, da ganas de seguir? | Pruebas con personas: comparación ciega de pares, valoración 1–5 por sala, telemetría de juego (tiempo, deshacer, reinicios, abandono), y "¿ya vi esta sala?" | Personas |

Hoy solo tenemos buenas herramientas para los dos primeros. **El atractivo es el eje sin datos**, y es el que más importa; el plan lo tiene que atacar de frente.

### Métricas de dificultad (definición cerrada)
1. `moved`: bloques DISTINTOS movidos en el camino más corto (la que importa).
2. `grabs`: empujes y tirones del camino más corto.
3. `opt`: largo del camino más corto; `ratio = opt / plantado` (1 = sin atajo).
4. `plain`: ¿se resuelve sin mover ningún bloque? (debe ser no).
5. `states`: estados que explora el solucionador (cuántos caminos tentadores hay).
6. `error_cost`: fracción de posiciones alcanzables sin salida (castigo del error).
7. `myopic`: éxito y pasos de un jugador de miras cortas (beam de ancho 3, profundidad 6) — mide qué tan **evidente** es la sala, que el solucionador óptimo no mide.
8. `tempo`: movimientos por fila subida.

### Qué es "el calibre que querés" (hay que fijarlo con datos de Catherine)
El número de referencia que usamos hasta ahora ("~15 movimientos de bloque cada 3 filas") es una estimación a ojo. **Primer entregable: un conjunto de referencia.** Transcribir 15–25 tramos de Catherine (de tus grabaciones y la wiki) a nuestro formato y calcular con las mismas métricas. Así "calibre Catherine" deja de ser una frase y pasa a ser una banda: por ejemplo "moved entre 8 y 14 por tramo de 3 filas, plain = no, myopic < 30 %". Si no se puede transcribir, la alternativa es que vos juegues tus mejores salas actuales y marques cuáles "son del calibre" y cuáles no, y calibramos con eso.

## 2. Lo que ya sabemos (datos)

| Dato | Valor | Fuente |
|---|---|---|
| Tiempo de generar una torre, un hilo, motor de editor | etapa 5: 92 s; 8: 145 s; 10: 295 s; 13: 368 s; 15: 358 s | `tests/bench_gen.gd` |
| Mismo, motor de lanzamiento | 85 / 109 / 226 / 267 / 288 s (8–27 % menos) | idem |
| Sala chica con altura (`chica`) | 40–70 s por sala, 4–7 agarres | `probe_reja`, `probe_seed` |
| Sala mediana (dos salas apiladas) | 55–110 s por sala, 8–11 agarres en total | idem |
| Salas medianas por búsqueda al azar | 31 de 40 sin resolver en el tope | `tests/exp_vert.gd` |
| Construir hacia atrás desde la sala resuelta | distancia reversible ~25, óptimo real ~10 (atajos irreversibles) | exploración inversa |
| Cadenas de movimientos (4x4, pilar 4, 20 000 intentos) | 6,4 % llegan a la meta; 89 % con atajo; 141 buenas con 4+ bloques (35 con 5+, 10 con 6+); ~1 buena cada 1,5 s | `docs/experimento_cadenas.md` |
| Cadenas en arena 5x4, pilar 5 | 1,2 % llegan; 50 buenas con 4+ bloques; 3 con 6+ | idem |
| Recortar la búsqueda actual a la mitad | ahorra poco tiempo y baja la calidad (salas que fallan) | prueba del 13/10 |

Conclusiones que ya se sostienen con datos:
- El costo está en el solucionador y en los candidatos que no se resuelven.
- Muestrear mucho y filtrar con el solucionador es barato y rinde; construir la dificultad "a mano" paso a paso, no.
- Las salas chicas topan en 4–6 bloques distintos; la dificultad alta pide salas más grandes o composición.

## 3. Alternativas a evaluar

Cada una con: idea, qué se probaría, hipótesis, esfuerzo de la prueba y riesgo.

### A. Generador actual (ideas + módulos) — línea base
Qué es: `rooms.gd` con ideas, `taller`, `chica`, `mediana`. **Medir en grande** (200 salas por tipo) para tener la línea base: rendimiento, banda de dificultad, variedad. Esfuerzo: bajo.

### B. Muestreo masivo + filtro del solucionador ("generar y probar", ya medido en chico)
Idea: terreno aleatorio o por cadenas, el solucionador filtra por dificultad. Hipótesis: con un solucionador rápido da salas buenas baratas. Prueba: ya hecha en 4x4; falta medianas y grandes y un jugador de miras cortas. Riesgo: techo de dificultad bajo.

### C. Búsqueda local con el solucionador como función objetivo (estilo Rush Hour)
Idea: partir de una sala, cambiar una pieza y conservar el cambio si sube el costo (`moved`, `states`). Es lo que hacen `taller` y `chica` en pequeño. Hipótesis: con un solucionador 10× más rápido, escala a salas medianas y rompe el techo de B. Prueba: recocido simulado sobre 5x5 y 3x8 con 5 000 evaluaciones; medir la curva "dificultad vs. evaluaciones". Esfuerzo: medio. Riesgo: óptimos locales y sensación de "monstruo raro".

### D. Construcción inversa con candados
Idea: deshacer desde la sala resuelta eligiendo movimientos que traban. Datos previos: el desorden al azar se aleja poco (6–11 movimientos) y la distancia reversible sobreestima. Prueba acotada: elegir los deshacer con una cuenta de dependencias; medir `ratio`. Esfuerzo: medio. Riesgo: alto de atajos.

### E. Plantillas con ranuras (esqueleto diseñado + relleno aleatorio + giro)
Idea: salas de 3–5 esqueletos por tema con ranuras de tipo de bloque, alternativas y relleno. Hipótesis: da diseño intencional (trampas pensadas) con variedad suficiente. Prueba: diseñar 5 esqueletos, generar 100 variantes de cada una, medir variedad (distancia entre descriptores) y dificultad, y mostrar 20 a personas para ver si "se sienten distintas". Esfuerzo: medio-alto (diseño a mano). Riesgo: la variedad percibida.

### F. Salas de autor en volumen, con transformaciones (rotar, espejar, cambiar de tipo)
Idea: como los Babel de Catherine. Datos del brainstorming: 100–250 salas no alcanzan para sostener interés; las transformaciones multiplican por 8 pero el jugador reconoce el patrón. Prueba: no hace falta construirla; se mide con la tabla de repetición y con una prueba de "¿ya vi esta?" usando salas actuales giradas. Esfuerzo: bajo para medir. Riesgo: trabajo manual enorme.

### G. **Minado fuera de línea + biblioteca curada (nueva)**
Idea: no generar en el juego. Generar **decenas de miles de salas** de noche con el mejor método disponible (B/C), medirlas con todas las métricas, quedarse solo con las que entran en la banda "calibre", y que el juego **elija y combine** en tiempo de ejecución (apilar, girar, espejar, cambiar de tipo). Una sala son unos bytes; 50 000 salas ocupan pocos MB. Hipótesis: resuelve a la vez el tiempo (la espera pasa a ser cero) y la calidad (se puede curar con ojos humanos lo mejor). Datos: B da ~2 400 salas buenas por hora por hilo en 4x4; con 4 hilos y una noche son decenas de miles. La tabla del brainstorming dice que con 10 000 salas la repetición en la partida 4 baja a ~3 %; con transformaciones y composición, mucho menos.
Prueba: generar 20 000 salas chicas por la noche, medir distribución de métricas y variedad; mostrar una muestra a personas. Esfuerzo: bajo-medio. Riesgos: ya rechazaste "cosas prehechas" una vez; la diferencia aquí es la escala y que cada sala nació aleatoria. **Decisión para vos.**

### H. Aprendizaje automático: un juez que predice la dificultad (suplente del solucionador)
Idea: una red pequeña que predice `moved` y "si sirve" sin correr el solucionador (entrenada con datos de B/C). Hipótesis: acelera 100× el filtrado y deja explorar más. Prueba: con los datos de la prueba G, entrenar un modelo simple y medir el error de predicción. Esfuerzo: medio (Python). Riesgo: bajo, pero solo vale si el solucionador sigue siendo el cuello.

### I. Aprendizaje automático: generador (PCGRL, VAE)
Idea: aprender a generar salas. Hipótesis: da variedad, pero es opaco y costoso. Prueba: ninguna por ahora. Esfuerzo alto. Riesgo alto. Se deja fuera del plan a menos que A–H fallen.

### J. Programación con restricciones / SAT
Idea: pedir directamente "una sala donde el camino más corto mueva 8 bloques distintos". Hipótesis: da salas "óptimas" por construcción. Prueba: modelar una arena 4x4 de 3 pisos con un solver externo (OR-Tools / CP-SAT) y medir si encuentra instancias de dificultad exacta. Esfuerzo alto (otro lenguaje, otro modelo de reglas). Riesgo: mantener dos copias de las reglas. Solo para salas muy chicas.

### K. Acelerar el solucionador (habilitador, no es un generador)
Idea: portar solver y simulación a C++ (GDExtension) y optimizar copias de estado. Datos: el motor de lanzamiento solo da 8–27 %. Prueba: microbanco del solucionador en una sala fija y estimación de aceleración con una versión prototipo del bucle caliente. Esfuerzo: medio-alto. **Multiplica la capacidad de B, C, G y H**, así que conviene medirlo temprano.

### L. Ocultar la espera: generar por sala, mientras se juega (habilitador)
Idea: en lugar de torre completa, generar la sala siguiente mientras el jugador sube la actual. Hoy ya se generan las dos etapas siguientes. Cuesta poco y quita la espera percibida; no cambia la calidad. Prueba: simulación del presupuesto de tiempo: ¿cuánto tarda el jugador en cada sala vs. cuánto cuesta generar la siguiente? Esfuerzo: medio.

## 4. Banco de pruebas común (lo primero que hay que construir)

Un script `tests/eval_rooms.gd` que recibe cualquier conjunto de salas (de cualquier proveedor) y devuelve una tabla con todas las métricas de la sección 1, y un set fijo de semillas y etapas (5, 8, 10, 13, 15). Con eso toda alternativa se compara con **la misma regla**:

1. Costo por sala en banda: tiempo hasta tener 50 salas aceptadas dentro de la banda "calibre".
2. Distribución de dificultad: cuántas caen en la banda, por debajo y por encima.
3. Variedad: distancia entre descriptores (agarres, huella, técnicas usadas, alturas) y repetición exacta.
4. Resultados con `myopic`.

Y una **prueba humana estándar**: 10 salas por proveedor, mezcladas a ciegas, con valoración 1–5 por sala, "¿cuál prefieres?" por pares, y telemetría (tiempo, deshacer, reinicios).

## 5. Plan por fases

| Fase | Qué se hace | Entrega | Criterio para pasar |
|---|---|---|---|
| 0 | Fijar el calibre: conjunto de referencia de Catherine y/o tus salas favoritas; definir la banda por etapa | Tabla de banda por etapa | Estás de acuerdo con la banda |
| 1 | Banco de pruebas y línea base del generador actual | `eval_rooms` + tabla A | Reproducible con semilla |
| 2 | Microbanco del solucionador y prototipo de aceleración (K) | Aceleración medida | Decidir si vale portarlo |
| 3 | Pruebas cortas de B, C, D, E, G sobre el mismo banco (1–2 días cada una) | Tabla comparativa de rendimiento y dificultad | Al menos una entra en banda a costo razonable |
| 4 | Prueba humana a ciegas de las 2–3 finalistas | Valoraciones y telemetría | Gana la que dé mejor atractivo a costo aceptable |
| 5 | Plan de implementación del ganador (híbrido si hace falta) | Hoja de ruta | Aprobada por vos |

## 6. Lo que necesito de vos

1. **El calibre**: ¿puedo contar con tus grabaciones o una lista de tramos de Catherine que consideres la vara? Si no, ¿marcás tus mejores salas actuales?
2. **La biblioteca fuera de línea (G)**: ¿está descartada por principio o la ponemos a prueba con datos? Es la que más ataca el problema del tiempo.
3. **Cuánto tiempo de generación aceptás** en el peor caso en una partida normal (la primera torre de la partida, una torre de etapa 13): ¿2 minutos, 30 segundos, instantáneo?
4. **Quiénes pueden probar**: ¿tenés a 3–5 personas para la prueba a ciegas?
