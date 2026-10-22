#!/bin/bash
# Tanda de salas con especiales: por cada rol, tres pasadas según el nivel de la sala base (fácil/media, difícil, pesadilla), y se juntan en bibliotecas/salas_especiales_<rol>.jsonl
cd "$(dirname "$0")/.."
for rol in pinchos; do
  for paso in "A facil,media 16" "B dificil 14" "C pesadilla 10"; do
    set -- $paso
    timeout 2700 python herramientas/especializar_biblioteca.py rol=$rol niveles=$2 objetivo=$3 hilos=7 tope=100000 salida=bibliotecas/sn_especiales_${rol}_$1.jsonl 2>&1 | tail -1
  done
  cat bibliotecas/sn_especiales_${rol}_*.jsonl > bibliotecas/salas_especiales_${rol}.jsonl
  echo "== $rol: $(wc -l < bibliotecas/salas_especiales_${rol}.jsonl) salas"
done
echo "TANDA TERMINADA"
