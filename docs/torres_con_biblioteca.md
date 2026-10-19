# Torres con la biblioteca de salas

El juego arma sus torres con las salas de la biblioteca (las que salen del minero, ver `docs/minero_y_estudio.md`), elegidas por dificultad: más fáciles en la torre 1, más difíciles hacia la 15.

## Piezas

- `data/salas.rooms`: la biblioteca que viaja con el juego (zstd, ~1 MB, 4025 salas con prueba exacta). Se arma con el empaquetador a partir de `bibliotecas/*.jsonl`:
  `tools\Godot... res://scenes/pack.tscn -- --in=CARPETA --out=data/salas.rooms` (la carpeta tiene los `.jsonl` a juntar). `export_presets.cfg` incluye `data/*.rooms`.
- `scripts/room_pool.gd`: lee la biblioteca una vez (con un candado, los hilos de generación la comparten), califica cada sala (`rating`: 0..1, mezcla de agarres, dificultad = agarres/pasos y largo del camino),
  y `pick` devuelve las salas más cercanas a la calificación buscada para la torre y el lugar (`target`: sube con la dificultad de la etapa y un poco dentro de la torre), sin repetir y que entren en los pisos que quedan.
  Una sala sólo sale si todos sus tipos de bloque están desbloqueados en esa etapa (la escalera de `tower_gen.gd`: hielo 2, pesado 3, agrietado 4, trampa 5, pinchos 6, bomba 7, trampolín 8).
- `scripts/rooms.gd`, `place_library_room`: para cada sala del plan que no es un respiro prueba hasta 6 salas de la biblioteca × 8 simetrías (giros y espejos). La apoya con la llegada en el bloque donde está parado el jugador,
  arma el piso, el pilar de salida y las columnas (bloque por bloque, con huecos y bombas con su cuenta) y la pasa por el mismo `_commit` que cualquier sala: el camino que ya trae la sala tiene que llegar,
  nada se puede caer, y el recorrido de toda la torre hasta ahí tiene que seguir andando (el core y lo ya armado pueden hacer fallar una simetría: se prueba otra o otra sala).
  Si ninguna entra, se usa una idea de las de siempre (muro, hielo, taller…), y los respiros siguen siendo los de siempre.
- Los escenarios con ideas propias (Glaciar) no usan la biblioteca. `SIN_BIBLIOTECA=1` la apaga (para comparar); `opts.library=false` también.

## Probar

`GAME_SANDBOX=1 STAGES=1,8,15 SEEDS=2 tools/Godot...console.exe --headless --path . -s tests/probe_biblioteca.gd` muestra las salas que entraron en cada torre y cuánto tardó.
