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

## 6. Decisiones tomadas hasta ahora
- **Se pone a prueba la biblioteca precalculada (G).** "Fuera de línea" significa que se genera antes de publicar, en una PC sobrante que corre 24/7; el juego no necesita internet.
- Se usa el propio Godot: una escena "minero" exportada como `.exe` + `.pck`, con tantas copias como núcleos. Formato de trabajo: JSON Lines (una sala por línea, un archivo por copia); formato de publicación: binario comprimido, deduplicado y ordenado por dificultad.
- El generador actual pasa a ser **un proveedor más** del minero (y la red de seguridad del juego).

## 7. Cómo funcionaría el generador (hipótesis de arquitectura, a validar)

Tres piezas separadas:

```
 MINERO (PC sobrante, 24/7)      BIBLIOTECA (archivo)       ENSAMBLADOR (en el juego)
 proveedores -> medir ->  -->    salas con métricas  -->    elige, transforma, apila,
 filtrar -> deduplicar            + versión de reglas        verifica y arma la torre
```

### 7.1 La sala estándar ("enchufes")
Una sala de la biblioteca es independiente del resto de la torre y se describe en coordenadas relativas a su llegada:
- **Entrada:** el jugador llega parado en una celda de piso, a nivel 0, junto a la arena.
- **Salida:** celda de la cima de su columna de salida, a altura `h`; de ahí arranca la sala siguiente.
- **Huella:** celdas que ocupa (arena y camino) y qué tipo de piso lleva cada una.
- **Contenido:** bloques (celda relativa, tipo, fijo o no, temporizador si es bomba).
- **Camino más corto** (para revalidar sin buscar) y sus métricas.
- **Etiquetas:** tamaño (chica, mediana, grande), tema (hielo, bomba, trampas…), técnicas usadas, banda de dificultad, proveedor.
- **Versión de reglas** y **huella normalizada** (igual para giros y espejos).

Tamaños previstos: chica (3x3 a 3x5, 4–5 pisos), mediana (apilando dos chicas o una arena de 3x6 a 3x8, 8–10 pisos), grande (L de 5x5, hasta ~15 pisos).

### 7.2 El minero
1. **Proveedores:** el generador actual (`taller`, `chica`, `mediana`), el muestreo masivo con filtro (B) y, si pasan la prueba, la búsqueda local (C), las cadenas y las plantillas (E). Cada uno devuelve una sala estándar.
2. **Medición:** todas las métricas de la sección 1, con el solucionador completo y el jugador de miras cortas.
3. **Filtro por banda:** solo entran las salas dentro de la banda de calibre de su tamaño y etapa, sin atajo caminando, con la visibilidad mínima.
4. **Deduplicado** por huella normalizada y por cercanía de descriptores (para no guardar mil variantes de lo mismo).
5. **Salida:** una línea por sala en `minero_N.jsonl`, con cuenta de aceptadas por hora y por banda; reinicio automático si falla.

### 7.3 La biblioteca
- Se arma con un paso de empaquetado: une los archivos de todas las copias, revalida con las reglas actuales (descarta las que ya no funcionen), ordena por banda y tamaño, y escribe un binario comprimido.
- Metas de tamaño por banda (a ajustar con datos): por lo menos 1 500 salas distintas por banda de dificultad y tamaño; con giros, espejos y combinaciones el conjunto efectivo es mucho mayor. La tabla del brainstorming dice que ~10 000 salas dejan la repetición de la partida 4 en ~3 %.
- Control de calidad humano: una herramienta que muestra una muestra al azar por banda para marcar "buena / mala"; las malas se descartan y sus descriptores se usan para endurecer el filtro.

### 7.4 El ensamblador (tiempo de ejecución)
1. **Plan de torre:** secuencia de salas según etapa y dificultad (reglas actuales de ritmo: respiros, sin repetir tema ni tres salas del mismo tipo seguidas).
2. **Selección:** para cada hueco, elige de la biblioteca por banda, tamaño y tema, sin repetir salas dentro de la partida (y reduciendo la probabilidad de las vistas recientemente).
3. **Transformación:** giro y espejo para que entre en la huella libre; cambio de aspecto o de tipo solo si la etiqueta lo permite.
4. **Colocación y verificación:** se ubica con su llegada sobre la salida de la anterior; se comprueba el espacio libre; se repite el camino guardado en la torre real (milisegundos, sin buscar). Si falla (el entorno cambió algo), se prueba otra sala.
5. **Composición:** cuando hace falta una sala grande, se apilan dos o más de la biblioteca (verificadas de a una y en conjunto).
6. **Red de seguridad:** si no hay sala disponible o ninguna entra, cae al generador actual.
7. Tiempo esperado: menos de un segundo por torre.

### 7.5 Cuidado de la variedad y el atractivo
- Los jugadores no deberían reconocer "la misma sala" de una partida a otra: se mide con la prueba de repetición y con la pregunta "¿ya viste esta?" en las pruebas humanas.
- Distribución de descriptores objetivo (técnicas, tamaños, temas) por etapa, no solo la dificultad; así una torre no es "diez salas iguales".
- Telemetría opcional en el juego (siempre local): tiempo por sala, deshacer, reinicios; sirve para marcar salas que la gente abandona.

## 8. Plan por fases (revisado)

| Fase | Qué se hace | Entrega | Criterio para pasar | Esfuerzo |
|---|---|---|---|---|
| 0 | Fijar el calibre con tramos de Catherine y/o tus salas favoritas | Banda de calibre por tamaño y etapa | Aprobada por vos | S |
| 1 | Banco de pruebas y línea base del generador actual | `tests/eval_rooms.gd` + tabla A | Reproducible con semilla | M |
| 2 | **Sala estándar y enchufes:** formato, importar/exportar, colocarla en una torre con transformaciones y revalidar | Una sala del generador actual guardada, cargada, girada y verificada | Pasa la verificación en 100 salas | M |
| 3 | Microbanco y prototipo del solucionador rápido (K) | Aceleración medida | Decidir si se porta a C++ | M |
| 4 | **Minero v0** con el generador actual como proveedor; exportar a `.jsonl`; empaquetar | Un archivo de ~1 000 salas y el empaquetador | Rendimiento por hora medido | M |
| 5 | **Ensamblador v0:** armar una torre de etapa 10 desde la biblioteca, con verificación | Torre en menos de 1 s, jugable | Ganable con el camino guardado | M |
| 6 | Proveedores nuevos en el minero (B, C, cadenas, E) comparados con el banco | Tabla comparativa por rendimiento y dificultad | Al menos uno supera al actual en la banda | M c/u |
| 7 | Prueba humana a ciegas: biblioteca vs. generador actual vs. el mejor proveedor nuevo | Valoraciones y telemetría | Gana la biblioteca con atractivo >= al actual | S |
| 8 | Producción: la PC sobrante corre 24/7, revisión de muestras, ajuste de bandas, integración final | Biblioteca de 20 000+ salas | Metas de tamaño y variedad cumplidas | L (tiempo de máquina) |

S = menos de un día, M = 1–3 días, L = semanas de máquina con poco trabajo mío.

## 9. Riesgos principales y cómo se miden
| Riesgo | Cómo se detecta |
|---|---|
| La repetición se nota | Prueba "¿ya viste esta?" con 20 salas y 3–5 personas; tabla de repetición con el tamaño real |
| Las salas de la biblioteca son más fáciles que las actuales | `moved`, `myopic` contra la banda de la fase 0 |
| El entorno de la torre rompe una sala | Tasa de salas rechazadas al colocarlas (fase 5) |
| Los cambios de reglas invalidan todo | Versión de reglas + revalidación en el empaquetador |
| La PC sobrante rinde poco | Aceptadas por hora medidas en la fase 4; acelerar con la fase 3 |
| Atractivo igual de bajo | Prueba humana de la fase 7 antes de invertir semanas de minería |

## 10. Preguntas abiertas
1. **El calibre:** ¿tus grabaciones de Catherine o una lista de tramos como vara? Si no, tus salas favoritas del juego.
2. **Tiempo de espera aceptable** en el peor caso (hoy minutos; con la biblioteca, menos de 1 s).
3. **Quiénes pueden probar** a ciegas (3–5 personas).
4. **Salas con una sola entrada y salida:** ¿está bien que todas las salas de la biblioteca sean de ese tipo? (Las que bajan, o con varias salidas, serían una segunda familia.)
5. ~~Variaciones de aspecto~~ **Resuelto (ver sección 11.1):** sí se cambia el tipo de bloque, pero cada variante se verifica en el minero.

## 11. Decisiones nuevas (14/10) y lo que cambian

Respuestas de Dante a las preguntas abiertas:

1. **Variaciones de tipo de bloque: sí.** Ejemplo: en una sala donde hay que mover un bloque para pasar un muro de hierro, el bloque que se mueve puede ser común, de hielo o de arenisca: tres variantes de una misma sala.
2. **No se repiten salas.**
3. **Toda sala tiene un punto de entrada y uno de salida.**
4. **El generador no se limita a un tamaño:** hace todas las variantes: chicas (3x3), medianas (5x3), y formas en L, en U y en O (anillo), con **alturas de 4 hasta unos 20 pisos**.

### 11.1 Variantes de tipo: se verifican, no se asumen
Cambiar el tipo de un bloque **cambia la solución** (el hielo se desliza hasta chocar, el agrietado se rompe tras unos pasos, la bomba cuenta movimientos), así que no se puede cambiar al ensamblar sin volver a resolver. Se hace en el **minero**:
- Para cada sala aceptada, el minero prueba cambiar el tipo de cada bloque movible (y de los muros que se mueven) por cada tipo permitido, **resuelve de nuevo** y conserva la variante solo si sigue siendo resoluble, sin atajo y dentro de la banda.
- Cada variante es un registro propio, con `family` (la sala base normalizada sin tipos) y `variant_of`. El camino más corto de la variante puede ser distinto del de la base.
- Costo: una resolución por variante (milisegundos con las salas chicas). Multiplica la biblioteca por 2–4 sin tener que inventar salas nuevas.
- Medir: qué fracción de las salas admite al menos una variante, y si las variantes se **sienten** distintas (prueba humana: ¿es "la misma sala"?). Si el jugador las reconoce como la misma, valen menos para la repetición que como salas nuevas, y el recuento de variedad lo debe tener en cuenta (cada familia cuenta como una sala con 0,5 de crédito extra por variante, por ejemplo).
- "Arenisca" es el bloque agrietado actual (resuelto en la sección 12).

### 11.2 No repetir salas
- Cada registro tiene `id` y `family`.
- **Dentro de una torre:** ninguna `family` dos veces.
- **Dentro de una partida:** ningún `id` dos veces; una `family` puede volver solo con otro tipo de bloque y no antes de 5 salas.
- **Memoria entre partidas (opcional, local):** una lista de las últimas salas vistas, que baja el peso de lo ya visto. Se mide con la prueba de repetición.
- Prueba automática: simular 1 000 partidas completas y contar repeticiones por `id`, por `family` y por huella normalizada.

### 11.3 Formas y alturas
- **Formas:** chica 3x3; chica alargada 3x4–3x5; mediana 5x3; L, U y O (anillo con el hueco en el medio); más adelante grandes. Cada forma es una **huella** distinta con sus entradas y salidas posibles (en U y en O, la entrada y la salida pueden estar en puntas opuestas y obligar a rodear).
- **Alturas de 4 a 20 pisos:** el costo del solucionador sube muy rápido con la altura. Plan en dos niveles:
  - hasta ~10 pisos: salas **nativas** (el proveedor resuelve la sala entera);
  - de 10 a 20: **descartado el apilado** (ver sección 12.3): tienen que ser salas nativas, con el tope que marque la curva de costo.
  - Medir con datos: cuántos pisos nativos se alcanzan a costo razonable (curva "tiempo por sala aceptada vs. altura"). Medir también si un tramo apilado se siente como una sola sala o como "pilas de lo mismo" (prueba humana).
- **Entrada y salida:** estándar de cada huella; registradas en el formato de la sala.

### 11.4 Control de la mezcla de tamaños
El ensamblador no sorteará "una sala cualquiera" sino que respeta **cuotas por torre**: por ejemplo, de 6 a 10 salas por torre, al menos 2 formas distintas, no más de 3 del mismo tamaño seguidas, y la altura total que pide la etapa. Programar las cuotas como datos (tabla por etapa), no en el código, para ajustarlas con las pruebas.

### 11.5 Cambios a las fases
- **Fase 2 (sala estándar):** incluye huellas no rectangulares (L, U, O), alturas variables y los campos `family` y `variant_of`.
- **Fase 4 (minero v0):** agrega la etapa de variantes de tipo.
- **Fase 5 (ensamblador v0):** agrega no repetición y cuotas.
- **Fase nueva entre 4 y 5:** "formas y alturas": medir cuánto cuesta producir salas L/U/O y de 10–20 pisos y decidir qué se hace nativo y qué compuesto.

## 12. Decisiones nuevas (14/10, segunda tanda)

1. **"Arenisca" es el bloque agrietado actual** (se rompe después de pisarlo). No hay tipo nuevo: las variantes de tipo usan los tipos que ya existen.
2. **Se descartan las salas compuestas** para alturas de 10 a 20 pisos: "terminarían siendo dos salas". Reemplaza la segunda mitad de 11.3 (ver 12.3).
3. **Se pide un ejecutable de edición de salas** (ver 12.1) y **un hash de cada sala** para no repetir (ver 12.2).

### 12.1 Estudio de salas (ejecutable de edición y curado)
Un programa hecho con el mismo motor del juego (se exporta como `.exe`, igual que el minero) que abre la biblioteca y deja **ver, jugar, corregir y anotar** cada sala.

**Qué hace**
- **Ver:** navegar la biblioteca (filtros por tamaño, forma, altura, tema, banda de dificultad, estado), con la sala dibujada con el mismo aspecto del juego y cámara orbital; botón para **reproducir el camino más corto** (como hice en las capturas).
- **Editar:** seleccionar un bloque con el mouse y borrarlo, moverlo o cambiar su tipo; agregar bloques.
- **Marcar variantes:** seleccionar un bloque y declarar "puede ser también hielo, agrietado, común…". Es una **pista**, no una orden: al marcar, el Estudio vuelve a resolver la sala con cada tipo y muestra al instante cuáles son válidos (resoluble, sin atajo, dentro de la banda). Los que no, quedan tachados con la razón.
- **Verificación continua:** cada vez que se edita algo, se vuelve a resolver (en milisegundos si es una sala chica) y se muestran las métricas nuevas (bloques distintos movidos, agarres, atajos, si todavía se resuelve). Una sala editada que deja de resolverse no se puede guardar como "buena".
- **Salas parecidas:** muestra la **sala más parecida** (y las 5 más cercanas) con su **miniatura**, la distancia y en qué se parecen. Sirve para decidir "esta ya la tengo" y descartar.
- **Curado:** marcar buena / mala / "mejorable", con una nota. Las malas se descartan; las buenas pasan a la biblioteca de publicación. Las editadas a mano quedan con `origen: manual`, protegidas de que el minero las pise.
- **Guardar:** cada cambio se guarda en la biblioteca con la versión de reglas.

**Cómo se hace**
- Reutiliza el motor del juego: las reglas (`TowerLogic`), el solucionador y los modelos de bloque (`block_models.gd`, `voxel_mesh.gd`). El dibujo de la torre hoy vive dentro de `main.gd` (2 800 líneas); hay dos caminos: (a) **v0 rápido:** instanciar la escena del juego y cargarle la sala, como hacen mis scripts de captura, y reutilizar la selección de bloque con el mouse que ya existe para los consumibles; (b) **v1 limpio:** extraer un nodo `TowerView` reutilizable por el juego, el Estudio y el minero. Recomiendo empezar con (a) para ver salas en días y pasar a (b) si el Estudio crece.
- Miniaturas: se dibujan fuera de pantalla (SubViewport) una sola vez y se guardan como PNG pequeños junto a la sala.
- "Sala más parecida": distancia entre descriptores (tamaño, forma, histograma de alturas, tipos de bloque, agarres, bloques movidos, técnicas) más una distancia estructural sobre la sala normalizada (invariante a giros y espejos). Se indexa en el empaquetado; para la búsqueda alcanza una comparación directa con unos miles de salas.

**Qué mide el éxito:** el tiempo por sala que lleva revisarla y corregirla (objetivo: menos de 1 minuto), y cuántas salas del minero pasan a "buena" sin edición.

### 12.2 Hash de sala para no repetir
Sí se puede, y conviene tener **tres niveles**, porque un solo hash es insuficiente:

| Nivel | Qué mira | Para qué |
|---|---|---|
| **Exacto** | huella, bloques y tipos, normalizado | no guardar dos veces la misma sala |
| **Familia** | igual pero sin tipos de bloque (solo "hay bloque / no hay bloque" y fijo / pesado) | no mostrar la base y su variante seguidas; agrupar variantes |
| **Patrón de solución** | secuencia normalizada de los movimientos del camino más corto y de qué bloque se mueve adónde | detectar salas que **se juegan igual** aunque tengan relleno distinto |

- **Normalización:** se traslada la sala para que su esquina mínima sea (0,0,0), se generan las 8 simetrías (4 giros × espejo) y se elige la de serialización menor: así una sala, su giro y su espejo dan el mismo hash. Hash de 128 bits (SHA-256 recortado): colisiones prácticamente imposibles.
- **Casi duplicados:** si se cambia un solo bloque de relleno, el hash exacto cambia aunque la sala se sienta igual. Para eso, además del hash: huella de tipo "MinHash / SimHash" sobre el conjunto de celdas relativas (comparación rápida) y la distancia de descriptores. El Estudio muestra las más cercanas y el minero rechaza las que estén bajo un umbral.
- **Lo que reconoce el jugador es el patrón de solución, no el relleno:** por eso el tercer nivel es el más útil para "no repetir". Se validará con la prueba humana "¿ya viste esta?".
- **En el juego:** el ensamblador lleva un conjunto de hashes vistos en la partida (y opcionalmente en las últimas partidas, guardado local).

### 12.3 Alturas de 10 a 20: solo salas nativas (reemplaza lo de salas compuestas)
Una sala alta tiene que ser **un solo acertijo conectado**, no pilas de salas. Lo que hay que averiguar con datos es **hasta qué altura se puede producir y verificar una sala nativa**:

1. **Curva costo vs. altura:** con el solucionador actual y el rápido (cuando exista), medir tiempo y estados para salas de 4, 6, 8, 10, 12, 14, 16, 20 pisos, con la misma densidad. Define el **tope nativo**. Si no se llega a 20 con el solucionador actual, el tope hoy es el que da la curva; el solucionador rápido (fase 3) puede subirlo.
2. **Ventaja de la biblioteca precalculada:** el minero puede gastar **10 o 30 minutos por sala alta** (en la PC sobrante, de noche) en lugar de segundos. Con la PC 24/7 es viable producir unas pocas decenas de salas altas buenas por día.
3. **Cómo se construyen (proveedor "alta entrelazada"):** una cadena donde cada tramo **depende del material y las posiciones del anterior** (los bloques movidos abajo son los que hacen falta arriba), de modo que sea un solo acertijo y no dos. Se verifica **entera** con el solucionador con un tope grande (offline) y se guarda el camino más corto. La cadena sola tiene muchos atajos (ver `experimento_cadenas.md`), así que cada candidato se filtra con el solucionador.
4. **Verificación débil como último recurso:** si una sala muy alta no se puede resolver óptimamente en un tiempo razonable, se podría aceptar con el camino plantado y un tope de búsqueda de atajos (garantía más débil: puede haber atajo no encontrado). Se marca con una etiqueta `garantia: debil` y se usa con peso bajo. Decisión pendiente tras ver la curva.
5. **Criterio:** si la curva dice que a 14 pisos el costo ya es inviable aun fuera de línea, el tope de altura del juego es 14 hasta tener solucionador rápido. Mejor un tope honesto que salas altas que en realidad son dos.

### 12.4 Cambios a las fases
- **Nueva fase "Estudio de salas v0"** después del minero v0 (necesita salas guardadas para verlas): visor con reproducción del camino, selección y edición de bloques, verificación continua, miniaturas y "sala más parecida". Esfuerzo M–L.
- **Fase 3 (solucionador rápido)** sube de prioridad: determina el tope de altura nativa y la cantidad de salas por hora.
- **Fase de formas y alturas:** incluye la curva costo vs. altura (12.3.1) y el proveedor "alta entrelazada".
- **Fase 2 (sala estándar):** agrega los tres hashes (exacto, familia y patrón de solución) y el campo `origen` (minero / manual).
