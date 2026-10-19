#!/bin/bash
# Tanda del Glaciar de una hora: varios procesos de tools/generador.exe en modo hielo, se cortan a los 60 minutos, se cierra con las reglas del juego y se arma el reporte.
# Uso: bash herramientas/glaciar_1h.sh [minutos=60] [procesos=6]
cd "$(dirname "$0")/.."
MIN=${1:-60}
N=${2:-6}
OUT=bibliotecas/glaciar_1h
mkdir -p "$OUT"
rm -f "$OUT"/gen_*.txt "$OUT"/gen_*.log
date +%s > "$OUT/inicio.txt"
for ((i=0; i<N; i++)); do
	tools/generador.exe mina --out="$OUT/gen_$i.txt" --steps=1000000 --hlo=5 --hhi=11 --seed=101 --part=$i --parts=$N \
		--types=i,h,c,s --p-ice=0.7 --p-type=0.6 --min-ice=1 --min-slides=2 --nodes=300000 --eval=14 2> "$OUT/gen_$i.log" &
done
sleep $((MIN * 60))
taskkill //F //IM generador.exe > /dev/null 2>&1
sleep 5
date +%s > "$OUT/fin.txt"
export GAME_SANDBOX=1
tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . res://scenes/generador.tscn -- --in="$OUT" --old=bibliotecas/no_hay --lib="$OUT/no_hay.rooms" --out="$OUT/glaciar.rooms" --min-reach=0.5 > "$OUT/cierre.log" 2>&1
tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/reporte_glaciar.gd -- "$OUT/glaciar.rooms" "$OUT/reporte.txt" > /dev/null 2>&1
echo FIN > "$OUT/listo.txt"
