#!/bin/bash
# Corre todas las pruebas (tests/test_*.gd) una por una y resume. Uso: bash tests/correr_todos.sh [patrón] (por ejemplo: bash tests/correr_todos.sh casino)
# Cada prueba termina con "fallos: N"; el código de salida es 1 si alguna falla o se pasa del tiempo (TIEMPO, en segundos, 900 por omisión).
# Las pruebas de generación y de runs completos tardan varios minutos; todo el conjunto, más de una hora. Resultados también en tests/resultados.txt (no se versiona).
cd "$(dirname "$0")/.."
GODOT="tools/Godot_v4.7.2-stable_win64_console.exe"
TIEMPO=${TIEMPO:-900}
export GAME_SANDBOX=1
export SN_LIB=${SN_LIB:-data/salas_torre.jsonl}   # (las pruebas de la biblioteca de salas necesitan saber cuál mirar)
SALIDA=tests/resultados.txt
: > "$SALIDA"
malas=0
for f in tests/test_*.gd; do
  n=$(basename "$f" .gd)
  if [ -n "$1" ] && [[ "$n" != *"$1"* ]]; then continue; fi
  r=$(timeout "$TIEMPO" "$GODOT" --headless --path . -s "$f" 2>&1)
  codigo=$?
  fall=$(echo "$r" | grep -oE "fallos: [0-9]+" | tail -1)
  malos=$(echo "$r" | grep -E "^(FAIL|FALLA)|SCRIPT ERROR" | head -3 | tr '\n' ' ')
  if [ "$codigo" = "124" ]; then estado="TIEMPO"; malas=$((malas+1))
  elif [ "$fall" = "fallos: 0" ]; then estado="ok"
  else estado="FALLA"; malas=$((malas+1)); fi
  echo "$estado | $n | $fall | $malos" | tee -a "$SALIDA"
done
echo "pruebas con problemas: $malas" | tee -a "$SALIDA"
[ "$malas" = "0" ]
