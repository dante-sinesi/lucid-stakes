# Bloques y mecánicas de la torre

Una etapa es una torre de 25 pisos (27 etapas por partida). Se camina, se empuja o tira de bloques (Shift) y se cuelga de los bordes (Espacio). La fila de abajo cae cada N movimientos. Estos son los tipos de bloque; se introducen de a uno a medida que sube la dificultad (0 a 1 a lo largo de las 27 etapas).

## normal
- descripción: Bloque común: se pisa, se empuja y se tira.
- aparece: siempre

## hielo
- descripción: Hace resbalar: se desliza hasta que algo lo frena.
- aparece: desde dificultad 0,05

## pesado
- descripción: No se puede empujar ni tirar (hace falta la habilidad Fuerza bruta).
- aparece: desde dificultad 0.15

## agrietado
- descripción: Se rompe al bajarte de él.
- aparece: desde dificultad 0.25

## bomba
- descripción: Tiene una cuenta: baja con cada movimiento mientras estás a su altura; al llegar a 0 explota. Pisarla la desactiva.
- aparece: desde dificultad 0,4

## trampa
- descripción: Celda de plataforma que se desarma al pisarla.
- aparece: desde dificultad 0.3

## pinchos
- descripción: No se puede pisar.
- aparece: desde dificultad 0.35

## catapulta
- descripción: Sube 4 en vertical y busca un borde de donde agarrarse (hasta 2 más arriba). No se genera en las torres: sólo sale con consumibles y en el laboratorio.
- aparece: no se genera

# Ritmos de caída de la fila de abajo

## fast
- margen_de_caída: 0.55
- corrimiento_de_banda: -1

## normal
- margen_de_caída: 1.0
- corrimiento_de_banda: 0

## slow
- margen_de_caída: 1.25
- corrimiento_de_banda: 2
