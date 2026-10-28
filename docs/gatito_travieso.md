# Ama, la gata traviesa: el personaje de la prueba Travesuras

El gato de la prueba **Travesuras** (`pruebas.md`) se llama **Ama**, como la gata de Dante en la que está inspirado: un gato de pelo largo, gris atigrado, con la mirada seria y las orejas en punta. El modelo es `scripts/personajes/gatito_travieso.gd`, las poses y movimientos están en `scripts/personajes/gatito_anim.gd` y se pueden ver con `tests/capturas/shot_gatito_modelo.gd`.

## Cómo es

Un gato **de cuatro patas, cuerpo largo y cabeza cuadrada** como los de Minecraft, pero con la personalidad de Ama. Mide la mitad de un personaje y cabe en un bloque.

De Ama:
- **Pelo gris atigrado**, con rayas finas en los costados, las patas y el lomo, y los anillos en la cola esponjada, que termina en punta oscura.
- **Pechera blanca** esponjosa, cachetes crema y las patitas claras.
- **La "M" de la frente**: tres rayas oscuras, y las marcas a los costados de los ojos.
- **Ojos verde claro** con la pupila vertical y el párpado a medio cerrar: la mirada seria y de reojo de las fotos.
- **Orejas en punta con mechones**, de adentro rosadas. La derecha tiene la punta **doblada**, como en una de las fotos.
- **Nariz durazno** y bigotes largos y claros.

Lo "travieso" que se agregó: un **collar azul con cascabel** que suena cuando salta (y delata sus travesuras).

## Las animaciones

**En la prueba:**
1. **Aparecer** sobre el bloque de entrada, junto al personaje.
2. **Saltar** de bloque en bloque: estira las patas en el aire y cae con un cascabelazo.
3. **Empujar** el bloque con la patita, en tres golpecitos, **mirando al jugador de reojo**; el gato se va con el bloque encima.
4. **Esperar junto a Farolín** en el checkpoint (abajo).

**La cámara.** Mientras Ama mueve bloques, la cámara **pasa al centro de la sala y el zoom cambia para contenerla entera**, así se la ve moverse de bloque en bloque. Cuando llega al checkpoint, la cámara **vuelve al personaje** y al zoom de siempre, de a poco. (El zoom es el justo para la altura y el ancho de la sala; en las salas bajas casi no cambia.)

**La espera: las poses de las fotos de Ama.** El gato espera en el bloque de salida mirando a Farolín. **Cuanto más tarda el jugador, más se va durmiendo**, pasando por las cuatro poses de las fotos:

| Pose | De qué foto | Cuánto dura |
|---|---|---|
| **Sentada**, atenta, con la cabeza girada de reojo | el retrato | 6 s |
| **Esfinge** ("pan de carne"): echada, con las patitas metidas, atenta | la que está acostada sobre el piso | 9 s |
| **Estirada**: las patas delanteras estiradas hacia adelante, la cabeza baja, los ojos cerrados | la que está dormitando estirada | 9 s |
| **Bollito**: hecha un ovillo, durmiendo, con una patita estirada y la cola alrededor | la que duerme al sol | hasta que el jugador sigue |

En todas mueve la cola despacio, las orejas de vez en cuando y parpadea (dormida, casi no se mueve). Los cambios de pose son suaves.

## Con Farolín (la espera)

Mientras espera en el checkpoint (`scripts/personajes/ama_farolin.gd`, que usa `torre_juego.gd`), después de un momento sentada y atenta, Ama hace **dos de estas tres travesuras, al azar**, y después se va quedando dormida:

- **Mirar la llama:** la cabeza sigue el titilar del farol, con los ojos bien abiertos y la colita inquieta; Farolín la mira de vuelta.
- **Frotarse:** trota hasta él y se frota yendo y viniendo, con la cola en alto y los ojitos cerrados; el cuerpo vibra (el ronroneo) y la llama de Farolín brilla más.
- **Robarle el sombrero:** el "sombrero" de Farolín es la tapa del farol. Ama se hace la distraída, se acerca, se para en dos patas y se lo saca de un manotazo (Farolín se sorprende y se pone triste); se lo lleva puesto, orgullosa, y después se lo devuelve (Farolín se rasca la cabeza, contento).

Después viene la espera de siempre (esfinge y estirada) y al final **se acurruca**: se pega a Farolín y se duerme hecha un bollito apoyada en él; Farolín baja la llama. Si el jugador llega al checkpoint a la mitad de una travesura, se corta y todo vuelve a su lugar (el sombrero, el ánimo y la llama de Farolín).

Pruebas: `tests/unitarios/test_gatito.gd` (la espera completa, cada travesura y el corte a la mitad); captura de cada una: `tests/capturas/shot_ama_farolin.gd`.

## Lo que falta

Las reacciones en la torre: se eriza si hay una bomba cerca y se tapa los ojos con la pata si el jugador pierde la sala.

## Cómo está hecho

- Cada parte tiene un nombre: `cuerpo`, `cabeza`, `oreja_i`, `oreja_d`, `pata_di`, `pata_dd`, `pata_ti`, `pata_td` (delanteras y traseras), `cola_1`, `cola_2`, `cascabel`, `ojo_i` y `ojo_d`.
- Una **pose** es un diccionario por parte (posición, giro y escala) que se aplica de golpe o se mezcla con otra para los cambios suaves.
- Las animaciones del gato son propias (no sirven las del personaje, que es de dos patas).
- El modelo se hace con cubos en el código, como Farolín y los personajes; si se prefiere retocar a mano, se puede pasar al **editor de modelos** (`editor_modelos.md`).
- Pruebas: `tests/unitarios/test_gatito_modelo.gd` (el modelo, las poses y los movimientos) y `tests/unitarios/test_gatito.gd` (la prueba en el juego).
