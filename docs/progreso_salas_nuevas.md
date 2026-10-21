# Salas nuevas (torre sin núcleo sólido): bitácora

Reglas en `docs/torre_salas_reglas.md`. Código aislado del juego en `salas_nuevas/` (motor, reglas, solucionador de referencia en GDScript, puente al nativo, vista, estudio) y `native/salas_nuevas.cpp` (`tools/salas_nuevas.exe`: solucionador exacto A* y generador). Capturas del Estudio en `capturas/sn/` (no se versiona).

## Cómo se genera una sala (`salas_nuevas.exe --gen`)
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
