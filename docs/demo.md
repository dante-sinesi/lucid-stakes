# La demo de Steam: cómo está armada y cómo se construye

Cómo está armada la demo, cómo se construye y cómo se prueba.

## Qué es
El mismo código del juego completo con un interruptor (`scripts/datos/demo.gd`). `Demo.on()` es verdadero en la compilación "Windows Demo" (característica personalizada `demo` del preset) o con `GAME_DEMO=1` en el editor. Sin el interruptor el juego completo no cambia (`tests/unitarios/test_demo.gd` lo comprueba).

- **Contenido:** el tutorial y La Pesadilla hasta el casino de la etapa 6 (`Demo.LAST_STAGE`): las dos pruebas (etapas 3 y 6) y el segundo casino (el salón, desde la etapa 4). Al pagarle a Farolín en ese casino, o al abandonar (sin vidas y sin claridad), sale la pantalla de fin de la demo (`demo_end_screen.gd`) con el resumen, el agradecimiento y la lista de deseos (`Demo.WISHLIST_URL`: completar con la dirección de la página en Steam).
- **Recortes** (todos por `Demo`): los demás escenarios dicen "Próximamente" (tarjeta bloqueada); el botón Habilidades avisa "Disponible en la versión completa"; el blackjack y las tragamonedas avisan "Disponible en el juego completo"; cosméticos: Corona y Gorro de lana, Remera y Capa (vienen desbloqueados, los demás salen con "?" y, al pasar el mouse, "Disponible en la versión completa"); personajes: Dante, Gaby, gatito (predeterminado) y perrito.
- **Torres:** se arman en vivo como en el juego completo (la generación es instantánea); la demo no genera nada más allá de su última etapa.
- **Guardado aparte:** `user://demo/` (perfil y partida): la demo no pisa los guardados del juego completo.
- Título de la ventana: "Balatro x Catherine — Demo".

## Construirla
1. Exportar con el preset **Windows Demo**: `tools\Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Windows Demo" build/demo/BalatroXCatherineDemo.exe` (el preset incluye `data/*.jsonl` —la biblioteca de salas— y `data/modelos/*`; las escenas de herramientas no se exportan). Para el juego completo: preset "Windows Desktop".
2. Probarla en el editor: `GAME_DEMO=1 herramientas\demo.bat`

## Pruebas
`tests/unitarios/test_demo.gd` (interruptor, recortes, fin de la demo), `test_farolin.gd` y `test_telemetria.gd`. La batería completa: `bash tests/correr_todos.sh` (cada prueba termina con "fallos: N").

## Prueba con jugadores (pendiente de Dante: hace falta gente)
- 5 a 10 personas, una sesión de 45 minutos cada una, sin explicarles nada; se anota dónde se traban, qué no entienden y cuándo se aburren.
- El juego anota en `user://telemetria.jsonl` (sólo en la máquina del jugador; en Opciones → General → Datos de juego hay un botón para abrir la carpeta): por cada torre (etapa, resultado, segundos, movimientos, claridad, reintentos, vidas, causa), cada casino, cada decisión del peaje y el fin del run.
- Con esos datos se calibra la tasa de muerte del bot (`docs/bot.md`: hoy inventada) y la curva del peaje.

## Criterios para darla por cerrada (plan §0)
1. Un jugador nuevo termina el tutorial y entiende el bucle torre → casino → Farolín sin explicación externa (a verificar con jugadores).
2. 10 partidas completas seguidas sin errores ni torres sin generar.
3. La etapa 1 arranca en menos de 5 s.
4. Todas las pruebas en verde.
5. La exportación funciona (hecha: preset Windows Demo; falta probarla en una máquina limpia).
6. Al menos 5 personas de afuera la jugaron y lo que marcaron más de una vez está arreglado.
