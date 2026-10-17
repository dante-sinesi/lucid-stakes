extends RefCounted
## Bandera para cortar enseguida los cálculos largos de la generación de torres (solucionador, métricas, colocación de salas) cuando se cancela
## el trabajo: abandonar el run, volver al menú, etc. La pone `main._cancel_jobs` y la mira todo lo que tarda; así los hilos terminan en
## milisegundos y el juego no se cuelga esperándolos. Vive en su propio archivo para que lo puedan usar todos sin referencias circulares.

static var flag := false
