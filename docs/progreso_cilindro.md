# Progreso del cilindro (rama `experimento/cilindro`)

Bitácora de la noche del 2026-10-21 (desde la 01:50 hasta las 08:00). Las imágenes están en `capturas/progreso/` (no se versiona). Cada entrada: qué se probó, parámetros, resultados y qué se aprendió.

## Punto de partida (00:00)
- Cilindro 6x6 con pozo 2x2 vacío, anillo de piso de 1 bloque (28 celdas), sin nada debajo. La salida es un bloque fijo en el borde de arriba; todo lo demás cuelga de ella (cadena de vecinos).
- Primeros resultados (escalada de 100 s por sala, bloques comunes): pared plana 20-39 pasos y 6-10 empujes (1,2-2,0 por piso); cilindro de 1 salida 23-28 pasos y 7-11 empujes; cilindro de 4 salidas costos de 11 a 31 pasos con algunas caras sin solución. Imágenes: `00_*`, `01a_*`, `01b_*`, `01c_*`.

## 01:50 — Movimiento nuevo de Catherine: colgado, avanzar hacia bloques que tienen otro encima
- `TowerLogic._act_hanging` y su copia en `native/solver_nativo.cpp`: colgado ya se puede avanzar por el borde (tramo recto y esquina hacia adentro) hacia un bloque aunque tenga otro encima, agarrado de su costado; lo que sigue sin poderse es trepar ahí. Solucionador y generador nativos recompilados e instalados.
- Pruebas: `test_logic` (se actualizó la expectativa vieja de la esquina y se agregaron dos chequeos nuevos), `test_colgado`, `test_native`: 0 fallos.

## 02:05 a 02:40 — Paredes colgantes: material, salidas y especiales (imágenes `02_*` a `05_*`)
- **Más material** (pared plana de 6 pisos, 16 vs 24 bloques, 120 s de escalada): 20-26 pasos y 6-10 empujes en los dos casos. Más bloques no suben la dificultad por sí solos (`02_*`).
- **Cantidad de salidas** (cilindro de 6 pisos, pedidas 1 a 4): el puntaje por cara es parecido (alrededor de 100 por cara) con 1, 2 o 3 salidas; con 4 siempre queda una sin alcanzar y se poda. Los costos por cara quedan parecidos (25/27, 32/31/30): más salidas no dan por sí solas rutas de dificultad distinta, hay que pedirlo en el puntaje. Evaluar cada cara multiplica el costo por la cantidad de salidas (350 a 2000 pruebas por sala según cuántas). Conclusión provisoria: dejar la cantidad de salidas variable de 1 a 3, sólo alcanzables (`03_*`).
- **Especiales, primer intento** (meterlos al azar y quedarse con los que cambian el camino sin bajar el puntaje): 0 de ~4.000 intentos se quedaron. Diagnóstico con una sala: de 22 bloques, entre 12 y 18 por tipo no cambian el camino y entre 3 y 17 dejan la sala sin solución; los pocos que lo cambian lo acortan (puntaje menor).
- **Especiales dentro de la escalada** (mover bloques conservando el tipo, cambiar un bloque a especial o a común, y un puntaje que suma 30 por cada especial que hace falta, es decir que al cambiarlo por común cambia el camino, y resta 15 por cada uno que sobra): ahora sí quedan de 1 a 4 especiales por sala y todos hacen falta (`04_*`, `05_*`). Con especiales los empujes bajan (4-7 contra 8-10): el especial sustituye trabajo (la catapulta salta pisos, el hielo desliza).

## 02:40 a 04:00 — Riesgo, entrada cerca, calidad mínima, recocido, excavador y visor
- **Entrada cerca de la salida** (la entrada del cilindro se pone pegada a la cara de la salida): sin esto el jugador daba la vuelta al anillo entero antes del primer empuje. Se resta del puntaje la parte del camino que se camina antes del primer empuje.
- **Calidad mínima por cara**: una cara con menos de 1 empuje por piso o menos de 3 pasos por piso no cuenta como resuelta. Antes la escalada "hacía trampa": con tres especiales bien puestos (una catapulta que salta toda la pared) se resolvía en 7 pasos y 1 empuje y el puntaje subía igual.
- **Riesgo**: se mide cuántos movimientos legales del camino hacen caer partes de la pared (derrumbes: 5 a 40 por sala, casi siempre recuperables) y cuántos dejan la sala sin solución (muertes, con el solucionador). Las muertes son pocas: de 0 a 3 por sala, y 8 a 15 en las mejores. Tener un derrumbe no alcanza para perder la sala: hace falta que el material sea justo.
- **Podar el relleno** (`RoomLib.prune`) deja 10 a 16 bloques por pared y no cambia el camino.
- **Recocido simulado y agregar/sacar bloques durante la escalada**, **cobertura de caras del cilindro** y **excavador nativo** (`scripts/pared_pasos.gd`, `scripts/pared_excavador.gd`: la pared se convierte en un "paso" y se la mejora con el grafo de estados): ninguno movió el techo. Todas las variantes terminan en 20 a 30 pasos y 6 a 10 empujes. El excavador devuelve casi una sola candidata de 800.000 nodos porque casi ninguna disposición alcanzable se sostiene si se la arma de cero.
- **El mejor resultado fue un valor atípico**: una pared plana de 46 pasos y 15 empujes con una agrietada y dos trampas (`08_*`), que apareció una sola vez entre unas 130 salas; el resto, 20 a 32 pasos. Las siguientes corridas parten de las mejores (`bibliotecas/p2_elite.rooms`, `tests/elite_paredes.gd`) sin superarla.
- **Visor interactivo** de las mejores paredes con reproducción paso a paso: artefacto "Visor de paredes" (datos con `tests/volcar_visor.gd`).
- **Comparación del ancho de la pared plana** (6, 9 y 12 celdas): en curso.

### 04:30 - ancho, espesor, termino de estados, dispersion (sin mejora)
- Ancho 6/9/12 de la pared plana: 20-31 pasos / 6-9 empujes. Mas ancho no sube el techo.
- Espesor 1 y 3: 23-25 pasos / 6-7 empujes. Igual.
- Termino `est` (estados que explora el A*, proxy de "engano") 6 y 15: 24-27 pasos / 6-7 empujes. Igual.
- `disp=10` (salidas dispersas): 21-24 pasos / 6 empujes. Igual.
- Conclusion: la busqueda aleatoria + recocido se estanca en ~25 pasos / 6-7 empujes para h=6; lo que cambia son las variantes de forma, no la dificultad. Imagen: capturas/progreso/04h_espesor_est_disp.png

### 04:50 - paredes altas, reparacion, produccion desde la elite
- Paredes altas (h 9-12) no arrancan: el crecimiento al azar no da una sala resoluble de partida (el climb necesita un punto de partida resoluble). Agregue una reparacion (saca los bloques sin apoyo) en `Base.make` -> ahora son siempre estables, pero siguen sin ser resolubles. Pendiente: sembrar con una escalera construida. Opcion `suave=1` (pisos minimos como puntaje) lista.
- Bombas ('b') como especial: el recocido no las elige (no son "necesarias"): hay que disenar un modulo donde la bomba sea la unica salida.
- Produccion desde la elite (5 procesos, 4 salas c/u): sigue 20-28 pasos / 6-8 empujes; los mejores usan 3-4 especiales necesarios (28p/8e con h+t+c+k; 33p/9e con s+t). Imagen: capturas/progreso/05a_produccion_elite.png
- Visor republicado con las 10 mejores (la mejor 47 pasos / 14 empujes).

### 05:05 - paredes altas (h 8-9) por fin
- Muestreo masivo de puntos de partida (`guardia=40000`, `suave=1`) da algunas paredes altas resolubles (1 de cada ~300 a h8; 0 a h8 con 400 muestras). Luego `elite_h=8` refina desde esas.
- Resultado: h9 con 26-28 pasos / 11-12 empujes (1.3 empujes por piso), con el hielo/hierro/agrietado "necesarios". Mas empujes por pared que las de h6 (6-8) con los mismos pasos.
- Imagen: capturas/progreso/06a_paredes_altas.png

### 05:40 - refinamiento de las altas
- Muestreo de partida a h10-12 (60 mil intentos x 5 procesos, 10 min): ninguna resoluble. El techo del muestreo al azar es h9.
- Refinando desde la elite de h9 (3 rondas, 15 procesos): todas convergen a la misma pared, 28 pasos / 12 empujes (1.3 empujes por piso), con hierro + agrietado necesarios. T=6 no encuentra algo mejor.
- Visor republicado: 47p/14e (h6), 28p/12e (h9) x3, 27p/11e...
- Pendiente (necesita idea nueva, no mas tiempo): sembrar paredes altas con una escalera construida; modulo donde la bomba sea necesaria.
