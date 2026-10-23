# Música del juego: Las Cuatro Estaciones de Vivaldi

Las cuatro pistas del juego son *Las Cuatro Estaciones* (Antonio Vivaldi, Op. 8; obra en dominio público: Vivaldi murió en 1741) tocadas con el sintetizador chiptune del juego, con los tres movimientos de cada estación seguidos y en bucle:

| Pista (`Music.play`) | Estación | Cuándo suena | Duración |
|---|---|---|---|
| `menu` | Primavera | menús (principal, escenarios, opciones...) | ~9 min |
| `torre` | Verano | torres comunes | ~9 min |
| `casino` | Otoño | casinos | ~9,5 min |
| `pruebas` | Invierno | torres que son una prueba (`Main._tower_music`) | ~6,5 min |

Los archivos están en `audio/music/*.ogg` (unos 34 MB en total). Si falta alguno, `scripts/sonido/music.gd` sintetiza una pista simple por código.

## Cómo se hicieron
- Las notas salen de las partituras en MIDI de **Mutopia Project** (obra y transcripción en dominio público), una por movimiento: `herramientas/musica/fuentes/{spring,summer,autumn,winter}/` (bajadas de `https://www.mutopiaproject.org/ftp/VivaldiA/O8/<estación>/<estación>-mids.zip`). Por cada estación hay tres archivos: `*-score.mid` (movimiento I), `*-score-1.mid` (II) y `*-score-2.mid` (III), identificados por su contenido.
- `herramientas/musica/midi_leer.py` lee el MIDI (con los tempos) y `herramientas/musica/render_estaciones.py` lo toca: el solista es un pulso con vibrato y eco, los violines y la viola pulsos finos y el violonchelo un triángulo. Vuelve a generar todo con `python herramientas/musica/render_estaciones.py audio/music audio_prueba` (hace falta ffmpeg; también deja los `.mp3` en `audio_prueba/`, que no se versiona).
- Los tempos y la dinámica son los del MIDI (planos): no hay percusión ni repeticiones agregadas. Pendiente si se quiere más "chiptune": percusión suave en los movimientos rápidos, o tempos ajustados a mano.
- Vivaldi y las partituras de Mutopia son dominio público: no hace falta nombrarlos en los créditos (Dante decidió no incluirlos).
