# Plan del Glaciar (primer escenario llevado a calidad)

Fecha: 2026-10-19. Es el único escenario, además de La Pesadilla, que se puede elegir en el selector; los demás (Ruinas, Polvorín, Relojería, Compromiso, Gran Casino) quedan como "Próximamente" (`Scenarios.AVAILABLE`, `Scenarios.playable`) hasta que se les arme el contenido. Este documento ordena cómo lograr que el Glaciar no caiga en salas repetitivas y monótonas del generador.

## La idea en una frase

Un escenario donde **el hielo es el protagonista del acertijo**: casi todas las salas se resuelven resbalando, frenando contra topes y empujando bloques que se deslizan hasta chocar, no solo con "un bloque de hielo suelto" como pasa hoy.

## Diagnóstico (con datos)

1. **El Glaciar no usa la biblioteca de salas.** `rooms.gd` (`use_lib`) excluye a los escenarios con ideas propias (`SCENARIO_IDEAS`), así que sus torres salen del generador viejo con solo 3 ideas (`hielo_freno`, `hielo_pista`, `hielo_billar`). Ahí está la monotonía que se ve.
2. **La biblioteca tiene poco hielo "de verdad".** De las 91.911 salas de la generación de 48 horas, 4.298 tienen hielo (4,7 %), pero casi todas con 1 solo bloque (1,1 por sala; solo 18 salas tienen 3 o más). Con dificultad ≥ 35 % y alcance ≥ 0,5 quedan 509. Usar la biblioteca tal cual no da un escenario helado: da la Pesadilla con un cubito de hielo aquí y allá.
3. **El generador nativo no sabe pedir hielo.** Su paso de tipos reparte los seis especiales (`TYPE_POOL`: hielo, agrietado, bomba, catapulta, trampa, pinchos) sin forma de decir "solo hielo" ni "al menos N bloques de hielo en el camino".

## Qué hace el hielo (reglas que ya existen, para diseñar con ellas)

- Un bloque de hielo empujado **se desliza hasta chocar** con algo o salir de la huella. Una fila de bloques no resbala: solo el hielo suelto.
- El jugador que llega a una celda apoyada en hielo **sigue resbalando** en la dirección del movimiento hasta salir del hielo o chocar; fuera de la huella, cae.
- **No se puede colgar del borde de un bloque de hielo** (salvo con la habilidad *Garras de hielo*, que es lo que da escapar de este escenario).

## Familias de salas del Glaciar

Las tres que ya existen se mantienen y se suman cuatro que el nuevo modo del generador tiene que poder producir:

| Familia | El acertijo | Estado |
|---|---|---|
| Freno | colocar un bloque como tope para frenar un resbalón | existe (`hielo_freno`) |
| Pista | resbalar por una franja; el castigo es salirse y caer | existe (`hielo_pista`) |
| Billar | empujar hielo que rebota entre topes hasta quedar en su lugar | existe (`hielo_billar`) |
| Cadena | llegar a un destino encadenando varios resbalones con cambios de dirección | nueva |
| Puente móvil | un bloque de hielo que se desliza hasta cubrir un hueco | nueva |
| Tope móvil | el tope también se mueve (bloque pesado o normal empujado antes) | nueva |
| Mixta ligera | hielo más un solo compañero: pesado o normal como tope, agrietado como puente de un solo uso | nueva |

Regla de variedad: nunca más de 2 salas seguidas de la misma familia, y la mezcla entre familias sube con la etapa.

## Contenido: cómo se consigue sin repetir

### 1. Minería dirigida al hielo (generador nativo)
- Nuevo modo `--types=i` y `--min-ice=N` en `generador.cpp`: el paso de tipos solo inserta hielo y descarta candidatas con menos de N bloques de hielo **que cambian el camino óptimo** (la auditoría ya descarta especiales que no hacen falta).
- Nueva métrica por sala, calculada sobre el camino exacto: `slides` (cuántos resbalones y deslizamientos tiene la solución) y `ice_moved` (cuántos bloques de hielo hay que mover). Se guardan en `opt` y se muestran en el Estudio.
- Objetivo: 3.000 a 5.000 salas con `slides ≥ 3`, repartidas por forma, altura (5 a 11 pisos) y dificultad. Se deja corriendo 24 a 48 horas con `herramientas\generador.bat` (Dante) y se cierra con `generador_todo`/`generador_main` como siempre. Todo con prueba exacta.

### 2. Curaduría en el Estudio
- Filtro nuevo "Glaciar" en el Estudio de salas (hielo en el camino ≥ 3 resbalones), orden por dificultad y por familia.
- Dante marca las buenas con `status = "aprobada"` y la etiqueta `glaciar` en `pattern` o `note` (los campos ya existen en el formato). Meta: **150 a 300 aprobadas**, de 5 a 11 pisos, con todas las familias. Se guardan en `data/glaciar.rooms` (biblioteca aparte que viaja con el juego, igual que `salas.rooms`).
- Las salas rechazadas se anotan (`status = "rechazada"`) para no volver a mirarlas.

### 3. Variedad medible
- **Firma de una sala:** forma, altura, nº de bloques de hielo, familia, y la secuencia de modos del camino (empujar, tirar, colgar, caminar) resumida. Las salas con la misma firma forman un "grupo".
- **Anti-repetición:** dentro de una torre, no se repite sala ni grupo; entre torres seguidas, se baja el peso de las salas vistas hace poco; en el perfil se guarda la memoria de las últimas N salas vistas (por escenario) para que dos runs seguidos no se parezcan.
- **Mezcla entre familias:** el selector elige la familia primero (con el límite de 2 seguidas) y la sala después.

## Integración en el generador de torres

1. `rooms.gd`: el Glaciar usa la biblioteca (`use_lib` ya no lo excluye) pero con `RoomPool.pick(..., scenario)` filtrando por `glaciar.rooms` (etiqueta). Las ideas viejas quedan solo de relleno cuando la biblioteca no alcanza (pisos libres para empalmar).
2. Plataformas y suelo de hielo entre salas (`plat_ice`) para que la torre entera se sienta helada, no solo las salas.
3. Escalera de dificultad: igual que la Pesadilla (`RoomPool.target`/`rating`), pero con el rating recalculado para hielo (los resbalones y el castigo pesan más que los agarres).
4. Torres de 50 a 100 pisos como el resto (`RunState.rows_for`), con la grilla de 160 capas del solucionador nativo.
5. Pruebas del escenario (`hielo_total`, niebla, prisa...) y la habilidad *Garras de hielo*: hay que comprobar con el solucionador que las salas siguen siendo resolubles con y sin garras (las garras solo pueden ayudar) y que la habilidad cambia de verdad cómo se juega.

## Hitos

| Hito | Qué | Cómo se sabe que está |
|---|---|---|
| H1 | Generador: `--types=i`, `--min-ice`, métricas `slides` e `ice_moved`; Estudio muestra y filtra por ellas | `tests/test_generador.gd` extendido + 200 salas de prueba |
| H2 | Minería de 24 a 48 horas (la deja Dante) y cierre con prueba exacta | ≥ 3.000 salas con `slides ≥ 3`, sin repetidos, todas con prueba exacta |
| H3 | Curaduría en el Estudio y `data/glaciar.rooms` | 150 a 300 aprobadas, todas las familias, 5 a 11 pisos |
| H4 | Integración: filtro por escenario en `RoomPool`, anti-repetición, `plat_ice`, memoria en el perfil | tests de torres del Glaciar; el Glaciar deja de usar el generador viejo |
| H5 | Banco de torres del Glaciar y el bot | métricas de aceptación de abajo |
| H6 | Capturas y partida de prueba de Dante (3 torres) | ajustes de dureza |

H1 y H4 son trabajo mío; H2 es tiempo de máquina; H3 y H6 necesitan la vista de Dante.

## Métricas de aceptación

- Al menos el 70 % de las salas de una torre del Glaciar tienen `slides ≥ 3`.
- En 100 torres generadas, ninguna sala aparece más de 2 veces, y ningún grupo de firma supera el 12 % de las salas usadas.
- Dos torres seguidas comparten como máximo el 10 % de sus salas.
- Todas las torres verificadas por el solucionador exacto; tiempo de generación igual o menor al de una torre común.
- El bot cumple la curva de dificultad del escenario (muertes por torre comparables a la Pesadilla, algo más altas en las últimas etapas).

## Riesgos y decisiones

- **Frustración:** el hielo castiga (se cae uno). Mitigación: poner las salas más punitivas (Pista, Billar de dos topes) solo desde la mitad del run y marcar claramente los topes con el diseño de bloques.
- **Monotonía visual:** casi todo es hielo. Mitigación: las "Mixtas ligeras" y variantes de bloques de hielo (`BlockModels.VARIANTS` ya tiene 4 por tipo) y color de ambiente del escenario.
- **Generador:** el modo `--types=i` toca el C++; hay que comprobar que no cambia lo que produce sin ese flag (las pruebas de determinismo ya existentes).

## Decisiones de Dante (2026-10-19)

1. **El Glaciar dura 8 etapas** (no 15). Hay que comprimir la curva: propuesta, la etapa real `k` (1 a 8) usa la dificultad, el precio de Farolín, el nivel de casino y la escalera de bloques de la etapa "virtual" `1 + 2 (k - 1)` (1, 3, 5, 7, 9, 11, 13, 15), así el recorrido de dificultad y de economía llega igual de lejos en menos torres. Las pruebas caen en las virtuales 3, 9 y 15 (etapas reales 2, 5 y 8, tres pruebas). La pared de precios (virtual 8) queda entre la etapa real 4 y la 5. Las torres tienen menos pisos (piso mínimo por etapa real, a definir con el bot). Cada escenario pasa a tener `stages` (15 por defecto) y la etapa final sale de ahí; habrá que revisar `FINAL_STAGE`, `RunState.rows_for`, `Stages`, el cartel de la última torre y la Luz (el bono de escapar y el multiplicador).
2. **Las salas mixtas usan pesados, agrietados y pinchos como compañeros del hielo**, para que la partida no sea "todo hielo". Es el modo `--types=i,h,c,s` del generador. Las salas con hielo "puro" también existen, pero no son la regla.
3. **150 salas aprobadas para empezar.** Después se genera en cantidad fuera de línea (con `Generar_Salas.exe --glaciar` o `herramientas\generador_glaciar.bat`) una vez confirmado que el generador cumple (H1).

## Estado

- **H1 hecho (2026-10-19):** `generador.cpp` con `--types`, `--p-ice`, `--min-ice`, `--min-slides` y la métrica de resbalones; el cierre y `RoomLib.path_stats` guardan `opt.slides` y `opt.ice_moved` medidos con las reglas del juego (coinciden con los del generador); el Estudio ordena y filtra por resbalones; `generador_todo.gd --glaciar` y `herramientas\generador_glaciar.bat`. Pruebas: `test_generador` (`test_ice`), `test_studio_model`.
- Prueba de rendimiento: con `--min-ice=2 --min-slides=2` salen unas 6 salas por cada ~5 minutos de un solo proceso (mucho filtro); con `--min-ice=1 --min-slides=1` y `--p-type=0.9`, 8 a 10 salas en 18 segundos. Los parámetros definitivos (`--p-type`, `--p-ice`, mínimos) se calibran con la primera tanda larga.
- **Sigue H2:** una tanda de 24 a 48 horas con `--glaciar` para ver cuántas salas buenas salen y con qué `slides`, antes de curar.

## Giro de enfoque (2026-10-19): salas de deslizamiento

La tanda de una hora con el generador normal en modo hielo (368 salas) salió mal para lo que se busca: casi todo escaleras con uno o dos cubos de hielo. El formato de la biblioteca (una arena alrededor de un pilar que hay que trepar) y el generador (un buscador de escaleras con acertijo) no pueden dar un escenario helado con solo pedir "con hielo". Hace falta un generador propio con otra estructura:

- **Meseta de hielo** (`tests/probe_hielo_plano.gd`, prototipo): casi todas las columnas son de hielo; unas pocas llevan encima un bloque pesado o común que hace de tope; una rampa baja junto a la llegada; huecos al ras del piso. El desafío es resbalar bien (sala lateral, casi no se sube), no armar una escalera. La salida sigue siendo el pilar.
- **Resultado del prototipo** (6000 intentos, 4 a 6 pisos): 1.654 salas resolubles con prueba exacta y 359 buenas (más del 80 % de hielo, 3 o más resbalones, 8 o más pasos), en unos 8 minutos de un solo proceso. Archivo: `bibliotecas/glaciar_prototipo/plano.rooms`.
- **Pendiente** (según lo que diga Dante al verlas): bordes mortales, hielo que se empuja entre topes (billar), puentes angostos sobre el vacío, mesetas de varios niveles, compañeros (pinchos, agrietados), probarlas dentro de una torre y pasar el prototipo al generador nativo para generar en cantidad.
