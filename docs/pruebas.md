# Pruebas: las que hay y las que podrían venir

Borrador para conversar. La primera parte describe lo que hay hoy en el juego; la segunda, ideas nuevas **solo conceptuales** (sin pensar en cómo se programan): lo que importa es que sean divertidas.

## Cómo funcionan las pruebas hoy

Una prueba es una etapa especial, como los jefes de Balatro: **la torre de esa etapa cambia una regla**.

- **Cuándo caen:** en las etapas **3, 6, 9, 12 y 15** (una por cada tres etapas, cinco por partida).
- **Qué prueba toca:** se sortea al empezar la partida, entre las que admite el escenario, y **nunca se repite la misma dos veces seguidas**. El jugador sabe desde el principio cuál es la próxima y cuántas etapas faltan.
- **Cómo se ve:** al empezar la torre, el nombre de la prueba aparece grande, abajo en la pantalla, con su descripción; se vuelve a ver entero al pausar.
- **Qué pagan:** la claridad que juntas en esa torre se multiplica por **×1,5 / ×1,8 / ×2,1 / ×2,4 / ×2,7** (cada prueba paga más que la anterior), y al superarla regalan **un boost raro** (épico en las dos últimas; si no hay lugar, claridad).
- **Qué pasa si fallas:** se pierde la sala como siempre, salvo en Todo o nada (ver abajo). Cada prueba superada también suma 20 puntos de avance para la Luz del final del run.

## Las pruebas actuales (3)

| Prueba | Qué hace | Cómo se siente |
|---|---|---|
| **Sin ayudas** | No se pueden usar consumibles durante toda la torre. | Una prueba tranquila: solo castiga a quien llegó con consumibles guardados. |
| **Todo o nada** | No hay reintentos: si caes, o se agotan los movimientos, **se termina la partida**. | La más tensa: cada sala se juega con la partida entera en juego. |
| **Sin racha** | La racha no sube el multiplicador de claridad: cada bloque vale lo mismo. | La más suave: casi no cambia cómo se juega, solo cuánto se gana. |

**Qué escenarios las usan:** La Pesadilla, las tres. Los demás eligen entre dos o tres según su idea (Compromiso no usa Todo o nada: con una sola vida ya sería redundante).

### Qué se podría mejorar de las actuales

- **Sin ayudas** depende de que el jugador tenga consumibles: si no tiene, la prueba es gratis y no se nota. Podría extenderse a algo que todos tengan (por ejemplo, también apagar los boosts de cosecha durante la torre) o pasar a "un solo consumible permitido".
- **Todo o nada** en la etapa 3 es muy duro para quien recién aprende. Podría reservarse para las etapas 9 en adelante.
- **Sin racha** casi no cambia cómo se mueve el jugador. Podría pasar de "no sube" a algo con decisión: por ejemplo, "la racha vale el doble pero se corta con cualquier retroceso".

## Las que se retiraron con la torre vieja (fuente de ideas)

Niebla, Oscuridad, Prisa, Hielo total, Quebradizo, Polvorín y Lluvia de meteoritos. Dependían de reglas de la torre anterior, pero varias de las ideas siguen siendo buenas y se retoman abajo adaptadas a la torre actual.

## Qué hace buena a una prueba

Criterios para elegir entre las ideas de abajo:

1. **Se entiende en una frase** y se ve en cuanto empieza la torre.
2. **Cambia cómo piensas, no solo cuánto dura.** Mejor una regla que obligue a planear distinto que un número más chico.
3. **Es justa:** si fallas, fue por decisión tuya y no por azar puro.
4. **Se nota en la pantalla,** no es solo un cartel.
5. **A veces es un trato y no un castigo:** algunas pruebas dan algo a cambio de un riesgo (como los jefes de Balatro que también ofrecen ventajas).
6. **Entra en distintos momentos del run:** las suaves arriba (etapas 3 y 6), las serias en el medio (9 y 12) y una especial para el final (15).

## Ideas nuevas (conceptuales)

Para cada una: qué cambia, por qué sería divertida y el cuidado que pide.

### Ver y recordar

**Memoria de pez.** Al entrar a una sala la ves entera unos segundos y después los bloques lejanos se ocultan: solo se ven los de alrededor.
*Divertida porque* te obliga a memorizar y planear de antemano, y sale muy bien si la sala se puede resolver "de memoria".
*Ojo:* que los segundos de vista alcancen para entender la sala.

**A oscuras.** Farolín se apaga y solo se ve en un círculo alrededor del personaje. El resto es negro, salvo los checkpoints dorados.
*Divertida porque* convierte la torre en exploración, con Farolín como personaje central.
*Ojo:* que no moleste en las salas altas (se puede ver el nivel de arriba apenas).

### Esfuerzo y movimientos

**Espalda mala.** Empujar o tirar de un bloque cuesta **dos** movimientos en lugar de uno.
*Divertida porque* cada empujón se vuelve una decisión cara, y los atajos que ahorran empujar valen oro.
*Ojo:* que el margen de movimientos acompañe (la sala debe seguir siendo resoluble).

**Solo tres bloques.** En cada sala solo se pueden mover **tres bloques distintos**: el cuarto queda trabado. (Es la métrica de "bloques distintos movidos" que ya mide la dificultad.)
*Divertida porque* es un puzzle dentro del puzzle: elegir cuáles tres bloques mover.
*Ojo:* que el jugador sepa cuántos le quedan (un contador).

**Presupuesto compartido.** Los movimientos de toda la torre son un solo fondo: lo que sobra en una sala pasa a la siguiente, y lo que falta se toma de lo que queda.
*Divertida porque* permite apostar: gastar de más en una sala difícil y ahorrar en las fáciles.
*Ojo:* mostrar bien el fondo restante.

**Quebradizo.** Cada bloque que pisas **se rompe** al bajarte, como un agrietado: una sola pisada por bloque en toda la sala. (Es la vieja "Quebradizo", adaptada.)
*Divertida porque* convierte la sala en un camino de un solo sentido y obliga a leer la ruta completa.
*Ojo:* hay que chequear que cada sala siga teniendo solución.

### El mundo se mueve

**Lluvia de meteoritos.** Cada cierta cantidad de movimientos, una **sombra** marca una celda de la sala: un movimiento después cae un meteorito y destruye el bloque que haya ahí.
*Divertida porque* el peligro es visible y se puede esquivar, y a veces el meteorito abre un camino nuevo.
*Ojo:* la sombra tiene que verse con tiempo.

**Mareo.** La cámara **gira 90 grados** cada cinco movimientos, y los controles siguen siendo relativos a la cámara.
*Divertida porque* es caos puro y muy gracioso: hay que reorientarse todo el tiempo.
*Ojo:* mejor para el principio del run, donde molesta menos; el cartel debe avisar cuándo gira.

**Terremoto.** Cada ocho movimientos tiembla la pantalla y un bloque suelto de la sala se corre una celda (se avisa con el temblor).
*Divertida porque* la sala "respira" y hay que adaptar el plan.
*Ojo:* que no cambie el bloque donde estás parado.

### Bloques cambiados

**Hielo total.** Todos los bloques de la sala son de hielo: cualquier paso resbala. (La vieja "Hielo total".)
*Divertida porque* es un puzzle de patinaje completamente distinto, y casi un mini-juego.
*Ojo:* hay que cuidar que no se salga de la huella a cada paso.

**Pegamento.** Los bloques que se tocan quedan **unidos**: se empujan y tiran juntos.
*Divertida porque* cambia la física de toda la torre y los bloques se vuelven piezas grandes.
*Ojo:* que siga habiendo solución sin frustrar.

**Polvorín.** Cada sala trae una bomba extra con una cuenta bastante larga. (La vieja "Polvorín".)
*Divertida porque* mete presión sin cambiar las reglas básicas.
*Ojo:* que la bomba nunca bloquee la única salida.

**Plomo.** Todos los bloques son pesados: se trepan, pero no se empujan. Solo se mueven unos pocos, marcados con un color.
*Divertida porque* convierte la sala en un laberinto con muy pocas piezas móviles.
*Ojo:* hace falta marcar bien cuáles se mueven.

### Riesgo y recompensa (tratos)

**Apuesta de Farolín.** Antes de la torre Farolín te ofrece un multiplicador de claridad (×1,5, ×2 o ×3) a cambio de menos vidas para esa torre (3, 2 o 1).
*Divertida porque* el jugador decide cuánto arriesga, como en una mano de blackjack.
*Ojo:* mostrar claro el trato.

**La claridad no se asegura.** En esta torre los checkpoints no guardan la claridad: se cobra toda al final, pero si caes **se pierde toda** la de esa torre.
*Divertida porque* cada sala es una decisión de seguir o conformarse.
*Ojo:* se parece a Todo o nada, así que conviene que no salgan seguidas.

**Corrupción que vuelve.** Los bloques ya purificados se **corrompen de nuevo** cada diez movimientos: hay que volver a pisarlos para cobrar su claridad.
*Divertida porque* toca el corazón del juego (purificar) y premia las rutas que recorren mucho.
*Ojo:* que el aviso sea claro y no confunda con la racha.

### Casino y contratos

**Casino torcido.** En esta etapa solo está abierta **una mesa**, sorteada: ruleta, tragamonedas o blackjack. Las demás tienen el cartel de cerrado.
*Divertida porque* obliga a adaptar la estrategia económica y a descubrir juegos que se habían descuidado.
*Ojo:* en el salón y la taberna casi no hay mesas, así que habría que probarlo con el casino más grande.

**Encargo de Farolín.** Farolín te **obliga** a aceptar un contrato especial, sin fianza y con una recompensa grande. Cumplirlo regala un boost; fallarlo cuesta claridad.
*Divertida porque* mezcla las pruebas con los contratos y le da personalidad a Farolín.
*Ojo:* que el encargo sea siempre posible en esa torre.

**Peaje por adelantado.** Farolín cobra el peaje **antes** de la torre (si no puedes pagarlo, no se entra); si superas la torre te devuelve la mitad.
*Divertida porque* cambia el ritmo: el dinero se piensa antes de jugar, no después.
*Ojo:* en las etapas con peaje alto puede cortar la partida; hay que ajustar bien los números.

### Con personajes

**El gatito travieso.** Al entrar a cada sala, un gatito mueve **un bloque común** de lugar (una celda, siempre sin romper la solución).
*Divertida porque* es un toque de humor y cada sala se parece a la anterior pero no igual.
*Ojo:* hay que verificar que la sala siga siendo resoluble.

**Sombra.** Una **sombra** te sigue una celda atrás y copia tus pasos con retraso: puede pisar bloques antes que tú o trabarte el camino.
*Divertida porque* es un compañero molesto que hay que usar a favor.
*Ojo:* necesita reglas claras de qué pasa cuando se cruzan.

### Para el final (etapa 15)

**La Pesadilla despierta.** La última torre combina dos reglas de las de arriba (por ejemplo, Mareo y Lluvia de meteoritos) y paga el máximo (×2,7 más un boost épico).
*Divertida porque* es el "jefe final" de la partida: un examen de todo lo que se aprendió.
*Ojo:* que las dos reglas se lleven bien entre sí.

## Cómo seguir

1. Marcar cuáles te gustan, cuáles cambiar y cuáles descartar.
2. Decidir cuántas pruebas habría en total y si cada escenario tiene su propio grupo (hoy es un grupo de tres que cada escenario recorta).
3. Ordenarlas por etapa: cuáles pueden caer en la 3 y en la 6, cuáles solo de la 9 en adelante y cuáles son del final.
4. Recién después, pensar cómo se construyen.
