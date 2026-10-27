# El gatito travieso: el personaje

Diseño del gato de la prueba "El gatito travieso" (`pruebas.md`). Hoy el juego usa de reemplazo el modelo del personaje gatito; esto es el diseño del gato verdadero.

## Cómo es

Un gato **de cuatro patas, cuerpo largo y cabeza cuadrada** como los de Minecraft, pero con personalidad propia. Mide la mitad de un personaje (unos 0,5 de alto y de largo), así que se ve chiquito al lado de quien juega. El código es `scripts/personajes/gatito_travieso.gd` y hay una captura para compararlos (`tests/capturas/shot_gatito_modelo.gd`).

Lo que lo diferencia de un gato de Minecraft:
- **Orejas desparejas:** una tiene la punta doblada (una oreja que se rompió en alguna travesura).
- **Ojos de reojo:** entornados, con la pupila vertical y el párpado marcado, como si siempre estuviera planeando algo. En el atigrado, **de distinto color** (uno verde y uno ámbar).
- **Cascabel:** un collar con cascabel que suena cuando salta (y delata sus travesuras).
- **Cola con punta clara y en gancho.**
- **Más expresivo:** orejas y bigotes que se mueven, y animaciones propias (abajo).

## Los tres diseños para elegir

| | Diseño | Cómo es |
|---|---|---|
| 1 | **Atigrado** | gris con rayas oscuras en el lomo y la frente, medias y pecho blancos, ojos de distinto color, collar rojo |
| 2 | **Smoking** | negro con pecho, patas y hocico blancos, bigote blanco, ojos amarillos, collar azul |
| 3 | **Siamés** | crema con máscara, orejas, patas y cola marrón oscuro, ojos azules, collar verde |

Ninguno se parece al gatito naranja del jugador. El atigrado tiene los ojos de colores distintos, que es lo más "con personalidad"; el smoking es el más elegante y el que mejor se lee sobre los bloques oscuros de la torre; el siamés es el más claro y el que más resalta.

## Las animaciones

**Para la prueba (primero):**
1. **Aparecer:** entra trotando al bloque de entrada.
2. **Trotar:** cuatro patas en diagonal, la cola en alto.
3. **Saltar:** se agacha, salta y cae con un cascabelazo.
4. **Empujar:** se para y empuja el bloque con la patita, mirando al jugador de reojo.
5. **Esperar sentado:** en el checkpoint, la cola se mueve, las orejas giran, parpadea.

**Con Farolín (después):**
6. **Se frota contra Farolín** y ronronea (tiembla un poquito).
7. **Persigue la llama** con la mirada y la quiere atrapar con la pata; Farolín la aleja.
8. **Farolín lo mira de reojo** y se hace el distraído mientras el gato le roba el sombrero (¡una travesura más!).
9. **Se duerme** hecho un bollito junto a Farolín cuando el jugador tarda mucho.

**Reacciones del gato en la torre (opcional):** se erizan los pelos si hay una bomba cerca; se tapa los ojos con la pata si el jugador pierde la sala.

## Cómo se construiría

- Cada parte tiene un nombre para las animaciones: `cabeza`, `oreja_i`, `oreja_d`, `pata_di`, `pata_dd`, `pata_ti`, `pata_td` (delanteras y traseras), `cola_1`, `cola_2` y `cascabel`.
- Las animaciones del gato son propias (no sirven las del personaje, que es de dos patas): un módulo aparte con las poses de cada una.
- El modelo se hace con cubos en el código, como Farolín y los personajes. Si prefieres retocarlo a mano después, se puede pasar al **editor de modelos** (`editor_modelos.md`).

## Preguntas

1. ¿Cuál de los tres diseños?
2. ¿Le damos un nombre? Mi propuesta: **Cascabel**.
3. ¿Las animaciones con Farolín las dejamos para una segunda etapa?
4. ¿Algún detalle más de personalidad que quieras?
