# Cómo se construyó el juego

Resumen del método de trabajo y de las decisiones de rumbo. Lo que el juego hace hoy está en [diseno.md](diseno.md).

## Método

1. **Diseño primero.** Los sistemas grandes se escriben y se conversan antes de programarlos: [diseno.md](diseno.md), [reglas_torre.md](reglas_torre.md), [economia.md](economia.md) y [plan_casinos.md](plan_casinos.md).
2. **Cada sistema, con sus pruebas.** Las pruebas corren sin pantalla y el conjunto completo termina en `fallos: 0`.
3. **La dificultad se juzga jugando.** Las métricas ayudan, pero se miran capturas y se juega la torre. La medida que importa es la cantidad de bloques distintos movidos, no la de movimientos.
4. **Se descarta lo que no da buenos puzzles.** Lo aprendido de cada experimento queda en [aprendizajes.md](aprendizajes.md) y el código viejo se borra del repositorio.
5. **Una rama por cambio.** Se sube en cada hito y se une a `main` al terminar.

## Decisiones de rumbo

- **La torre pasó por varias versiones:** núcleo sólido con piso y fila que cae, torre cilíndrica y escenario de hielo. Se retiraron las que no daban buenos puzzles y quedó la torre actual, de salas apiladas.
- **Salas verificadas.** Un solucionador exacto en C++ comprueba cada sala y fija su tope de movimientos. Ver [generador.md](generador.md) y [solver_extension.md](solver_extension.md).
- **Limpieza en seis fases.** Se ordenó el repositorio en carpetas por tema, se borró lo muerto y se dejaron reglas para no volver a ensuciarlo.
- **Economía con un bot.** Un bot juega partidas completas para calibrar el peaje, las fichas y la tienda. Como es casi perfecto, el ajuste fino se hace con jugadores reales. Ver [bot.md](bot.md).

## Ronda de testers

Un grupo de testers jugó una versión y devolvió una lista de más de treinta puntos: economía difícil de alcanzar, tutorial confuso, falta de modo daltonismo, jerga y riesgo de perder partidas. Cada punto se priorizó y se resolvió o se descartó con motivo.

Lo resuelto después incluye: guardado a prueba de cortes, ajustes gráficos automáticos, tutorial reescrito, texto más legible, daltonismo completo y una pasada de pruebas sobre la versión final.
