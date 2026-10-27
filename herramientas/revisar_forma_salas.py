"""Revisa la FORMA de las salas de una biblioteca (jsonl): bloques dentro de la huella, entrada y salida externas y opuestas, niveles de entrada y de salida limpios.
Uso: python herramientas/revisar_forma_salas.py archivo.jsonl"""
import json, sys
HUELLA = {'3x3': (0, 0, 3, 3), '5x3': (3, 0, 5, 3), '8x3': (0, 0, 8, 3)}
malas = 0
n = 0
for linea in open(sys.argv[1], encoding='utf-8'):
    if not linea.strip():
        continue
    d = json.loads(linea)
    n += 1
    x0, z0, w, dd = HUELLA[d['tipo']]
    h = d['meta']
    motivos = []
    ent = [b for b in d['bloques'] if b[3] == 'p']
    sal = [b for b in d['bloques'] if b[3] == 'f']
    if len(ent) != 1 or ent[0][1] != 1:
        motivos.append('la entrada no es un checkpoint único en el nivel 1')
    if len(sal) != 1 or sal[0][1] != h:
        motivos.append('la salida no es un único bloque fijo en el nivel meta')
    for b in d['bloques']:
        if not (x0 <= b[0] < x0 + w and z0 <= b[2] < z0 + dd):
            motivos.append('bloque fuera de la huella %s' % b); break
    otros1 = [b for b in d['bloques'] if b[1] == 1 and b[3] != 'p']
    otrosh = [b for b in d['bloques'] if b[1] == h and b[3] != 'f']
    if otros1: motivos.append('hay bloques extra en el nivel de entrada')
    if otrosh: motivos.append('hay bloques extra en el nivel de salida')
    if len(ent) == 1 and len(sal) == 1:
        ex, ez = ent[0][0] - x0, ent[0][2] - z0
        sx, sz = sal[0][0] - x0, sal[0][2] - z0
        borde = lambda x, z: x in (0, w - 1) or z in (0, dd - 1)
        if not borde(ex, ez) or not borde(sx, sz): motivos.append('entrada o salida no externas')
        if d['tipo'] in ('5x3', '8x3') and not d.get('giro'):   # (las salas con giro tienen la salida a 90 grados de la entrada)
            if abs(ex - sx) != w - 1: motivos.append('entrada y salida no están en puntas contrarias')
        elif d['tipo'] == '3x3' and abs(ex - sx) + abs(ez - sz) < 3: motivos.append('entrada y salida demasiado cerca')
    if motivos:
        malas += 1
        print('MAL sala %d (%s): %s' % (n, d['tipo'], '; '.join(motivos)))
print('salas: %d, con problemas de forma: %d' % (n, malas))
