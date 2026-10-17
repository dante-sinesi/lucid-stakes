# Revisión de diálogos (propuesta para aprobar)

Estado: **propuesta**. Nada de esto está aplicado todavía, salvo el arreglo de Opciones. El cuadro del tabernero entra con **4 renglones**: hoy sólo se pasan 5 líneas del cierre del tutorial (la del azar y, en inglés, las de Farolín, la vitrina y la Luz). `tests/audit_dialogos.gd` mide todos los diálogos (historia, tabernero de los casinos con cada regla y prueba, Farolín, avisos de bloques) en español e inglés. `tests/audit_texto.gd` busca textos que se salen de la ventana en las pantallas del menú.

## Criterios
1. **Voseo en todo.** Hoy el tutorial usa tuteo ("Pase", "Ve hasta allí", "debes", "puedes") y los casinos voseo ("Sentate", "Pagás"). El tabernero es el mismo personaje.
2. **Cada lección dice qué hacer.** Hoy el tabernero sólo dice lore y la acción queda en la ayuda de teclas de arriba.
3. **Cortos.** Un máximo de 3 renglones por línea.
4. **Farolín se ve y habla.** Aparece en el salón de piedra y tiene su propia voz.

## Introducción (taberna)
| Ahora | Propuesta |
|---|---|
| Pase, soñador. Qué cara... ¿es tu primera vez aquí? | Pasá, soñador. Qué cara... ¿es tu primera vez por acá? |
| Este no es el mundo de los despiertos. Es una pesadilla, tu pesadilla, hecha con tus propios recuerdos, y los recuerdos se corrompen. | Esto no es el mundo de los despiertos: es una pesadilla, la tuya, hecha con tus propios recuerdos. Y los recuerdos se corrompen. |
| (claridad) Si estás acá es porque te queda algo de esto: la claridad, lo que queda de tus recuerdos que aún no están corruptos. | (claridad) Si llegaste hasta acá es porque te queda algo: claridad, lo que todavía no se corrompió de tus recuerdos. |
| Salir de aquí no es fácil. Si no, mirame: no estaría aquí, atendiendo una taberna, atendiendo a los soñadores perdidos. | Salir no es fácil. Si lo fuera, yo no estaría atendiendo una taberna para soñadores perdidos. |
| ¿Que cómo se sale? Dando claridad a tu pesadilla, y creeme, no es fácil. | ¿Cómo se sale? Devolviéndole claridad a tu pesadilla, torre por torre. Y no, no es fácil. |
| ¿Ves ese portal de atrás, el que brilla? Ve hasta allí y crúzalo, que te enseñaré cómo abandonar este lugar. | ¿Ves ese portal del fondo, el que brilla? Cruzalo y te enseño cómo se anda por acá. |

## Lecciones (lo que dice el tabernero)
| Lección | Ahora | Propuesta (lore + qué hacer) |
|---|---|---|
| Moverse | Si bien los recuerdos pueden ser corrompidos, al parecer no olvidaste cómo caminar, pero repasemos. | Los recuerdos se corrompen, pero caminar no se olvida. Llegá hasta el bloque dorado. |
| Cámara | A veces es mejor ver las cosas desde otro ángulo. Prueba verte desde otro punto de vista. | Algunas cosas se entienden mejor desde otro ángulo. Girá la vista. |
| Empujar | A veces caminar no es suficiente, así que debes alterar tu contexto para seguir adelante. | Si el camino no alcanza, hay que moverlo. Empujá el bloque de enfrente: va a ser tu primer escalón. |
| Tirar | Si te arrepientes de cómo alteraste el contexto, siempre puedes devolver las cosas a como estaban... o eso creo. | Y si un bloque te estorba, también se arrastra: caminá alejándote de él y se viene con vos. Después da la vuelta y subí. |
| Cornisa | A veces caminar no es la mejor solución para salir adelante. ¡Pero siempre se puede tomar un atajo! | Un borde no siempre es el final: agarrate de él y rodealo. |
| Soltarse | A veces uno ve el precipicio y... tiene que saltar. | A veces uno ve el precipicio y... tiene que saltar. Colgate del borde y soltate. |
| Torre | Una torre de verdad se ve así. Tienes que andar con cuidado, porque si caminas mucho, el suelo comienza a caer. ¿Por qué no intentas superar esta? | Esta ya es una torre de verdad. Ojo: si caminás mucho, el suelo empieza a caer. ¿Te animás? |

## Dados
| Ahora | Propuesta |
|---|---|
| ¡Qué habilidad motriz tienes! Ahora probemos tu suerte en el azar. | ¡Qué agilidad, soñador! Ahora probemos tu suerte. |
| Tienes 5 dados. Antes de tirarlos, puedes elegir el número que saldrá en cada uno. Después se tiran, y los que aciertes se quedan; se puede tirar hasta 3 veces los dados. | Tenés 5 dados. Elegí el número que esperás en cada uno y tiralos: los que aciertan se quedan. Podés tirar hasta 3 veces. |
| (luz) Con dos aciertos, ganas algo de claridad. Con tres, algo más de claridad y una luz. Con cuatro, aún más claridad, y dos luces. | (luz) Con dos aciertos ganás claridad. Con tres, más claridad y una luz. Con cuatro, todavía más y dos luces. |
| Pero con cinco... Hay un premio enorme, con cinco luces... ¡Y un cosmético! | Pero con cinco... cinco luces y un cosmético. Un premio enorme. |

## Cierre en el salón de piedra (se reescribe entero, con Farolín en escena)
| Ahora | Propuesta |
|---|---|
| ¡Lo lograste, soñador! Ya sabes moverte, empujar, tirar, colgarte y tirarte al precipicio. Con eso podrás subir cualquier torre. O al menos eso fue necesario para que yo llegue aquí. | ¡Lo lograste, soñador! Ya sabés moverte, empujar, tirar, colgarte y soltarte. Con eso se sube cualquier torre. Al menos a mí me alcanzó. |
| Este salón es más claro y espacioso que mi taberna, ¿no crees? | Este salón es más claro que mi taberna, ¿viste? |
| Cada vez que superes una torre, tendrás más claridad, lo que hará que todo lo que recuerdes sea más luminoso y pintoresco. ¡Como este salón y yo! | Cada torre que superes te da más claridad, y todo lo que recordás se vuelve más luminoso. |
| Al parecer, en tus sueños te gusta jugar con azar, así que, ¿por qué no? Conmigo podrás jugar a la ruleta, y si ganas te daré consumibles o habilidades... | **(se saca "te gusta el azar")** Acá podés jugar a la ruleta: si ganás, te doy consumibles o habilidades para las próximas torres. |
| ¡Y mira si te estoy haciendo un favor! Solo voy a cobrarte claridad. ¡Sí, la misma que consigues superando la torre! | Y sólo te cobro claridad: la misma que sacás de las torres. |
| Ah, y no te olvides de quien cuida la puerta de salida: Farolín. Es un farol con patas, y te cobra claridad por cada torre... | **(aparece Farolín junto a la puerta)** Y mirá quién está en la puerta: Farolín. |
| *(no existe)* | **Nuevo, lore:** Fue un soñador como vos. Se quedó cuidando la salida y, de tanto alumbrarla, terminó convertido en farol. |
| *(no existe)* | **Nuevo:** Su luz te muestra el camino a la próxima torre, y esa luz se paga con claridad. Sin luz nadie encuentra la puerta. |
| Si no te alcanza, Farolín te ofrece volver a subir la torre, y eso te cuesta una vida: morir en la torre ya no te quita claridad, te quita una vida. Si no te quedan vidas, o pagás o dejás que todo se apague. | Si no te alcanza, te deja volver a subir la torre, pero eso cuesta una vida. Sin vidas, o pagás o todo se apaga. |
| *(no existe)* | **Nuevo, peaje de práctica:** Farolín habla con su voz y su cuadro, y el jugador paga de verdad con claridad de regalo (no se puede trabar). |
| Mi vitrina cambia en cada visita: ahí ves qué premios dan las fichas de la ruleta, y si no te gustan, la podés rotar pagando. En la tienda podés comprar directo lo que ya viste, aunque sale más caro que apostar. | Mi vitrina cambia en cada visita: ahí ves los premios de la ruleta, y podés rotarla pagando. En la tienda comprás directo lo que viste, pero sale más caro que apostar. |
| Lo que ganes —boosts, consumibles— se queda con vos y hace que juntes más claridad en cada torre. Y ojo: el precio de Farolín sube con cada etapa, así que más te vale crecer rápido. | Lo que ganes se queda con vos y te hace juntar más claridad por torre. Y ojo: Farolín cobra más en cada etapa, así que más te vale crecer rápido. |
| Cada tres torres, la pesadilla te pone a prueba, cambiando las reglas del juego. Ten cuidado con eso, nunca se sabe qué nuevo desafío puede aparecer... | Cada tres torres la pesadilla te pone a prueba y cambia las reglas. Nunca se sabe qué desafío viene. |
| Cuando superes todos los pisos de la pesadilla, conseguirás una habilidad especial, que se quedará contigo por siempre. ¡Sí, por siempre, aun si vuelves a tener una pesadilla! | Si superás todos los pisos, te llevás una habilidad para siempre, incluso si volvés a soñar. |
| (luz) Y una cosa más, esto que brilla también te lo deja la pesadilla según hasta dónde llegues. Con esto... no sé qué podrías hacer, pero se ve brillante, ¿no? | (luz) Y esto que brilla también te lo deja la pesadilla, según hasta dónde llegues. No sé para qué sirve, pero es lindo, ¿no? |
| Creo que eso es todo. Ahora ve, soñador. ¡A despertar! | Eso es todo. Ahora andá, soñador. ¡A despertar! |

## Farolín (en el juego)
Ahora: "Son N de claridad para seguir. ¿Pagás, o volvés a subir esta torre?" y las variantes sin claridad o sin vidas. Están bien de largo. Propuesta de **sumar**:
- Una línea al pagar ("Gracias, soñador. Te prendo el camino."), otra al rehacer ("Otra vez a subir. La luz no se va a ningún lado.") y otra al abandonar ("Entonces se apaga todo... Nos vemos en el próximo sueño.").
- Un saludo distinto la primera vez que se lo ve en un run.

## Avisos al descubrir un bloque (tabernero)
Están bien, pero repiten "Mirá, soñador:" y mezclan estilos. Propuesta: sacar los saludos repetidos y dejar sólo qué hace el bloque y qué hacer ("El hielo resbala: buscá algo que te frene antes de pisarlo"). Se mantienen todos (normal, hielo, hierro, agrietado, bomba, trampa, pinchos, catapulta).

## Sumar y restar
- **Sumar:** primer aviso de vidas (la primera vez que perdés una vida, Farolín explica cuántas quedan); aviso de la primera prueba cuando falta una torre; mensaje al terminar un run con victoria.
- **Restar:** la línea de "te gusta el azar" y la repetición de la claridad en el cierre (se dice dos veces).

## Textos que se salen del espacio
- **Opciones** (arreglado en esta rama): las notas bajo cada ajuste se parten en renglones y quedan alineadas a la izquierda; la nota de "Abrir la carpeta" ahora entra sin desplazar. `audit_texto.gd` da 0 textos fuera de la ventana en el menú, Opciones, Habilidades, Cosméticos y Créditos (español e inglés).
- **Diálogos:** sólo las 5 líneas del cierre mencionadas arriba se pasan de 4 renglones.
- Falta auditar el casino (ruleta, tienda, vitrina, servicios), la pantalla de fin de run y la de la demo, que necesitan una partida en curso para abrirse.
