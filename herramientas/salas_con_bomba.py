"""Separa de la biblioteca del juego (data/salas_torre.jsonl) las salas con bombas, para verlas en el Estudio de salas:
bibliotecas/salas_bomba.jsonl (todas las salas con bomba) y bibliotecas/salas_bomba_arriba.jsonl (las que tienen un bloque justo arriba de una bomba).
Uso: python herramientas/salas_con_bomba.py"""
import json, os
RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
con_bomba, con_arriba = [], []
for l in open(os.path.join(RAIZ, 'data', 'salas_torre.jsonl'), encoding='utf-8'):
    if not l.strip():
        continue
    d = json.loads(l)
    celdas = {(b[0], b[1], b[2]): b[3] for b in d['bloques']}
    bombas = [p for p, t in celdas.items() if t.startswith('b') and len(t) > 1]
    if bombas:
        con_bomba.append(l)
        if any((p[0], p[1] + 1, p[2]) in celdas for p in bombas):
            con_arriba.append(l)
os.makedirs(os.path.join(RAIZ, 'bibliotecas'), exist_ok=True)
for nombre, lista in (('salas_bomba.jsonl', con_bomba), ('salas_bomba_arriba.jsonl', con_arriba)):
    with open(os.path.join(RAIZ, 'bibliotecas', nombre), 'w', encoding='utf-8', newline='\n') as f:
        f.write(''.join(x if x.endswith('\n') else x + '\n' for x in lista))
print('salas con bomba: %d, con un bloque justo arriba de una bomba: %d' % (len(con_bomba), len(con_arriba)))
