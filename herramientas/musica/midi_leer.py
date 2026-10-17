"""Lector mínimo de archivos MIDI (formato 0 y 1) sin dependencias: devuelve las notas {inicio_en_segundos, duracion, nota, velocidad, pista, canal} y el nombre de cada pista,
respetando los cambios de tempo. Lo usa render_estaciones.py para pasar las partituras de dominio público (Mutopia Project) al sintetizador chiptune del juego."""
import struct


def _vlq(data, i):
    v = 0
    while True:
        b = data[i]
        i += 1
        v = (v << 7) | (b & 0x7F)
        if not b & 0x80:
            return v, i


def leer(path):
    data = open(path, 'rb').read()
    assert data[:4] == b'MThd'
    fmt, ntracks, division = struct.unpack('>HHH', data[8:14])
    assert not division & 0x8000, 'tiempos SMPTE no soportados'
    i = 14
    tracks = []
    tempos = []   # (tick, microsegundos por negra)
    for _ in range(ntracks):
        assert data[i:i + 4] == b'MTrk'
        n = struct.unpack('>I', data[i + 4:i + 8])[0]
        body = data[i + 8:i + 8 + n]
        i += 8 + n
        tracks.append(body)
    raw = []   # (tick, tipo, canal, a, b, pista)
    names = []
    programs = {}
    for ti, body in enumerate(tracks):
        j = 0
        tick = 0
        status = 0
        name = ''
        while j < len(body):
            d, j = _vlq(body, j)
            tick += d
            b = body[j]
            if b == 0xFF:
                typ = body[j + 1]
                ln, k = _vlq(body, j + 2)
                payload = body[k:k + ln]
                j = k + ln
                if typ == 0x03 and not name:
                    name = payload.decode('latin-1')
                elif typ == 0x51 and ln == 3:
                    tempos.append((tick, int.from_bytes(payload, 'big')))
                continue
            if b in (0xF0, 0xF7):
                ln, k = _vlq(body, j + 1)
                j = k + ln
                continue
            if b & 0x80:
                status = b
                j += 1
            typ = status & 0xF0
            ch = status & 0x0F
            if typ in (0x80, 0x90, 0xA0, 0xB0, 0xE0):
                a, bb = body[j], body[j + 1]
                j += 2
                if typ == 0x90 and bb > 0:
                    raw.append((tick, 'on', ch, a, bb, ti))
                elif typ == 0x80 or typ == 0x90:
                    raw.append((tick, 'off', ch, a, 0, ti))
            elif typ in (0xC0, 0xD0):
                if typ == 0xC0:
                    programs[(ti, ch)] = body[j]
                j += 1
        names.append(name)
    tempos.sort()
    if not tempos or tempos[0][0] != 0:
        tempos.insert(0, (0, 500000))

    def seconds(tick):
        t = 0.0
        last_tick, tempo = 0, tempos[0][1]
        for tk, tp in tempos:
            if tk >= tick:
                break
            t += (tk - last_tick) * tempo / division / 1e6
            last_tick, tempo = tk, tp
        return t + (tick - last_tick) * tempo / division / 1e6

    raw.sort(key=lambda e: (e[0], 0 if e[1] == 'off' else 1))
    open_notes = {}
    notes = []
    for tick, typ, ch, a, v, ti in raw:
        key = (ti, ch, a)
        if typ == 'on':
            open_notes.setdefault(key, []).append((tick, v))
        elif open_notes.get(key):
            t0, vel = open_notes[key].pop(0)
            s0, s1 = seconds(t0), seconds(tick)
            notes.append({'t': s0, 'd': max(0.02, s1 - s0), 'n': a, 'v': vel, 'pista': ti, 'canal': ch})
    notes.sort(key=lambda x: (x['t'], x['n']))
    return {'notas': notes, 'pistas': names, 'programas': programs, 'division': division, 'tempos': tempos}


if __name__ == '__main__':
    import sys
    for p in sys.argv[1:]:
        m = leer(p)
        por = {}
        for n in m['notas']:
            por.setdefault(n['pista'], []).append(n)
        dur = max((n['t'] + n['d'] for n in m['notas']), default=0)
        print(p, '%d notas, %.0f s, %d tempos' % (len(m['notas']), dur, len(m['tempos'])))
        for ti, ns in sorted(por.items()):
            print('   pista %d «%s»: %d notas, rango %d-%d, primera a %.1fs, última %.1fs' % (ti, m['pistas'][ti], len(ns), min(x['n'] for x in ns), max(x['n'] for x in ns), ns[0]['t'], ns[-1]['t'] + ns[-1]['d']))
