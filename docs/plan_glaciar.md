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

## Preguntas para Dante

1. ¿El Glaciar tiene las 15 etapas como la Pesadilla, o un run más corto (por ejemplo 10)?
2. ¿Se permite que las salas mixtas usen pesados y agrietados como compañeros del hielo, o hielo "puro"?
3. ¿Cuántas salas aprobadas son suficientes para vos antes de armar el banco (propongo 150 como mínimo)?
