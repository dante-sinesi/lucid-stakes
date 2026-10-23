# Replanteo de boosts y consumibles para la torre nueva

Estado al pasar el juego a la torre nueva (rama `feature/recuperar-torre-vieja`). Es una propuesta para decidir: nada de lo de la sección 3 está programado todavía.

## 1. Qué cambió en las reglas de la torre y por qué importa a los premios

La torre vieja tenía **una fila de abajo que caía cada N movimientos**, piso con un núcleo, y un solo bloque común de cada tipo especial a la vez. La torre nueva tiene:

- un **temporizador de movimientos por sala** (al agotarse cae la sala entera);
- salas apiladas en espiral alrededor de un **vacío de 5x5**, sin piso;
- un **checkpoint** entre sala y sala (y Farolín sentado en el próximo);
- **deshacer** ilimitado dentro de la sala;
- **salas con 1 a 3 bloques especiales** (hielo, pesado, agrietado, trampa, pinchos, bomba, trampolín) según la etapa;
- **vidas del run**: al perder una sala se reintenta esa sala (−1 vida).

Los premios que hablaban de "la caída de la fila base" tenían que traducirse (hecho); los que dependían de elegir un bloque con el mouse o de reglas que no existen más, no.

## 2. Qué quedó sin efecto (y qué hacía)

| Premio | Qué hacía en la torre vieja | Por qué no anda hoy | Se puede… |
|---|---|---|---|
| **Ojo de hielo** (boost, común) | Al resbalar por hielo te frenabas una celda antes | El motor nuevo no lo implementa | **Adaptar**: es una condición en `_resbalar` (parar una celda antes si hay boost). Fácil. |
| **Escudo** (consumible) | Si explotaba una bomba, no te afectaba (se rompía el escudo) | La explosión hoy pierde la sala siempre | **Adaptar**: al explotar, la bomba se desactiva y se gasta el escudo. Fácil. |
| **Doble salto** (consumible) | Tu próximo salto subía 2 bloques en vez de 1 | No existe en el motor nuevo | **Adaptar**: el próximo trepar sube 2 si hay lugar. Medio (el solucionador no lo conoce, pero es opcional: no rompe las salas). |
| **Teletransporte** (consumible) | Elegir con el mouse un bloque a 5 cubos o menos y aparecer encima | La elección de bloque con el mouse está atada a la torre vieja | **Adaptar** con un selector de bloques para la torre nueva (rayo desde la cámara). Medio. |
| **Ancla chica** (consumible) | Un bloque a elección no caía aunque perdiera sus vecinos (una etapa) | La torre nueva ya sostiene por propagación y los bloques sueltos caen sólo en pisos concretos | **Reemplazar** (ver 3.3). |
| **8 conversores** (consumibles): roca, hielo, agrietado, trampa, pinchos, pesado, bomba, catapulta | Convertían cualquier bloque en ese tipo (se elegía con el mouse) | Mismo selector de bloques; y varios (trampa, pinchos, bomba) rompen la solución de la sala sin ayudar | **Adaptar sólo algunos** (roca, hielo, catapulta) con el selector; **reemplazar el resto** (ver 3.3). |
| Habilidad **Fuerza bruta** | Permitía empujar y tirar bloques pesados | El motor nuevo nunca deja mover un bloque pesado | **Adaptar**: si hay el perk, el pesado se empuja (el solucionador no lo sabe; es opcional). Fácil. |

Funcionan y están traducidos a la torre nueva: Madrugada (+25 % de movimientos por sala), Aire extra (+4), Paso firme (trepar y bajar no gasta), Reflejos (bombas +3), Segundo aliento (una vez por torre), Pies ligeros y Aire de más (+movimientos), Freno (+5) y Reloj de arena (+10), y todos los de claridad.

## 3. Propuesta

### 3.1 Recuperar tal cual (con poco trabajo)
Ojo de hielo, Escudo y Fuerza bruta: son una condición cada uno en el motor.

### 3.2 Recuperar con un selector de bloques para la torre nueva
Teletransporte, Doble salto (no necesita selector) y los conversores de roca, hielo y catapulta (convertir un bloque estorbo en uno común, un tramo de hielo para deslizarse o una catapulta). El selector sería el mismo del juego (mouse o stick sobre el bloque), pero apuntando a la torre nueva.

### 3.3 Reemplazos nuevos pensados para esta torre
Ideas que usan cosas que sólo existen ahora:

**Consumibles**
1. **Susurro de Farolín**: ilumina el próximo movimiento óptimo de la sala (lo calcula el solucionador nativo, el mismo de Sin piedad). Un solo uso.
2. **Reinicio limpio**: reinicia la sala actual sin perder una vida (hoy reintentar cuesta −1 vida). Para cuando te trabaste.
3. **Dado de Farolín**: cambia la sala siguiente por otra del mismo nivel.
4. **Ancla de checkpoint**: el próximo checkpoint que alcances vale doble de claridad asegurada (apuesta: si morís antes, se pierde).
5. **Cuerda**: el próximo colgado y las próximas trepadas por cornisa no gastan movimientos de la sala.

**Boosts**
6. **Ojo de Farolín**: avisa cuando hacés un movimiento en falso (el mismo medidor de Sin piedad) sin castigarlo: sirve para aprender.
7. **Botas gruesas**: los pinchos no te matan la primera vez en cada sala (sólo te frenan: el paso no se hace).
8. **Mecha de seda**: las bombas sólo cuentan los movimientos que hacés dentro de su zona *y* sobre un bloque común (más tiempo para pensar).
9. **Tributo de checkpoint**: cada checkpoint da claridad extra según las salas que ya pasaste.
10. **Camino pesado**: la sala siguiente es un nivel más difícil, pero su claridad vale ×1,5 (riesgo y recompensa).

**Habilidades persistentes**
11. **Buen oído**: Farolín te avisa con un sonido cuando la sala siguiente tiene bloques especiales.

### 3.4 Orden sugerido
1. 3.1 (Ojo de hielo, Escudo, Fuerza bruta): rápido y devuelve premios que ya existen.
2. Susurro de Farolín y Reinicio limpio (3.3-1 y 2): son los dos que más cambian cómo se juega y reutilizan lo que ya hay.
3. El selector de bloques y 3.2.
4. El resto de 3.3 según cómo se sienta el balance.

## 4. Pendiente de decisión
- ¿Se mantienen los 8 conversores o se dejan sólo roca, hielo y catapulta?
- ¿Los reemplazos nuevos van al casino como premios nuevos (nuevas casillas de la ruleta y la vitrina) o reemplazan a los que se retiran?
- Cuántos de los nuevos entran en la primera tanda.
