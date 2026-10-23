# Plan de la limpieza a fondo

Se hace en una rama nueva (`limpieza/a-fondo`) cortada de `main` después de mergear `feature/recuperar-torre-vieja`, con la etiqueta `antes-de-la-limpieza` en ese punto: todo lo que se borre sigue en la historia de git y se recupera con `git show antes-de-la-limpieza:ruta`.

## Criterio (qué se queda y qué se va)
Un archivo se queda sólo si cumple al menos una de estas:
1. Lo usa el juego o las pruebas **tal como funciona hoy**.
2. Es una herramienta que hace falta para **volver a producir** algo que viaja con el juego (las salas, la música, los modelos, el .exe).
3. Es documentación que describe lo que el juego **hace ahora** (no cómo se llegó hasta acá).

Lo demás se borra. Lo que se aprendió de lo viejo y puede servir (qué funcionó y qué no al generar salas, por qué se descartó el cilindro...) se condensa en **un solo documento** (`docs/aprendizajes.md`) antes de borrar los experimentos que lo originaron.

## Estado de la carpeta (medido)
| Carpeta | Versionado | Peso | Problema |
|---|---|---|---|
| `tools/` | no | 250 MB | 25 .exe: variantes `salas_nuevas_a..g`, `_e2..e6`, `_dbg`, `solver_nativo_new/prev/viejo`, `cilindro.exe`, `generador_dbg.exe` |
| `build/` | no | 864 MB | exportaciones y zips viejos, `herramientas/` de 447 MB |
| `bibliotecas/` | no | 356 MB | 212 entradas: `generacion_48hs/96hs`, `minero_*`, `audit50*`, un .rar de 35 MB, miniaturas... sólo hacen falta 2 o 3 archivos |
| `audio_prueba/` | no | 248 MB | mp3 de prueba de la música, sin uso |
| `capturas/` | no | 70 MB | capturas sueltas de las pruebas |
| `data/` | sí | 40 MB | `data/salas/` (212 archivos de rondas del generador, 30 MB: **los agregué yo por error al commitear**), 3 `.bak`, la biblioteca vieja `salas.rooms`, el banco viejo de la demo |
| `docs/` | sí | 12 MB | 187 archivos: 132 capturas de la torre vieja (con sus `.import`: Godot importa las imágenes de la documentación), 40 documentos de las épocas del generador y del minero |
| `tests/` | sí | 335 archivos | 83 `test_*` y unos 250 que son sondas de una vez (`probe_`, `exp_`, `shot_`, `bench_`, `check_`, `sim_`...); 88 archivos dependen de la torre vieja |
| `herramientas/` | sí | 52 archivos | los `.bat`/`.py`/`.sh` del minero, empaquetador, estudio viejo, `especiales_lote1..5.sh`, `capturas_*.py`... |
| `scripts/` | sí | 263 archivos planos | mezcla de menús, casino, torre vieja, herramientas de desarrollo y el juego nuevo |
| raíz | sí | — | `demo.bat`, `jugar.bat` sueltos |

## Fases (cada una termina con todos los tests y un commit; no se pasa a la siguiente si algo falla)

### Fase 1 — Basura sin riesgo (media hora)
- Sacar `data/salas/` del control de versiones y agregarlo al `.gitignore` (la biblioteca que viaja con el juego es `data/salas_torre.jsonl`).
- Borrar de `tools/` todo salvo `Godot_*`, `salas_nuevas.exe`, `solver_nativo.exe` y `generador.exe` (los tres se rearman con `native/construir.bat`).
- Vaciar `build/`, `capturas/`, `audio_prueba/` y los `.bak` de `data/`.
- `bibliotecas/`: dejar `paquete_salas.jsonl`, `todas_las_salas.jsonl` y `salas_nuevas.jsonl` (las fuentes del paquete); el resto se borra.
- `docs/capturas`, `docs/maquetas`, `docs/img`: borrar lo de la torre vieja; poner un `.gdignore` en `docs/` para que Godot no genere `.import` ahí; dejar sólo capturas vigentes.
- Mover `demo.bat` y `jugar.bat` a `herramientas/` (o dejar sólo `jugar.bat` en la raíz).
- Efecto: se liberan unos 1,7 GB y la carpeta queda legible.

### Fase 2 — Pruebas y herramientas (una tarde)
- `tests/`: dejar los `test_*` que siguen valiendo, un puñado de capturas reutilizables (`shot_verificar_torre`, `shot_checkpoint_torre`, `shot_caida_torre`, `shot_primera_sala`, `shot_dificultad`) y las sondas vigentes (`probe_dificultad`, `probe_teclas_derrota`, `probe_wasd_menu`, `probe_etapa1`). Se borran los 12 `exp_*`, los `bench_*`, `sim_*`, `check_*`, `audit_*`, `retune_*`, `depurar_*`, `mock_*` y las capturas de pantallas que ya no existen.
- Convertir `todos.sh` en el corredor oficial de pruebas (`tests/correr_todos.sh`: corre todo, resume, devuelve error si algo falla).
- `herramientas/`: borrar todo lo del minero y del empaquetador de la torre vieja y los scripts `especiales_lote*`, `capturas_*`, `mixtas_*`, `especializar_*`, `resumen_biblioteca`, `controlar_biblioteca`. Quedan: `construir.ps1` (actualizado), los `.bat`/`.ps1` del generador y del estudio de la torre nueva, `armar_paquete.py`, `resumen_telemetria.py`, `editor_modelos.bat`, `musica/`.

### Fase 3 — Retirar la torre vieja (la grande; rama propia, varios commits)
La torre vieja (`tower_logic`, `solver`, `rooms`, `tower_gen`, `tower_metrics`, `room_*`, `step_*`, `studio*`, `native_solver`, `tower_bank`, `meteors`, el bot viejo, `native/generador.cpp` y `native/solver_nativo.cpp`, la biblioteca `data/salas.rooms`) sólo sigue viva por cuatro cosas. Hay que resolver cada una:
1. **Lecciones de movimiento del tutorial** → rehacerlas con el motor nuevo (salas armadas a mano de 1 o 2 pisos, sin temporizador).
2. **Laboratorio** → es una herramienta de desarrollo: borrarlo (o portarlo si todavía lo quieres).
3. **Demo** → su banco de torres (`data/torres_demo.torres`) es de la torre vieja: se arma uno nuevo con la torre nueva (salas curadas de las etapas 1 a 6) o se genera en vivo.
4. **Pruebas con reglas propias** (Niebla, Oscuridad, Lluvia de meteoritos) y los premios que quedaron sin efecto (Ojo de hielo, Escudo, Doble salto, conversores...): **decidir si se portan o se eliminan** (ver `docs/replanteo_boosts_consumibles.md`). Lo que no se porte se borra del código, del catálogo y de las traducciones.

Después se borran los módulos viejos, las ramas de `main.gd` que usan `logic.` (unas 176 referencias y 34 de `lab_active`: `main.gd` baja de 3.700 líneas a poco más de la mitad), `GAME_TORRE_VIEJA`/`GAME_TORRE_NUEVA`, los 88 tests de la torre vieja (o se reescriben los que valga la pena) y las dos herramientas nativas viejas.

### Fase 4 — Nombres y estructura
- `salas_nuevas/` deja de ser "nuevo": pasa a `torre/` (clase `Torre`, `Motor`, `Reglas`...), con sus pruebas dentro.
- `scripts/` (263 archivos planos) se ordena en carpetas por tema: `ui/` (menús, pausa, derrota, confirmaciones), `casino/` (ruleta, tragamonedas, blackjack, dados, servicios), `personajes/`, `datos/` (perfil, ajustes, guardado, telemetría), `herramientas/` (editor de modelos, generador, bot). Un script reescribe todas las rutas `res://` y los `.uid`, y se corren los tests después.
- `tests/` en subcarpetas (`unitarios/`, `sondas/`, `capturas/`).
- Normalizar finales de línea (hoy hay archivos CRLF y LF mezclados) con `.gitattributes`.

### Fase 5 — Documentación
- Unificar en `docs/` sólo lo vigente: reglas de la torre, interfaz y teclas, dificultad, economía y bot, catálogo (regenerar `catalogo.xlsx` y los `.md` con lo que existe de verdad), demo, diálogos, música, editor de modelos, telemetría.
- Escribir `docs/aprendizajes.md` con lo que sirve de las épocas viejas (generación de salas, métricas de dificultad, solucionador nativo, el cilindro) y borrar los 25 documentos de proceso (`brainstorming_generador`, `estado_rama_brainstorming`, `experimento_*`, `plan_generador*`, `evaluacion_generador`, `metrica_dificultad`, `minero_y_estudio`, `modulos`, `pasos`, `torres_con_biblioteca`, `torres_ideas`, `solucionador_nativo_y_excavacion`, `resumen_biblioteca_actual.txt`...).
- Reescribir `CLAUDE.md` (19 KB, la mitad habla de la torre vieja) con sólo lo que hoy es cierto.

### Fase 6 — Código muerto
- Con la torre vieja afuera: buscar funciones, constantes, señales, textos de `Loc` (español e inglés), assets (audio, shaders, escenas, modelos) y variables de ajustes que ya nadie usa; borrar los comentarios que cuentan historia ("antes la torre...", "la torre vieja...") y los `.uid` huérfanos.
- Revisar que el juego exportado (`export_presets.cfg`, preset normal y "Windows Demo") sigue armando y arrancando.

### Cierre
Tests completos, partida de principio a fin (con la captura de cada pantalla), `docs/` y `CLAUDE.md` al día, merge a `main`.

## Decisiones tuyas antes de empezar
1. **Pruebas con reglas propias y premios sin efecto:** ¿se portan a la torre nueva o se eliminan? (Define cuánto trabajo es la Fase 3 y qué hay que sacar del catálogo.)
2. **Laboratorio:** ¿se borra?
3. **Demo:** ¿banco de torres nuevas curadas o generación en vivo?
4. **Estructura de carpetas:** ¿te gusta la propuesta de `scripts/` y `tests/` o prefieres otra?
5. **Fase 3 y 4:** ¿en una sola rama (más simple) o una rama por fase (más fácil de revisar)?
