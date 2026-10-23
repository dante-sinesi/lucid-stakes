# La demo de Steam: cómo está armada y cómo se construye

Plan completo y decisiones de Dante: `docs/plan_demo.md`. Acá, lo que quedó hecho y cómo usarlo.

## Qué es
El mismo código del juego completo con un interruptor (`scripts/datos/demo.gd`). `Demo.on()` es verdadero en la compilación "Windows Demo" (característica personalizada `demo` del preset) o con `GAME_DEMO=1` en el editor. Sin el interruptor el juego completo no cambia (`tests/unitarios/test_demo.gd` lo comprueba).

- **Contenido:** el tutorial y La Pesadilla hasta el casino de la etapa 6 (`Demo.LAST_STAGE`): las dos pruebas (etapas 3 y 6) y el segundo casino (el salón, desde la etapa 4). Al pagarle a Farolín en ese casino, o al abandonar (sin vidas y sin claridad), sale la pantalla de fin de la demo (`demo_end_screen.gd`) con el resumen, el agradecimiento y la lista de deseos (`Demo.WISHLIST_URL`: completar con la dirección de la página en Steam).
- **Recortes** (todos por `Demo`): los demás escenarios dicen "Próximamente" (tarjeta bloqueada); el botón Habilidades avisa "Disponible en la versión completa"; el blackjack y las tragamonedas avisan "Disponible en el juego completo"; cosméticos: Corona y Gorro de lana, Remera y Capa (vienen desbloqueados, los demás salen con "?" y, al pasar el mouse, "Disponible en la versión completa"); personajes: Dante, Gaby, gatito (predeterminado) y perrito.
- **Torres:** salen del banco `data/torres_demo.torres` (84 torres verificadas, 12 o más por etapa para las etapas 1 a 6): carga instantánea, siempre se pueden ganar y no hace falta el solucionador nativo. La demo no genera nada más allá de su última etapa. Si el banco no tiene la etapa, se genera en vivo como siempre.
- **Guardado aparte:** `user://demo/` (perfil y partida): la demo no pisa los guardados del juego completo.
- Título de la ventana: "Balatro x Catherine — Demo".

## Construirla
1. Banco de torres (sólo si cambió el generador o la biblioteca): `herramientas\banco_torres.bat` (por defecto etapas 1 a 6, 12 torres, semilla 5000; las que no pasan la verificación se descartan; tarda unos minutos).
2. Exportar con el preset **Windows Demo**: `tools\Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Windows Demo" build/demo/BalatroXCatherineDemo.exe` (el preset incluye `data/*.rooms`, `data/modelos/*` y el banco; las escenas de herramientas no se exportan). Para el juego completo: preset "Windows Desktop".
3. Probarla en el editor: `GAME_DEMO=1 tools\Godot_v4.7.2-stable_win64.exe --path .`

## Pruebas
`tests/unitarios/test_demo.gd` (interruptor, recortes, fin de la demo), `tests/test_banco.gd` (cada torre del banco se gana con su camino, no hay repetidas, el juego las usa al instante), `tests/unitarios/test_farolin.gd`, `tests/unitarios/test_telemetria.gd`. La batería completa se corre con todos los `tests/test_*.gd` (cada uno termina con "fallos: N").

## Prueba con jugadores (pendiente de Dante: hace falta gente)
- 5 a 10 personas, una sesión de 45 minutos cada una, sin explicarles nada; se anota dónde se traban, qué no entienden y cuándo se aburren.
- El juego anota en `user://telemetria.jsonl` (sólo en la máquina del jugador; en Opciones → General → Datos de juego hay un botón para abrir la carpeta): por cada torre (etapa, resultado, segundos, movimientos, claridad, reintentos, vidas, causa), cada casino, cada decisión del peaje y el fin del run.
- Con esos datos se calibra la tasa de muerte del bot (`docs/bot.md`: hoy 3 % a 20 % por torre, inventada) y la curva del peaje.

## Criterios para darla por cerrada (plan §0)
1. Un jugador nuevo termina el tutorial y entiende el bucle torre → casino → Farolín sin explicación externa (a verificar con jugadores).
2. 10 partidas completas seguidas sin errores ni torres sin generar (el banco las evita).
3. La etapa 1 arranca en menos de 5 s (con el banco, instantánea).
4. Todas las pruebas en verde.
5. La exportación funciona (hecha: preset Windows Demo; falta probarla en una máquina limpia).
6. Al menos 5 personas de afuera la jugaron y lo que marcaron más de una vez está arreglado.
