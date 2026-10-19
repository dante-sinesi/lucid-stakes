# Interfaz con mando y teclado: botoneras

Regla de la interfaz: **casi sin botones en pantalla**. Cada pantalla dice la acción con la tecla (teclado) o el botón (mando) que la hace, abajo en una botonera; las listas del menú principal y de la pausa, las pestañas, los casilleros y los ajustes siguen siendo elementos que se eligen.

## Piezas
- `scripts/pad_hints.gd` (`PadHints`): la botonera. `set_items([{slot | name, key, text, call, keycode, when, dim}])`: `slot` es el botón de cara del mando (`PadGlyph.Slot`), `name` uno con nombre ("LB", "RB", "LT", "DPAD", "DPAD_LR", varios con "|"), `key` lo que se muestra con teclado ("Enter", "Esc"...), `call` lo que pasa al tocarla con el mouse, `keycode` (opcional) la tecla que la acciona mientras la pantalla se ve y `when` una condición. `PadHints.attach(pantalla, items, botones_que_reemplaza)` la pone abajo y oculta esos botones (siguen existiendo, sin foco, para las pruebas); `attach_in(contenedor, ...)` la pone dentro de una ventana.
- `scripts/pad_glyph.gd` (`PadGlyph`): dibuja los botones (letras de Xbox, símbolos de PlayStation) y las teclas. El estilo sale de Opciones → Controles → "Botones del mando" (automático, Xbox o PlayStation; el automático lee el nombre del mando conectado).
- `scripts/pad_bridge.gd`: traduce el mando a teclas (A = Enter, X = Espacio, Y = C, B = Esc, cruceta y stick izquierdo = flechas, LB/RB = Q/E, LT = Shift). Sigue andando con el juego en pausa y no cuenta como teclado las teclas que él mismo arma (si no, las ayudas saltaban a teclado al apretar un botón). Se quitan los eventos de joystick de las acciones `ui_*` de Godot para que el foco no avance de a dos.
- `Controls.using_pad`: qué ayudas se muestran. Opciones → Controles → "Ayudas de": Automático (lo último que se usó), Teclado o Mando.
- `scripts/confirm_box.gd`: cuadro de confirmación (abandonar la partida; empezar una partida nueva sobre una sin terminar, con el progreso que se pierde).
- Teclado y mando juegan con las mismas teclas: ruleta (Enter gira, Espacio pone la ficha de la casilla marcada, flechas mueven la marca, Q/E cambian la apuesta, C premios, Shift rota la vitrina), tragamonedas (Enter gira, Espacio cobra, flechas retienen), blackjack (Enter reparte o pide, Espacio se planta, C dobla).
- Los botones de las pantallas de juego, los servicios del casino, los menús, la derrota y el fin de la partida están ocultos y reemplazados por la botonera; el botón apuntado (foco) lleva un marco blanco que titila (`voxel_button.gd`).

## Pruebas
`tests/test_mando.gd` (pausa, foco, dispositivo, estilo y los tres juegos), `tests/test_confirmaciones.gd`, `tests/test_casino_services.gd` (selección con flechas), `tests/test_neutro.gd` (español neutro en todo el juego).
Capturas: `tests/shot_juegos_mando.gd`, `shot_dialogo_mando.gd`.

## Texto
Todo lo que ve el jugador va en español neutro (tuteo, sin voseo). Las traducciones al inglés están en `scripts/loc_en*.gd` (las frases nuevas de la botonera en `loc_en_mando.gd`, lo que dicen los personajes en `loc_en_dialogos.gd`).

## Ayudas de los juegos
`scripts/game_help.gd` (`GameHelp`): panel de varias páginas con dibujitos de cubitos para la ruleta, la tragamonedas, el blackjack, los dados del tabernero y las estaciones del casino (taller, caja fuerte, tienda). Se abre solo la primera vez que se entra a cada juego (`Profile.help_seen`; no en pruebas sin pantalla: `GameHelp.auto_open`) y se vuelve a abrir con H (teclado) o Select (mando; `PAD_FIXED` lo traduce a H en menús y juegos). Mientras está abierta se queda con todas las teclas: flechas o Enter pasan de página, Esc o H cierran, sin cerrar el juego de atrás. Siempre figura como "Ayuda" al final de la botonera del juego (`PadHints.add_extra`). Los textos están en `GameHelp.PAGES` (con {enter}, {space}, {arrows}... que se reemplazan por la tecla o el botón) y su traducción en `loc_en_ayudas.gd`. Para agregar un juego: sus páginas en `PAGES`, un dibujito en `_Art` y `GameHelp.attach(pantalla, id)`. Pruebas: `tests/test_ayudas.gd`; capturas: `tests/shot_ayudas.gd`.

## Foco ordenado
En Opciones (`options_screen.gd`, `_link_focus`) y en la pantalla de personaje (`cosmetics_screen.gd`) el foco se mueve por filas: izquierda y derecha dentro de la fila, arriba y abajo de fila en fila, sin saltos; las listas con desplazamiento acompañan al foco (`follow_focus`). Pruebas: `test_opciones_foco.gd`, `test_cosmeticos_foco.gd`.
