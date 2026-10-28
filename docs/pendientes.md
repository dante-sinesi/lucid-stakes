# Pendientes e ideas

Lo que falta o se quitó a propósito, y las ideas anotadas (no son objetivos por ahora).

## Quitado en la limpieza (a repensar)

Al retirar la torre vieja se borraron, en vez de dejarlos sin efecto, los premios, pruebas y escenarios que dependían de reglas que ya no existen. Hay que repensar premios y pruebas con la torre actual:

- **Pruebas** que quedaron: Sin ayudas, Todo o nada y Sin racha. Se quitaron Niebla, Oscuridad, Prisa, Hielo total, Quebradizo, Polvorín y Lluvia de meteoritos (reglas propias de la torre vieja).
- **Consumibles y boosts retirados:** Ojo de hielo, Escudo, Doble salto, Teletransporte, Ancla chica, los ocho conversores de bloque, Fuerza bruta y Aire de más. Los que dependían de elegir un bloque con el mouse necesitan un selector de bloques para la torre actual.
- **Bot de balance:** funciona con la torre actual (`bot.md`) pero sólo juega por el camino mínimo y la ruleta (no tragamonedas ni blackjack).

## En pausa

- **Bloque trampa:** descontinuado hasta nuevo aviso. No hay salas con trampa (el generador no tiene el rol; `generador.md`) y ningún escenario ni logro puede depender de ella. Para retomarla hay que decidir su propósito en la sala: celda prohibida disfrazada, puente de un solo uso o bloque que hay que mover antes de pisarlo. El código del motor, el arte y la guía de bloques siguen ahí.

## Propuestas para conversar

- **Escenarios:** `escenarios_propuestas.md` (los siete escenarios que cambian reglas y no salas, ya implementados; quedan las ideas para después: Hemorragia, Racha o nada, Doble o nada y Sin red, y las preguntas abiertas).
- **Logros de Steam:** `logros.md` (48 logros más secretos, con los 18 que se pueden ganar en la demo). Decidido: los logros de la demo no se transfieren al juego completo (la demo es otra app de Steam, sus logros son básicos y se vuelven a ganar enseguida). Mejora posible si sobra tiempo: que la demo guarde sus logros en su archivo y el juego completo los entregue al abrirse.

## Ideas de premios para esta torre

Consumibles: **Susurro de Farolín** (ilumina el próximo movimiento óptimo con el solucionador nativo), **Reinicio limpio** (reinicia la sala sin perder una vida), **Dado de Farolín** (cambia la sala siguiente por otra del mismo nivel), **Ancla de checkpoint** (el próximo checkpoint asegura el doble, con riesgo), **Cuerda** (colgarse y trepar por cornisa no gastan movimientos).
Boosts: **Ojo de Farolín** (avisa de un movimiento en falso sin castigarlo), **Botas gruesas** (los pinchos no matan la primera vez en cada sala), **Mecha de seda** (las bombas sólo cuentan dentro de su zona y sobre un bloque común), **Tributo de checkpoint** (claridad extra según las salas pasadas), **Camino pesado** (la sala siguiente un nivel más difícil con claridad ×1,5).
Habilidad persistente: **Buen oído** (aviso sonoro cuando la sala siguiente tiene especiales).

Decisiones abiertas: cuántos entran en la primera tanda y si van al casino como premios nuevos o reemplazan a los retirados.

## Cosas del juego a revisar

- **El Taller:** ya es una fragua con chimenea, horno encendido y yunque (`casino_muebles.gd`); falta ver si en el juego llama a descubrirse (se podría sumar un personaje o una animación de las chispas).
- **Casinos, lo que falta del plan (`plan_casinos.md`):** que el bot juegue contratos. (Decidido: el casino y el gran casino no llevan estación; solo el Taller del salón.)
- Los bloques ya no se aclaran con la etapa (solo el fondo y la luz): decidir si se retoma. Revisar también la ayuda de profundidad con la cámara de la torre.
- Música: decidir tempo, volumen y si se agrega percusión (se probaron variantes al 90, 80 y 70 % sin preferencia clara: `herramientas/musica/render_estaciones.py --tempo=0.8 --solo-previa`).
- Calibrar la economía con partidas reales (`economia.md`).
- **El solucionador en el juego exportado:** ya viaja como extensión de Godot para Windows (`solver_extension.md`; hay que armar la biblioteca release con `native\construir_extension.bat` antes de exportar). Falta armarla para Linux, macOS y Android (y bajar los topes de estados en celulares) cuando se quiera portar.

## Ideas anotadas

- **Telemetría remota de la demo:** hoy `telemetry.gd` guarda todo sólo en la computadora del jugador. Se podría enviar de forma anónima (un servidor mínimo propio, con consentimiento la primera vez, un interruptor en Opciones, identificador aleatorio y cola de reenvío), o usar estadísticas y logros de Steamworks. Serviría para reemplazar la calibración inventada del bot con datos reales.
- **Salas de la comunidad y Steam Workshop** (después de la demo, antes del lanzamiento): que los jugadores creen salas o paquetes y los suban. Se pulirá el Estudio y se publicará como herramienta aparte. Requisito de Dante: el juego tiene que **calcular por su cuenta** si una sala es resoluble y su % de dificultad, sin confiar en el archivo. Notas: (a) el solucionador nativo corre como .exe aparte, hay que empaquetarlo o tener un respaldo en GDScript con tope; (b) verificar una vez al instalar y guardar el resultado en una caché local por hash del contenido; (c) límites de tamaño y de tipos de bloque; (d) las salas del Workshop van en un conjunto aparte de `data/salas_torre.jsonl` y el jugador elige si las usa; (e) formato versionado, sólo datos, sin código ejecutable.
