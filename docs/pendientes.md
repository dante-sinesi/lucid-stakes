# Pendientes e ideas

Lo que falta o se quitó a propósito, y las ideas anotadas (no son objetivos por ahora).

## Quitado en la limpieza (a repensar)

Al retirar la torre vieja se borraron, en vez de dejarlos sin efecto, los premios, pruebas y escenarios que dependían de reglas que ya no existen. Hay que repensar premios y pruebas con la torre actual:

- **Pruebas** que quedaron: Sin ayudas, Todo o nada y Sin racha. Se quitaron Niebla, Oscuridad, Prisa, Hielo total, Quebradizo, Polvorín y Lluvia de meteoritos (reglas propias de la torre vieja).
- **Escenarios "Próximamente"** (tarjetas bloqueadas, sin entrar): Ruinas, Polvorín, Relojería, Compromiso y Gran Casino. Sus descripciones todavía hablan de mecánicas viejas (fila que cae, una sola vida): reescribir cuando se diseñen.
- **Habilidades pendientes** (`Abilities.PENDING`): Mecha larga, Pies ligeros, Corazón extra, Bolsillo de soñador, Segunda oportunidad.
- **Consumibles y boosts retirados:** Ojo de hielo, Escudo, Doble salto, Teletransporte, Ancla chica, los ocho conversores de bloque, Fuerza bruta y Aire de más. Los que dependían de elegir un bloque con el mouse necesitan un selector de bloques para la torre actual.
- **Bot de balance:** funciona con la torre actual (`bot.md`) pero sólo juega por el camino mínimo y la ruleta (no tragamonedas ni blackjack).

## Ideas de premios para esta torre

Consumibles: **Susurro de Farolín** (ilumina el próximo movimiento óptimo con el solucionador nativo), **Reinicio limpio** (reinicia la sala sin perder una vida), **Dado de Farolín** (cambia la sala siguiente por otra del mismo nivel), **Ancla de checkpoint** (el próximo checkpoint asegura el doble, con riesgo), **Cuerda** (colgarse y trepar por cornisa no gastan movimientos).
Boosts: **Ojo de Farolín** (avisa de un movimiento en falso sin castigarlo), **Botas gruesas** (los pinchos no matan la primera vez en cada sala), **Mecha de seda** (las bombas sólo cuentan dentro de su zona y sobre un bloque común), **Tributo de checkpoint** (claridad extra según las salas pasadas), **Camino pesado** (la sala siguiente un nivel más difícil con claridad ×1,5).
Habilidad persistente: **Buen oído** (aviso sonoro cuando la sala siguiente tiene especiales).

Decisiones abiertas: cuántos entran en la primera tanda y si van al casino como premios nuevos o reemplazan a los retirados.

## Cosas del juego a revisar

- Los bloques ya no se aclaran con la etapa (solo el fondo y la luz): decidir si se retoma. Revisar también la ayuda de profundidad con la cámara de la torre.
- La ayuda de texto de los menús no menciona WASD.
- Música: decidir tempo, volumen y si se agrega percusión (se probaron variantes al 90, 80 y 70 % sin preferencia clara: `herramientas/musica/render_estaciones.py --tempo=0.8 --solo-previa`).
- Calibrar la economía con partidas reales (`economia.md`).
- La exportación excluye `tools/*`: el solucionador nativo (`tools/salas.exe`), que usa Sin piedad, no viaja con el juego exportado; hay que empaquetarlo o tener respaldo.

## Ideas anotadas

- **Telemetría remota de la demo:** hoy `telemetry.gd` guarda todo sólo en la computadora del jugador. Se podría enviar de forma anónima (un servidor mínimo propio, con consentimiento la primera vez, un interruptor en Opciones, identificador aleatorio y cola de reenvío), o usar estadísticas y logros de Steamworks. Serviría para reemplazar la calibración inventada del bot con datos reales.
- **Salas de la comunidad y Steam Workshop** (después de la demo, antes del lanzamiento): que los jugadores creen salas o paquetes y los suban. Se pulirá el Estudio y se publicará como herramienta aparte. Requisito de Dante: el juego tiene que **calcular por su cuenta** si una sala es resoluble y su % de dificultad, sin confiar en el archivo. Notas: (a) el solucionador nativo corre como .exe aparte, hay que empaquetarlo o tener un respaldo en GDScript con tope; (b) verificar una vez al instalar y guardar el resultado en una caché local por hash del contenido; (c) límites de tamaño y de tipos de bloque; (d) las salas del Workshop van en un conjunto aparte de `data/salas_torre.jsonl` y el jugador elige si las usa; (e) formato versionado, sólo datos, sin código ejecutable.
