# Estado del código y pendientes (a retomar en el chat principal)

Este archivo recoge lo que **no** es brainstorming del generador: el estado del código al empezar la conversación de ideas y lo que queda por hacer. Las ideas del generador están en `docs/brainstorming_generador.md`.

Rama: `feature/salas-medianas-encadenadas`. En la conversación de ideas no se modificó ningún archivo del proyecto; los cambios sin commitear que se listan abajo son anteriores.

## Cambios hechos justo antes del brainstorming (sin commitear)

### Pisos configurables por etapa
- `RunState.rows_for(etapa)` en `scripts/datos/run_state.gd`: 25 filas hasta la etapa 5 y 2 más por etapa desde ahí, con tope en 41 (se alcanza en la etapa 13).
- `scripts/main.gd` (`_start_job`) la usa al generar cada torre. Si `tower_rows` fue cambiado a mano (tutorial, tests con torres chicas), se respeta ese valor.
- Chequeo nuevo en `tests/unitarios/test_run.gd` (25 en etapa 1 y 5, 31 en la 8, 41 en la 15).
- **Pendiente: `test_run.gd` no está verificado.** La última corrida terminó con código de salida 4 y no se revisó el motivo (la salida mostraba mucha generación de torres, puede ser un tope de tiempo del lanzamiento).
- Una torre de 41 filas tardará bastante más en generarse (estimado 4–5 minutos); hay que revisar caída del suelo, tiempo y prefetch con esa altura.

### Exploración inversa para la sala `chica` (experimental)
En `scripts/rooms.gd`: `_far_states`, `_vert_s0`, `_is_heavy_col`, `_chica_result`, constantes `TALLER_S0` y `TALLER_STATES`, y el primer paso de `_c_chica` (parte de la sala resuelta, explora hasta 9000 estados reversibles y verifica los 30 más lejanos con el solucionador completo).
- Funciona, pero rinde igual que el azar (18 movimientos y 5 agarres, contra 17 y 6) y tarda lo mismo (~45–75 s por sala).
- Motivo: la distancia reversible (~25) sobreestima el costo real (~10) por los atajos irreversibles.
- Tiene **trazas de depuración** (`explora: …`, `cand dist=…`) bajo `IDEA_LOG`; hay que quitarlas.
- Decidir: dejarlo como camino principal, dejarlo como respaldo o descartarlo.
- `test_rooms` pasó con 0 fallos con estos cambios.

## Qué NO está hecho
- Salas medianas (3x6 a 3x8, L de 5x5) y grandes.
- Alturas variables por sala (hasta ~15), temas por tamaño (bombas en chicas, hielo en grandes).
- Salas que bajan (objetivo = caer).
- Exigencia mínima garantizada en las salas actuales: en una muestra de 8 `chica`, 4 se resolvieron con 0–2 agarres.

## Próximos pasos propuestos
1. Verificar `test_run.gd` y limpiar las trazas de `rooms.gd`.
2. Subir el piso de exigencia de las salas actuales (bloques distintos movidos, no movimientos).
3. Experimento acotado de cadenas de movimientos (ver `brainstorming_generador.md`, secciones 5–7).
4. Revisar tiempos y caída con torres de hasta 41 filas.
5. Actualizar `docs/diseno.md`, `docs/plan_generador.md` y la memoria cuando se decida.
