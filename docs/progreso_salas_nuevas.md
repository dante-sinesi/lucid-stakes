# Salas nuevas (torre sin núcleo sólido): bitácora

Reglas en `docs/torre_salas_reglas.md`. Código aislado del juego en `torre/` (motor, reglas, solucionador de referencia en GDScript, puente al nativo, vista, estudio) y `native/salas.cpp` (`tools/salas.exe`: solucionador exacto A* y generador). Capturas del Estudio en `capturas/sn/` (no se versiona).

## Cómo se genera una sala (`salas.exe --gen`)
1. **Sala resuelta**: una escalera de un bloque por piso dentro de la huella (3x3, 5x3 u 8x3 del anillo de 11x11), con el bloque de entrada (nivel 1) y el de salida (nivel h) como checkpoint "p", un bloque fijo pegado a la salida (lo que la toca en la sala de arriba) y `extras` bloques más. El jugador parado sobre la salida.
2. **Contra-movimientos con haz**: cada paso hacia atrás es un estado desde el cual UNA acción del motor lleva al actual (se comprueba simulando), así que se puede resolver por construcción. El haz se guía con la distancia exacta del solucionador.
3. **Variante con el jugador puesto sobre el bloque de entrada** (el estado con el que se arrancaría), resuelta con el solucionador exacto.
4. **Escalada local** sobre la mejor: mover/agregar/sacar un bloque, se acepta si la sala sigue resolviéndose y el valor (pasos + 3 agarres + `wd` bloques distintos movidos) no baja (recocido opcional).

## Hallazgos
- Sin escalada, la construcción hacia atrás da salas fáciles (el solucionador exacto encuentra caminos mucho más cortos que el armado: demasiado material = atajos).
- Con la escalada local sobre el valor exacto, el 3x3 de 6 pisos sube a 39-62 pasos, 16-19 agarres y 4-10 bloques distintos (Catherine pide 3-4 bloques distintos por 3 pisos).

## Resultados de la primera producción (3x3, solucionador exacto hasta 9 pisos)
- 3x3 de 5 a 8 pisos con la escalada local: **1,2 a 2,4 bloques distintos movidos por piso** (Catherine pide ~1), 22 a 89 pasos y 10 a 26 agarres, con los caminos más cortos EXACTOS (A*, heurística: pisos que faltan).
- **Riesgo medido** (movimientos legales que, a lo largo del camino más corto, matan en el acto o dejan la sala sin solución): del 10% al 25%, es decir, un movimiento en falso es una caída bastante seguido.
- 5x3 de 9 y 12 pisos y 8x3 de 12 pisos salen por lonjas (de a 3 pisos): 41-81 pasos, 10-15 bloques distintos; sin garantía de que el camino sea el más corto.
- Solucionador nativo: lista de celdas ocupadas en vez de recorrer toda la grilla (2,3 veces más rápido), `copiar_de` parcial, hash antes de armar el estado.

## Pendiente
- Fase 2 (más adelante, lo pidió el usuario): un ejecutable con un árbol de búsqueda optimizado que calcule el mínimo real de las salas altas ya guardadas.
- Heurística admisible más fuerte (el techo del A* son unos 25-30 pasos con muchos bloques).
- Tabla de margen del temporizador por etapa (hoy provisoria: mínimo x 2,0 en la etapa 1 hasta x 1,15 en la 15).
- Integración al juego (motor de la torre, bloque checkpoint, caída y checkpoint): sólo cuando el usuario lo pida.

## Biblioteca v3 (176 salas: 82 de 3x3, 50 de 5x3, 44 de 8x3 de 5 a 23 pisos)
- Forma comprobada (`herramientas/revisar_forma_salas.py`: 0 problemas), caminos jugados en el motor de GDScript (`tests/unitarios/test_paquete_salas.gd`: 0 fallos).
- Se arreglaron las 8x3: la exigencia de bloques distintos ahora se aplica después de mejorar la sala; las grandes llevan ~2,3 bloques extra por piso; el armado de las altas usa un puntaje barato y la evaluación por lonjas va al final con un tope de nodos por lonja de 60 mil (una 8x3 de 24 pisos tarda ~2 minutos).
- Mínimo exacto demostrado: todas las 3x3, 5x3 hasta 8 pisos y 8x3 hasta 9; las más altas quedan con cota inferior (A* con presupuesto) y camino de lonjas (cota superior): 39 salas.
- Pendiente: certificar las altas (A* con memoria compacta o heurística más fuerte) y calibrar la métrica con salas jugadas.

## Salas con especiales por propósito (segundo paso `--especializar`, ver docs/plan_generador_especiales.md)
- Cinco roles: pesado (limita: no se puede mover), pinchos (celdas prohibidas), agrietado (cada decisión pesa: se pisa una vez), hielo (resbalar, pero también transporte) y trampolín (salto en vez de escalera). Cada uno se pone donde le rompe el paso más barato a la solución, se vuelve a resolver con el solucionador exacto y se acepta sólo si cumple su papel; al final cada especial pasa la prueba de necesidad (volverlo común cambia el resultado: el largo, el valor, o cuánto pesa cada decisión).
- Primera tanda (sobre salas base exactas de hasta 10 pisos): pinchos 36 salas, pesado 33, hielo 33, trampolín 40, agrietado 40. En `bibliotecas/salas_especiales_<rol>.jsonl` (no se versionan).
- Observaciones: el trampolín acorta mucho la sala (salta tramos): las más difíciles quedan en unos 180 bits; las pesadillas de pesado, hielo y agrietado salen con poca frecuencia (un especial casi siempre deja la sala sin solución o no suma).

## Bombas (rol `bomba` de `--especializar`)
- Reglas: la mecha ("b7" en el jsonl; en la grilla nativa vale 16 + mecha) baja un movimiento por acción mientras el jugador está dentro de su zona (dx²+dy²+dz² <= 5). Pararse encima la desactiva ("d", queda como un común); tirada fuera de la huella cae y se pierde; al llegar a 0 cae la sala entera. Ganar en el mismo movimiento gana a la explosión.
- Generación: para cada bloque que el camino pisa o mueve se busca por bisección la mecha mínima con solución (mínimo 3), se exige que la solución pase al menos 3 movimientos dentro de la zona y se elige la bomba que más sube la fracción de movimientos letales. Necesidad: vuelta común cambia el camino o esa fracción.
- Primera tanda: 40 salas (mechas de 3 a 22), el camino de todas verificado en el motor de GDScript. `bibliotecas/salas_especiales_bomba.jsonl`.

## Salas mixtas y paquete de salas
- Mixtas (`herramientas/mixtas_biblioteca.py`): cadena de especializaciones sobre una sala base, `--revisar` comprueba que cada especial (o línea de hielo) siga siendo necesario. Cantidad por altura: 1 + (pisos - 3) // 9 (8x3 de 21 a 24 pisos: hasta 3). Las salas de más de 10 pisos se resuelven por lonjas (no exacto) y tardan minutos por paso.
- Paquete (`herramientas/armar_paquete.py` -> `bibliotecas/paquete_salas.jsonl`): base + los seis roles + mixtas, sin repetidas, con id, categoría y nivel por complejidad. 878 salas, todas con el camino verificado en el motor de GDScript (`tests/unitarios/test_paquete_salas.gd`, 0 fallos). Se rearma cuando llegan más mixtas altas.

## Torre jugable (prototipo, `herramientas\torre_prototipo.bat`)
- `torre/torre.gd` (lógica: armado y partida) + `torre_juego.gd` / `torre.tscn` (escena) + `tests/unitarios/test_torre.gd`. Aislado del juego: usa el Motor de salas nuevas y el paquete de salas (`bibliotecas/paquete_salas.jsonl`).
- Armado: 6 salas con la curva fácil -> pesadilla (las dos primeras de bloques comunes); cada sala se gira o espeja (8 simetrías del anillo, el motor es simétrico) para que su entrada caiga en la celda de salida de la anterior, y se comprueba su camino en el motor. La salida de cada sala deja siempre una continuación posible.
- Partida: temporizador de movimientos (mínimo conocido × 1,9 / 1,6 / 1,4 / 1,25 + 10 / 8 / 6 / 5 según nivel; provisorio), al agotarse o caer se pierde una vida y la sala vuelve a empezar virgen; 3 vidas; al llegar a la salida la sala anterior cae.
- Prueba: 20 torres de 6 salas se completan solas con los caminos guardados (0 muertes).
- La torre se ve como en el juego: cámara isométrica ortogonal que sigue al personaje (gatito, con su silueta tras los bloques), Q/E giran, +/- zoom, V vista de toda la torre; los bloques empiezan corruptos y se purifican (azul con brillo) al pisarlos o colgarse de ellos (el Motor lleva la identidad de cada bloque, `ids`, y `purificados`). El Estudio mantiene su aspecto de siempre (`aspecto_juego` sólo en la torre).
- Armado en espiral: las salas se deslizan por el anillo hasta que su entrada cae en la salida de la anterior y giran siempre hacia el mismo lado (`Torre.armar`, `vueltas`).
