extends RefCounted
## Los tipos de bloque del juego (los de las salas de la torre se escriben con una letra: ver motor.gd) y lo que comparten las pantallas que los muestran.

enum Kind { NORMAL, ICE, BOMB, CATAPULT, CRACKED, HEAVY, TRAP, SPIKES }

## La zona de una bomba: celdas a distancia (al cuadrado) de 5 o menos de ella.
const BOMBA_R2 := 5

## La letra de un bloque de las salas -> su tipo.
const DE_LETRA := {"n": Kind.NORMAL, "p": Kind.NORMAL, "f": Kind.NORMAL, "h": Kind.HEAVY, "i": Kind.ICE, "c": Kind.CRACKED, "t": Kind.TRAP, "s": Kind.SPIKES, "k": Kind.CATAPULT, "b": Kind.BOMB, "d": Kind.BOMB}
