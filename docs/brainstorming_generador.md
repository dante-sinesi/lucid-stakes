# Brainstorming del generador de salas

Notas de una conversación de ideas (no se programó nada). Tema: cómo lograr salas con la complejidad de Catherine sin que el juego se vuelva repetitivo, y cómo generarlas.

## 1. Cómo lo logra Catherine

- Los tramos son **diseño humano**: cada sección de unas 3 filas tiene una trampa pensada (una solución obvia que falla, una que parece imposible y una que sirve).
- **Babel** no genera nada desde cero: cada nivel tiene un conjunto de paredes diseñadas a mano y el juego sortea cuál toca, sin repetir la misma dos veces seguidas ([wiki: Obelisk](https://catherine.fandom.com/wiki/Obelisk)). Las cuatro torres tienen tema y pasos fijos: Altar (10), Menhir (15), Obelisk (20), Axis Mundi (100) ([wiki: Babel](https://catherine.fandom.com/wiki/Babel?oldid=5250)). No se pudo confirmar si las paredes se giran o varían.
- Lo que da la dificultad:
  1. **Transportar material.** Los bloques solo se mueven horizontalmente y la altura total se conserva: para subir hay que traer bloques hasta la escalera, con pasillo libre y algo desde donde empujar o tirar.
  2. **Pared densa con profundidad.** Casi no hay celdas libres: para mover un bloque hay que mover otro. Se rodea con la cámara y se cuelga de bordes.
  3. **Vocabulario de técnicas que se combinan** (escalera de 3, colgarse y rodear, hielo, bomba…). Cada sección mezcla dos o tres.
- En un modo con ranking, la gente memoriza las paredes y las ejecuta de memoria. A Catherine le alcanza porque valora velocidad. A nosotros no: el casino y los boosts dependen de que no se pueda "saber" la solución.

## 2. El espíritu del Balatro

Lo que hace al Balatro no es la aleatoriedad en sí: las reglas son fijas, las **piezas** están diseñadas (cartas, jokers) y lo aleatorio es **qué te toca y cómo se combina**. Nadie siente "ya vi este joker". Para nosotros: la unidad que se repite tiene que ser chica y la sala tiene que ser la **combinación**.

## 3. Salas diseñadas a mano: la cuenta

Suponiendo ~100 apariciones de sala por partida (15 etapas × 6–10 salas) y sorteo sin repetir dentro de la partida, porcentaje de salas ya vistas en partidas anteriores:

| Salas | Partida 2 | 4 | 6 | 10 |
|---|---|---|---|---|
| 100 | 100 % | 100 % | 100 % | 100 % |
| 200 | 50 % | 88 % | 97 % | 100 % |
| 400 | 25 % | 58 % | 76 % | 92 % |
| 1000 | 10 % | 27 % | 41 % | 61 % |
| 3000 | 3 % | 10 % | 16 % | 26 % |
| 10000 | 1 % | 3 % | 5 % | 9 % |

- Para menos de 10 % de repetidas en la partida 4 hacen falta ~2900 salas; en la 10, ~8600; para menos de 25 % en la 4, ~1100.
- **Conclusión: un pool de salas completas, aunque sean cientos, no alcanza.** Con 150–250 se evita repetir dentro de una partida, no se mantiene el interés.
- Combinando 3 motivos de 40: C(40,3) = 9880 salas; de 60 con 8 giros: ~273 mil.
- Límites del modelo: mide repetición **exacta**; el jugador además reconoce técnicas; contar soluciones distintas no basta (con azar casi siempre salen distintas). Lo confiable es que alguien juegue varias partidas.

### Muestra del generador actual
8 salas `chica` (D=0.6, 5 filas, semillas 1000–1007): las 8 distintas, 17–29 movimientos, pero solo 4 pidieron 5 o más agarres; las otras 4 se resolvieron con 0–2 (una con 0). **El problema es la exigencia desigual, no la variedad.**

## 4. Alternativas evaluadas

| Alternativa | Veredicto |
|---|---|
| Salas hechas a mano en volumen | Descartada: la tabla muestra que se agota; mucho trabajo manual (20–40 min por sala). |
| Piezas chicas en fila | No crean el efecto "muro": cada tramo se resuelve aislado. Las piezas tienen que **entrelazarse** (compartir espacio y material). |
| Red neuronal que genera (PCGRL o aprendida de ejemplos) | Por ahora no: ambiciosa, opaca, riesgo de colapsar en pocos patrones, proyecto aparte. |
| Red neuronal que **juzga** (predice si una sala sirve y cuántos bloques pide mover) | Opción barata, anotada: sirve si el costo del solucionador pasa a ser el cuello de botella. Se entrena afuera (Python) y se corre en GDScript con una multiplicación de matrices; datos generados por el propio solucionador. |
| Plantillas semi-prediseñadas (esqueleto + ranuras opcionales / alternativas / relleno / giro) | Viable, pero el número de variantes **que se sienten distintas** por plantilla decide todo; ver la tabla. |
| Generar desde la solución con movimientos encadenados | **Candidata principal** (ver sección 5). |
| Híbrido (ideas actuales + cadenas + salas de autor) | **Estructura recomendada** (ver sección 6). |

### Ideas para fabricar muros densos y difíciles (la "reja")
La reja por desorden al azar fracasó (el solucionador la resolvía en 6–11 movimientos: un paseo al azar desde la solución no se aleja). Alternativas:
1. **Reja con ancla:** parte de los bloques inamovibles o pesados forma una retícula; el resto se desliza entre ellos (tipo puzzle de piezas corredizas, como Rush Hour). Menos grados de libertad, más dependencias, estado chico para el solucionador.
2. **Sustituto barato de la dificultad:** contar cuántos bloques distintos hay que mover para liberar un paso, para guiar la búsqueda; el solucionador confirma al final.
3. **Construcción con candados:** deshacer desde la sala resuelta eligiendo siempre los movimientos que **traban** a otro bloque.

En Rush Hour los tableros difíciles salen de buscarlos (cambiar una pieza y conservar el cambio si el solucionador dice que cuesta más), igual que los *climb* de `taller` y `chica`.

## 5. Generar desde la solución con movimientos encadenados

### Idea
Un catálogo de **movimientos**; el generador arma una cadena de movimientos que lleva a la meta, coloca los bloques que cada uno necesita, rellena el resto al azar y comprueba que la solución sigue funcionando.

### Ficha de un movimiento
- Nombre y qué hace.
- **Parámetros** (distancia, dirección, altura).
- **Huella:** qué celdas tienen que tener bloque, cuáles tienen que estar vacías, **qué tipo de bloque**, dónde se para el jugador.
- **Efecto:** cómo queda el terreno y dónde queda el jugador.
- Tamaño en celdas.

### Cómo el sistema sabe dónde poner bloques y dónde no
- Terreno inicial **sin decidir**. La cadena se ejecuta paso a paso en el simulador real (`TowerLogic`).
- Si un movimiento necesita una celda que **nunca fue tocada**, se decide su contenido en ese momento (queda como estado inicial). Si ya fue modificada por un paso anterior, se mira lo que hay: si no sirve, se descarta ese movimiento y se elige otro.
- Entre dos movimientos el jugador tiene que poder caminar: se busca un camino y se **reserva** (queda vacío).
- Lo decidido es el **esqueleto mínimo**; lo demás se rellena al azar (columnas desde el piso). Como todo lo que usa la cadena ya está decidido, el relleno no puede romper la solución; igual se la repite paso a paso como seguro (milisegundos, sin búsqueda).
- Alternativa equivalente: regresión desde la meta hacia atrás sobre un estado parcial (bloque / vacío / libre).

### Resuelve
- Resoluble por construcción (hoy se gasta mucho en candidatos irresolubles).
- Entrelazado: el efecto de un paso es la precondición del siguiente, y se reutilizan celdas y bloques.
- Dificultad elegida de antemano (largo de la cadena y bloques distintos).
- Variedad combinatoria: 20 movimientos en cadenas de 8 ≈ 2,5·10¹⁰ cadenas, más posición, giro y relleno.

### Riesgos
1. **Atajos:** la solución plantada es un límite superior; el relleno o el esqueleto pueden abrir un camino más corto. Hay que pasar el solucionador una vez por sala, con tope.
2. **Linealidad:** si cada paso está forzado, parece un tutorial. Hacen falta **distractores tentadores** (parecen útiles y no lo son).
3. **Geometría 3D** con marcha atrás para que los movimientos no choquen entre sí.
4. **Bloques distintos:** preferir movimientos que usen un bloque que todavía no se movió.

### Bloques especiales
- El **tipo** de bloque es parte de la huella; dos movimientos que piden tipos distintos en una celda chocan igual que cualquier otro conflicto.
- **Hielo:** huella con un tramo de hielo y un **tope** donde frenar; el sistema elige el largo y coloca el tope. El peligro (pasarse del borde) son trampas del relleno.
- **Trampolín:** celda del trampolín, tramo de aire libre y celda de aterrizaje libre con apoyo.
- **Bloques que se transforman** (bomba, agrietado, trampa): funcionan sin trabajo extra porque se ejecutan en el simulador real; cuidar que un agrietado no se use dos veces.
- **Medir la huella con el simulador** (instrumentarlo para anotar qué celdas lee o cambia) en vez de escribirla a mano: los tipos nuevos entran solos y el catálogo no se desfasa si cambian las reglas.
- **Casillero de tipo** en las plantillas (por ejemplo "empujar a un hueco" con bloque común o de hielo): multiplica el catálogo; el simulador calcula el efecto.
- El **tema de la sala** (hielo en grandes, bombas en chicas) es un filtro sobre el catálogo.

### Ejemplo: "deslizarse sobre hielo sin caerse"
Receta (se escribe a mano, es chica): tema = suelo de hielo; objetivo = de la entrada a la salida; peligro = caer por el borde; movimientos permitidos = deslizar y poner/mover un tope. La cadena: deslizar al este con un tope decidido en la celda siguiente, luego al sur con otro tope, etc. Los topes quedan como esqueleto; el relleno agrega topes extra (recorridos alternativos) y trampas (celdas por las que te pasás del borde). **No es una sala prehecha:** la disposición emerge; solo el vocabulario y la receta están escritos de antemano. Pierde los trucos elegantes pensados a propósito (para eso están las salas de autor).

### Cómo armar el catálogo
1. **A mano (12–15):** empujar a un hueco, traer con tirón, escalón doble, colgarse y soltar, puente, deslizar sobre hielo, rodear, apoyo pesado, desbloquear, más los de trampas, bomba y trampolín. Cada uno se prueba solo en un simulador vacío (funciona con la huella; deja de funcionar con un bloque de más o de menos).
2. **Minado:** cortar las soluciones del solucionador en tramos de agarres, calcular la huella de cada tramo, normalizarla (sin posición ni rotación), contar los patrones frecuentes y curarlos a mano. Encuentra movimientos que no se piensan a mano.
3. **Validación del catálogo:** cobertura (¿se rearman `taller` y `chica`?), variedad de cadenas, peso por movimiento (que ninguno aparezca en el 40 % de las salas) y jugarlo.
4. Tamaños: con 8–10 movimientos ya se prueba la idea completa; 25–40 dan buena variedad.

## 6. Híbrido recomendado

Tres fuentes en el mismo sorteo de `plan()` (cada idea ya es un proveedor que devuelve un candidato que pasa por el mismo solucionador y verificación):
1. **Ideas actuales** (hielo, pared pesada, `taller`, `chica`…).
2. **Cadenas de movimientos** (idea nueva).
3. **Salas de autor** (pocas, 30–40, como momentos especiales; funcionan como jokers legendarios: que reaparezcan se siente como un viejo conocido).

Pesos por etapa/dificultad y por cuánto hace que salió una de autor. Si la cadena no produce una sala válida dentro del presupuesto, se cae a una idea actual (red de seguridad, hoy no hay).

A cuidar: dificultad pareja entre fuentes (medir todo con **bloques distintos movidos**), mismos enchufes de entrada/salida/altura, ritmo (sin tres salas de la misma fuente seguidas; reutilizar topes de repetición y "respiros"), y más tests porque cada fuente falla distinto.

## 7. Orden propuesto

1. Subir el piso de exigencia de las salas actuales (ninguna con 0–2 agarres).
2. Experimento acotado de cadenas con 5–8 movimientos; medir qué proporción tiene atajos (si pasa en menos de la mitad, es viable; si pasa casi siempre, endurecer los requisitos de cada movimiento).
3. Si funciona: ampliar el vocabulario y hacer con esto las salas medianas y grandes. Las salas de autor, solo si todavía se quieren.
4. La red que juzga, solo si el costo del solucionador se vuelve el cuello de botella.

## 8. Preguntas abiertas

- ¿Qué formato tendrían las recetas de sala (texto, datos en un archivo, editor en el juego)?
- ¿Cómo se definen los enchufes estándar para salas en L o U, y las salas que bajan (objetivo = caer)?
- ¿Cuánto se tolera la sensación lineal de una cadena frente a una sala pensada?
