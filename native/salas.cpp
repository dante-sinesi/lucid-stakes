// Motor y solucionador de la torre de salas sin núcleo en C++ (port de torre/motor.gd + reglas.gd + solucionador.gd).
// Uso: salas.exe < entrada.txt   (formato abajo)  ->  salida por stdout.
//
// Entrada (texto, una cosa por línea):
//   meta N                  (nivel del bloque checkpoint de la salida: se gana parado encima, en y = N + 1)
//   jugador X Y Z
//   colgado DX DY DZ        (opcional; 0 0 0 = de pie)
//   tope N                  (opcional: máximo de nodos, por defecto 1500000)
//   b X Y Z K               (un bloque; K = n común, p checkpoint, f fijo, h,i,c,t,s,k)
// Salida:
//   RESULT ok MOVES EXPANDIDOS NODOS AGARRES DISTINTOS
//   PATH dx dz modo ...     (modo 0 mover, 1 agarrar, 2 colgar)
//   o  RESULT fail EXPANDIDOS NODOS  /  RESULT budget ...
// Compilar: g++ -O2 -std=c++17 -static -o ../tools/cilindro.exe cilindro.cpp
#include <array>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <string>
#include <algorithm>
#include <unordered_map>
#include <unordered_set>
#include <random>
#include <cmath>
#include <iostream>
#include <sstream>

using namespace std;

static const int GX = 24, GZ = 24, GY = 48;   // x,z en -6..17 (se guarda x+6), y en 0..47
static const int NC = GX * GZ * GY;
static const int OFF = 6;

static inline int idx(int x, int y, int z) { return (y * GZ + (z + OFF)) * GX + (x + OFF); }
static inline int ix(int i) { return (i % GX) - OFF; }
static inline int iz(int i) { return ((i / GX) % GZ) - OFF; }
static inline int iy(int i) { return i / (GX * GZ); }
static inline bool dentro(int x, int y, int z) { return x >= -OFF && x < GX - OFF && z >= -OFF && z < GZ - OFF && y >= 0 && y < GY; }

enum Kind : uint8_t { NONE = 0, N = 1, F = 2, H = 3, I = 4, C = 5, T = 6, S = 7, K = 8, CP = 9, BD = 10 };
// Una bomba vive en la grilla como el valor 16 + su mecha (los movimientos que le quedan dentro de su zona); desactivada pasa a BD.
static const int BOMBA0 = 16, BOMBA_R2 = 5;   // la zona: celdas con dx² + dy² + dz² <= 5 (como en el juego)
static inline bool es_bomba(int k) { return k > BOMBA0; }
static inline bool en_zona(int bx, int by, int bz, int x, int y, int z) { int dx = x - bx, dy = y - by, dz = z - bz; return dx * dx + dy * dy + dz * dz <= BOMBA_R2; }
static Kind kind_de(char c) {
	switch (c) {
		case 'n': return N; case 'f': return F; case 'h': return H; case 'i': return I;
		case 'c': return C; case 't': return T; case 's': return S; case 'k': return K; case 'p': return CP;
	}
	return N;
}
// Un bloque del texto o del jsonl: una letra, y la bomba lleva su mecha pegada ("b7"); "d" es una bomba desactivada.
static int codigo_de(const string& k) {
	if (k.empty()) return N;
	if (k[0] == 'b') return BOMBA0 + max(1, k.size() > 1 ? atoi(k.c_str() + 1) : 5);
	if (k[0] == 'd') return BD;
	return kind_de(k[0]);
}

static const int LADO = 11;   // la torre: un anillo de 11 x 11 alrededor de un vacío de 5 x 5

struct V { int x, y, z; };
static const V DIRS[4] = {{1, 0, 0}, {-1, 0, 0}, {0, 0, 1}, {0, 0, -1}};
static vector<V> VECINOS;

static uint64_t ZOB[NC][16];
static uint64_t ZT[256];
static inline uint64_t zk(int i, int k) { return k < 16 ? ZOB[i][k] : ZOB[i][11] ^ ZT[k]; }
static uint64_t ZJ[NC], ZH[8];

static uint64_t splitmix(uint64_t v) {
	v += 0x9E3779B97F4A7C15ULL;
	v = (v ^ (v >> 30)) * 0xBF58476D1CE4E5B9ULL;
	v = (v ^ (v >> 27)) * 0x94D049BB133111EBULL;
	return v ^ (v >> 31);
}

static void init_tablas() {
	for (int i = 0; i < NC; i++) {
		for (int k = 0; k < 16; k++) ZOB[i][k] = splitmix((uint64_t)i * 16 + k + 1);
		ZJ[i] = splitmix((uint64_t)i * 77 + 12345);
	}
	for (int h = 0; h < 8; h++) ZH[h] = splitmix(999000 + h);
	for (int k = 0; k < 256; k++) ZT[k] = splitmix(555000 + k);
	for (int dy = -1; dy <= 1; dy++)
		for (int dz = -1; dz <= 1; dz++)
			for (int dx = -1; dx <= 1; dx++) {
				int n = (dx != 0) + (dy != 0) + (dz != 0);
				if (n == 1) VECINOS.push_back({dx, dy, dz});                 // caras
				else if (n == 2 && dy != 0) VECINOS.push_back({dx, dy, dz}); // aristas horizontales (diagonal en un plano vertical)
			}
}

struct Sim {
	uint8_t g[NC];
	int alto = 8;
	int px = 0, py = 1, pz = 0;
	int hx = 0, hy = 0, hz = 0;   // colgado (0 0 0 = de pie)
	bool perdido = false, ganado = false;
	bool track = false;
	vector<int16_t> ids;
	vector<pair<int, int>> mov_jugador;   // (desde, hasta) de los bloques que movió una acción del jugador
	int sig_id = 0;
	int lim = NC;   // sólo se recorren los niveles que pueden tener algo (hasta alto + 6)
	vector<uint8_t> ok_, quietos_;
	vector<int> cel;   // celdas ocupadas (sin orden): los recorridos son por los bloques y no por toda la grilla
	void fijar_alto(int a) { alto = a; lim = min(NC, (a + 6) * GZ * GX); }

	Sim() { memset(g, 0, sizeof(g)); }
	void limpiar() { memset(g, 0, lim); cel.clear(); }
	// Copia sólo los niveles que se usan (el resto es cero en las dos): mucho más barata que la copia entera.
	void copiar_de(const Sim& o) {
		alto = o.alto; lim = o.lim;
		px = o.px; py = o.py; pz = o.pz; hx = o.hx; hy = o.hy; hz = o.hz;
		perdido = o.perdido; ganado = o.ganado; track = false;
		mov_jugador.clear();
		memcpy(g, o.g, lim);
		cel = o.cel;
	}
	void reconstruir() { cel.clear(); for (int i = 0; i < lim; i++) if (g[i] != NONE) cel.push_back(i); }
	void agregar_cel(int i) { cel.push_back(i); }
	void sacar_cel(int i) { for (size_t k = 0; k < cel.size(); k++) if (cel[k] == i) { cel[k] = cel.back(); cel.pop_back(); return; } }
	bool hay(int x, int y, int z) const { return dentro(x, y, z) && g[idx(x, y, z)] != NONE; }
	Kind kind(int x, int y, int z) const { return dentro(x, y, z) ? (Kind)g[idx(x, y, z)] : NONE; }
	bool colgando() const { return hx != 0 || hy != 0 || hz != 0; }
	bool solido(int x, int y, int z) const { return hay(x, y, z); }   // (no hay suelo)
	bool en_limites(int x, int y, int z) const { return x >= -3 && x <= LADO + 2 && z >= -3 && z <= LADO + 2 && y >= 0 && y <= alto + 6; }
	bool en_huella(int x, int y, int z) const { return x >= 0 && x < LADO && z >= 0 && z < LADO && y >= 0; }
	bool alcance_cuelgue(int x, int y, int z) const { return x >= -4 && x <= LADO + 3 && z >= -4 && z <= LADO + 3 && y >= 0; }

	void poner(int x, int y, int z, Kind k) {
		if (!dentro(x, y, z)) return;
		int i0 = idx(x, y, z);
		if (g[i0] == NONE) agregar_cel(i0);
		g[i0] = k;
		if (track) { if (ids.empty()) ids.assign(NC, 0); ids[idx(x, y, z)] = sig_id++; }
	}
	void quitar(int x, int y, int z) { if (dentro(x, y, z)) { int i0 = idx(x, y, z); if (g[i0] != NONE) { g[i0] = NONE; sacar_cel(i0); } } }

	void mover_bloque(int fx, int fy, int fz, int tx, int ty, int tz, bool del_jugador) {
		int a = idx(fx, fy, fz);
		Kind k = (Kind)g[a];
		g[a] = NONE;
		sacar_cel(a);
		if (!dentro(tx, ty, tz)) { return; }   // se fue lejísimo: se pierde
		int b = idx(tx, ty, tz);
		g[b] = k;
		agregar_cel(b);
		if (track) ids[b] = ids[a];
		if (del_jugador) mov_jugador.push_back({a, b});
	}

	// --- sostén ---
	void anclados(vector<uint8_t>& ok) const {
		ok.assign(lim, 0);
		vector<int> cola;
		for (int i : cel) if (g[i] == F) { ok[i] = 1; cola.push_back(i); }
		while (!cola.empty()) {
			int c = cola.back(); cola.pop_back();
			int x = ix(c), y = iy(c), z = iz(c);
			for (auto& d : VECINOS) {
				int nx = x + d.x, ny = y + d.y, nz = z + d.z;
				if (!dentro(nx, ny, nz)) continue;
				int n = idx(nx, ny, nz);
				if (g[n] != NONE && !ok[n]) { ok[n] = 1; cola.push_back(n); }
			}
		}
	}
	void sostenidos(vector<uint8_t>& ok) const { anclados(ok); }   // (sin suelo: sólo se sostiene lo anclado)
	// Devuelve cuántos cayeron + cuántos se perdieron (>0 = hubo cambios)
	int asentar_bloques() {
		int cambios = 0;
		vector<uint8_t>& quietos = quietos_;
		quietos.assign(lim, 0);
		vector<uint8_t>& ok = ok_;
		for (int guardia = 0; guardia < 200; guardia++) {
			sostenidos(ok);
			int s = -1;
			int smin_y = 1000, smin_x = 1000, smin_z = 1000;
			for (int i : cel) {
				if (ok[i] || quietos[i]) continue;
				int y = iy(i), x = ix(i), z = iz(i);
				if (y < smin_y || (y == smin_y && (x < smin_x || (x == smin_x && z < smin_z)))) { smin_y = y; smin_x = x; smin_z = z; s = i; }
			}
			if (s < 0) break;
			int sx = ix(s), sy = iy(s), sz = iz(s);
			Kind tipo = (Kind)g[s];
			int16_t id = track ? ids[s] : (int16_t)0;
			g[s] = NONE;
			sacar_cel(s);
			int y = sy;
			bool aterrizo = false;
			while (y > 0) {
				y -= 1;
				if (sx == px && y == py && sz == pz) { aterrizo = true; y += 1; break; }
				int a = idx(sx, y, sz);
				if (g[a] != NONE && (ok[a] || quietos[a])) { aterrizo = true; y += 1; break; }
			}
			if (aterrizo && y >= 1) {
				int d = idx(sx, y, sz);
				g[d] = tipo;
				agregar_cel(d);
				if (track) ids[d] = id;
				if (y != sy) cambios++; else quietos[d] = 1;
			} else {
				cambios++;
			}
		}
		return cambios;
	}
	void asentar_jugador() {
		if (perdido) return;
		if (colgando()) {
			if (hay(px + hx, py + hy, pz + hz)) return;
			hx = hy = hz = 0;
		}
		while (!solido(px, py - 1, pz)) {
			if (py <= 1) { perdido = true; py -= 3; return; }
			py -= 1;
		}
	}
	void asentar() {
		for (int guardia = 0; guardia < 50; guardia++) {
			int c = asentar_bloques();
			int ax = px, ay = py, az = pz, bx = hx, by = hy, bz = hz;
			asentar_jugador();
			bool cambio = c > 0 || ax != px || ay != py || az != pz || bx != hx || by != hy || bz != hz;
			if (perdido || !cambio) return;
		}
	}
	void peligros() {
		for (int i = 0; i < 8; i++) {
			if (perdido || colgando()) return;
			Kind k = kind(px, py - 1, pz);
			if (es_bomba(k)) { g[idx(px, py - 1, pz)] = BD; return; }   // pararse encima la desactiva
			if (k == T) { quitar(px, py - 1, pz); asentar(); }
			else if (k == S) { perdido = true; return; }
			else return;
		}
	}

	// --- movimientos ---
	void resbalar(int dx, int dz) {
		for (int i = 0; i < 40; i++) {
			int tx = px + dx, tz = pz + dz;
			if (hay(tx, py, tz)) return;
			if (!en_huella(tx, py, tz)) { perdido = true; px = tx; py = max(py - 3, -3); pz = tz; return; }
			px = tx; pz = tz;
			if (kind(px, py - 1, pz) != I) return;
		}
	}
	void lanzar(int dx, int dz) {
		int oy = py;
		for (int i = 0; i < 4; i++) {
			if (!en_limites(px, py + 1, pz) || hay(px, py + 1, pz)) break;
			py += 1;
		}
		if (py == oy) return;
		int tope = py;
		for (int i = 0; i < 2; i++) {
			if (!en_limites(px, tope + 1, pz) || hay(px, tope + 1, pz)) break;
			tope += 1;
		}
		for (int y = tope; y > oy; y--) {
			int gd[4][2] = {{dx, dz}, {-dz, dx}, {dz, -dx}, {-dx, -dz}};
			for (auto& q : gd) {
				int gx = px + q[0], gz = pz + q[1];
				if (hay(gx, y, gz) && !hay(gx, y + 1, gz) && kind(gx, y, gz) != I) {
					py = y; hx = q[0]; hy = 0; hz = q[1];
					return;
				}
			}
		}
	}
	void llegar(int dx, int dz) {
		Kind k = kind(px, py - 1, pz);
		if (k == I) resbalar(dx, dz);
		else if (k == K) lanzar(dx, dz);
	}
	bool caminar(int dx, int dz) {
		int tx = px + dx, tz = pz + dz;
		if (!en_limites(tx, py, tz)) return false;
		if (hay(tx, py, tz)) {
			if (hay(tx, py + 1, tz) || hay(px, py + 1, pz)) return false;
			px = tx; py += 1; pz = tz; llegar(dx, dz); return true;
		}
		if (solido(tx, py - 1, tz)) { px = tx; pz = tz; llegar(dx, dz); return true; }
		if (solido(tx, py - 2, tz)) { px = tx; py -= 1; pz = tz; llegar(dx, dz); return true; }
		return false;
	}
	bool agarrar(int dx, int dz) {
		int tx = px + dx, tz = pz + dz;
		if (hay(tx, py, tz)) {
			Kind k = kind(tx, py, tz);
			if (k == F || k == H) return false;
			int dxx = tx + dx, dzz = tz + dz;
			if (hay(dxx, py, dzz)) {
				// fila de hasta 3
				int fila[4][2]; int n = 0;
				int cx = tx, cz = tz;
				while (hay(cx, py, cz)) {
					Kind kc = kind(cx, py, cz);
					if (kc == F || kc == H) return false;
					if (n >= 3) return false;
					fila[n][0] = cx; fila[n][1] = cz; n++;
					cx += dx; cz += dz;
				}
				for (int i = n - 1; i >= 0; i--) mover_bloque(fila[i][0], py, fila[i][1], fila[i][0] + dx, py, fila[i][1] + dz, true);
				return true;
			}
			int destx = dxx, destz = dzz;
			if (k == I) {
				while (en_huella(destx, py, destz)) {
					int nx = destx + dx, nz = destz + dz;
					if (hay(nx, py, nz) || (nx == px && nz == pz)) break;
					destx = nx; destz = nz;
				}
			}
			mover_bloque(tx, py, tz, destx, py, destz, true);
			return true;
		}
		int bx = px - dx, bz = pz - dz;
		if (hay(bx, py, bz)) {
			Kind k = kind(bx, py, bz);
			if (k == F || k == H) return false;
			if (!en_limites(tx, py, tz)) return false;
			if (!solido(tx, py - 1, tz)) {
				int hx_ = tx, hy_ = py - 1, hz_ = tz;
				if (solido(hx_, hy_ - 1, hz_)) {   // un escalón más abajo: se baja
					mover_bloque(bx, py, bz, px, py, pz, true);
					px = hx_; py = hy_; pz = hz_;
					llegar(dx, dz); return true;
				}
				if (hay(px, py - 1, pz) && !hay(hx_, hy_, hz_) && alcance_cuelgue(hx_, hy_, hz_)) {
					if (kind(px, py - 1, pz) == I) return false;
					mover_bloque(bx, py, bz, px, py, pz, true);
					px = hx_; py = hy_; pz = hz_;
					hx = -dx; hy = 0; hz = -dz;
					return true;
				}
				return false;
			}
			mover_bloque(bx, py, bz, px, py, pz, true);
			px = tx; pz = tz;
			llegar(dx, dz);
			return true;
		}
		return caminar(dx, dz);
	}
	bool colgar(int dx, int dz) {
		int tx = px + dx, tz = pz + dz;
		int hx_ = tx, hy_ = py - 1, hz_ = tz;
		if (kind(px, py - 1, pz) == I) return false;
		if (!alcance_cuelgue(tx, py, tz) || hay(tx, py, tz)) return false;
		if (solido(hx_, hy_, hz_) || solido(hx_, hy_ - 1, hz_)) return false;
		if (!hay(px, py - 1, pz)) return false;
		px = hx_; py = hy_; pz = hz_;
		hx = -dx; hy = 0; hz = -dz;
		return true;
	}
	bool colgado_accion(int dx, int dz) {
		int wx = hx, wz = hz;
		if (dx == wx && dz == wz) {   // trepar
			int sx = px + wx, sy = py + 1, sz = pz + wz;
			if (hay(sx, sy, sz) || hay(px, py + 1, pz)) return false;
			px = sx; py = sy; pz = sz; hx = hy = hz = 0;
			return true;
		}
		if (dx == -wx && dz == -wz) { hx = hy = hz = 0; return true; }   // soltarse
		int h2x = px + dx, h2z = pz + dz;
		int g2x = h2x + wx, g2z = h2z + wz;
		if (!alcance_cuelgue(h2x, py, h2z)) return false;
		if (hay(h2x, py, h2z)) {
			if (kind(h2x, py, h2z) == I) return false;
			hx = dx; hy = 0; hz = dz; return true;
		}
		if (hay(g2x, py, g2z)) {
			if (kind(g2x, py, g2z) == I) return false;
			px = h2x; pz = h2z; return true;
		}
		if (alcance_cuelgue(g2x, py, g2z) && !hay(px + wx, py + 1, pz + wz)) {
			px = g2x; pz = g2z; hx = -dx; hy = 0; hz = -dz; return true;
		}
		if (solido(g2x, py - 1, g2z)) {
			hx = hy = hz = 0; px = g2x; pz = g2z; llegar(dx, dz); return true;
		}
		return false;
	}

	// Una acción completa. false si no se pudo (o si se perdió).
	bool actuar(int dx, int dz, int modo) {
		if (ganado || perdido) return false;
		mov_jugador.clear();
		int gx = -999, gy = -999, gz = -999;
		if (!colgando() && kind(px, py - 1, pz) == C) { gx = px; gy = py - 1; gz = pz; }
		bool ok;
		if (colgando()) ok = colgado_accion(dx, dz);
		else if (modo == 1) ok = agarrar(dx, dz);
		else if (modo == 2) ok = colgar(dx, dz);
		else ok = caminar(dx, dz);
		if (!ok) return false;
		if (gx != -999 && hay(gx, gy, gz) && !(px == gx && py == gy + 1 && pz == gz) && kind(gx, gy, gz) == C) quitar(gx, gy, gz);
		asentar();
		peligros();
		if (perdido) return false;
		if (!colgando() && py == alto + 1 && kind(px, py - 1, pz) == F) { ganado = true; return true; }   // (ganar en el mismo movimiento tiene prioridad sobre la explosión)
		for (int i : cel) {
			if (!es_bomba(g[i]) || !en_zona(ix(i), iy(i), iz(i), px, py, pz)) continue;
			g[i]--;
			if (g[i] <= BOMBA0) { perdido = true; return false; }   // explotó: cae la sala entera
		}
		return true;
	}

};

struct Estado {
	vector<uint32_t> bloques;   // (idx << 8) | kind, ordenado
	int16_t px, py, pz;
	int8_t hx, hz;
};

static void cargar(Sim& s, const Estado& e, int alto) {
	memset(s.g, 0, s.lim);
	s.fijar_alto(alto);
	memset(s.g, 0, s.lim);
	s.cel.clear();
	for (uint32_t b : e.bloques) { s.g[b >> 8] = (uint8_t)(b & 255); s.cel.push_back((int)(b >> 8)); }
	s.px = e.px; s.py = e.py; s.pz = e.pz;
	s.hx = e.hx; s.hy = 0; s.hz = e.hz;
	s.perdido = false; s.ganado = false;
}
static void guardar(const Sim& s, Estado& e) {
	e.bloques.clear();
	for (int i : s.cel) e.bloques.push_back(((uint32_t)i << 8) | s.g[i]);
	e.px = s.px; e.py = s.py; e.pz = s.pz; e.hx = s.hx; e.hz = s.hz;
}
static uint64_t clave_estado(const Estado& e) {
	uint64_t h = 0;
	for (uint32_t b : e.bloques) { int k = b & 255; if (k != F) h ^= zk(b >> 8, k); }
	h ^= ZJ[idx(e.px, e.py, e.pz)] * 31;
	h ^= splitmix(1000 + (e.hx + 2) * 5 + (e.hz + 2)) * 17;
	return h;
}

static uint64_t clave_sim(const Sim& s) {
	uint64_t h = 0;
	for (int i : s.cel) { int k = s.g[i]; if (k != F) h ^= zk(i, k); }
	h ^= ZJ[idx(s.px, s.py, s.pz)] * 31;
	h ^= splitmix(1000 + (s.hx + 2) * 5 + (s.hz + 2)) * 17;
	return h;
}

struct Nodo { Estado e; int padre; uint8_t accion; int g; };

struct Resolucion {
	bool ok = false, tope = false;
	int moves = 0, agarres = 0, distintos = 0;
	long expandidos = 0;
	size_t nodos = 0;
	int cota = 0;   // si se acabó el tope: el mínimo es al menos esto (el menor f que quedaba abierto)
	vector<int> acc;   // acciones: modo * 4 + índice de DIRS
};

// Agarres (acciones de Shift que movieron un bloque) y bloques DISTINTOS movidos por el jugador a lo largo de un camino.
static void estadisticas(const Estado& e0, int meta, const vector<int>& acc, int& agarres, int& distintos) {
	Sim r;
	cargar(r, e0, meta);
	r.track = true;
	r.ids.assign(NC, 0);
	for (int i = 0; i < NC; i++) if (r.g[i] != NONE) r.ids[i] = (int16_t)i;
	vector<uint8_t> movido(NC, 0);
	agarres = 0;
	for (int a : acc) {
		int dx = DIRS[a % 4].x, dz = DIRS[a % 4].z, modo = a / 4;
		r.actuar(dx, dz, modo);
		if (modo == 1 && !r.mov_jugador.empty()) {
			agarres++;
			for (auto& m : r.mov_jugador) { int id = (uint16_t)r.ids[m.second]; if (id < NC) movido[id] = 1; }
		}
	}
	distintos = 0;
	for (int i = 0; i < NC; i++) distintos += movido[i];
}

// A* exacto (heurística: pisos que faltan). tope = nodos como mucho.
static Resolucion resolver(const Estado& e0, int meta, int tope, bool con_stats = true, int objetivo = -1, int ub = 1 << 28) {
	Resolucion res;
	bool hay_k = false;
	for (uint32_t b : e0.bloques) if ((b & 255) == K) hay_k = true;
	int fin_y = objetivo > 0 ? objetivo : meta + 1;
	auto heur = [&](int py) { int falta = fin_y - py; if (falta <= 0) return 0; return hay_k ? (falta + 6) / 7 : falta; };
	vector<Nodo> nodos;
	nodos.push_back({e0, -1, 255, 0});
	unordered_map<uint64_t, int> vistos;
	vistos[clave_estado(e0)] = 0;
	vector<vector<int>> cubos(512);
	int f_min = heur(e0.py);
	cubos[f_min].push_back(0);
	Sim s, t;
	int meta_nodo = -1;
	while (true) {
		while (f_min < (int)cubos.size() && cubos[f_min].empty()) f_min++;
		if (f_min >= (int)cubos.size()) break;
		int id = cubos[f_min].back(); cubos[f_min].pop_back();
		cargar(s, nodos[id].e, meta);
		int g0 = nodos[id].g;
		res.expandidos++;
		for (int a = 0; a < 12; a++) {
			int dx = DIRS[a % 4].x, dz = DIRS[a % 4].z, modo = a / 4;
			if (s.colgando() && modo != 0) continue;
			t.copiar_de(s);
			if (!t.actuar(dx, dz, modo)) continue;
			uint64_t k = clave_sim(t);
			int gn = g0 + 1;
			auto it = vistos.find(k);
			if (it != vistos.end() && it->second <= gn) continue;
			vistos[k] = gn;
			Estado ne; guardar(t, ne);
			nodos.push_back({ne, id, (uint8_t)a, gn});
			int ni = (int)nodos.size() - 1;
			if (t.ganado || (objetivo > 0 && !t.colgando() && t.py >= objetivo)) { meta_nodo = ni; break; }
			int f = gn + heur(t.py);
			if (f > ub) continue;   // (no puede mejorar la cota superior conocida)
			if (f >= (int)cubos.size()) cubos.resize(f + 64);
			cubos[f].push_back(ni);
			if (f < f_min) f_min = f;
		}
		if (meta_nodo >= 0) break;
		if ((int)nodos.size() > tope) { res.tope = true; res.nodos = nodos.size(); res.cota = f_min; return res; }
	}
	res.nodos = nodos.size();
	if (meta_nodo < 0) return res;
	for (int i = meta_nodo; nodos[i].padre >= 0; i = nodos[i].padre) res.acc.push_back(nodos[i].accion);
	reverse(res.acc.begin(), res.acc.end());
	res.ok = true;
	res.moves = (int)res.acc.size();
	if (con_stats) estadisticas(e0, meta, res.acc, res.agarres, res.distintos);
	return res;
}

// Resolución por lonjas: se resuelve de a `salto` pisos (el solucionador exacto sólo hasta el próximo nivel), y se sigue desde donde quedó el jugador.
// La concatenación es una solución válida de la sala entera (sin garantía de ser la más corta). Falla si alguna lonja no se resuelve.
static Resolucion resolver_lonjas(const Estado& e0, int meta, int tope_lonja, int salto = 2) {
	Resolucion total;
	Estado actual = e0;
	Sim s;
	for (int vuelta = 0; vuelta < 80; vuelta++) {
		cargar(s, actual, meta);
		int objetivo = min(s.py + salto, meta + 1);
		Resolucion r = (objetivo >= meta + 1) ? resolver(actual, meta, tope_lonja, false) : resolver(actual, meta, tope_lonja, false, objetivo);
		total.expandidos += r.expandidos;
		total.nodos += r.nodos;
		if (!r.ok) {
			// una lonja de un solo piso a veces sale cuando la de dos no
			if (salto > 1) { r = (s.py + 1 >= meta + 1) ? resolver(actual, meta, tope_lonja, false) : resolver(actual, meta, tope_lonja, false, s.py + 1); total.expandidos += r.expandidos; }
			if (!r.ok) { total.tope = r.tope; return total; }
		}
		for (int a : r.acc) {
			s.actuar(DIRS[a % 4].x, DIRS[a % 4].z, a / 4);
			total.acc.push_back(a);
		}
		if (s.ganado) break;
		guardar(s, actual);
	}
	Sim fin;
	cargar(fin, e0, meta);
	for (int a : total.acc) fin.actuar(DIRS[a % 4].x, DIRS[a % 4].z, a / 4);
	if (!fin.ganado) return total;
	total.ok = true;
	total.moves = (int)total.acc.size();
	estadisticas(e0, meta, total.acc, total.agarres, total.distintos);
	return total;
}

// Acortar un camino conocido por ventanas: desde cada estado del camino se hace una búsqueda a lo ancho (hasta `ventana` pasos) y, si se llega a algún estado
// posterior del mismo camino en menos pasos que los que el camino tardaba, se reemplaza ese tramo. Se repite hasta que ninguna ventana mejora.
// El resultado es un camino válido (se verifica jugándolo) y, en la práctica, muy cerca del mínimo; el mínimo DEMOSTRADO sigue necesitando el A*.
static vector<int> acortar(const Estado& e0, int meta, vector<int> acc, int ventana, long tope_bfs) {
	for (int ronda = 0; ronda < 200; ronda++) {
		int n = (int)acc.size();
		vector<Estado> est(n + 1);
		vector<uint64_t> hs(n + 1);
		unordered_map<uint64_t, int> indice;
		Sim s;
		cargar(s, e0, meta);
		guardar(s, est[0]);
		hs[0] = clave_estado(est[0]);
		indice[hs[0]] = 0;
		for (int i = 0; i < n; i++) {
			s.actuar(DIRS[acc[i] % 4].x, DIRS[acc[i] % 4].z, acc[i] / 4);
			guardar(s, est[i + 1]);
			hs[i + 1] = clave_estado(est[i + 1]);
			indice[hs[i + 1]] = i + 1;   // (si el camino pasa dos veces por un estado, vale el último)
		}
		int mejor_i = -1, mejor_k = -1, mejor_ahorro = 0;
		vector<int> mejor_tramo;
		for (int i = 0; i + 2 < n && mejor_ahorro < 3; i++) {
			// búsqueda a lo ancho desde el estado i
			struct Nb { Estado e; int padre; int a; int d; };
			vector<Nb> cola;
			unordered_map<uint64_t, int> vist;
			cola.push_back({est[i], -1, -1, 0});
			vist[hs[i]] = 0;
			size_t cab = 0;
			Sim t, u;
			bool hallado = false;
			while (cab < cola.size() && (long)cola.size() < tope_bfs && !hallado) {
				Nb actual = cola[cab];
				int idx_actual = (int)cab;
				cab++;
				if (actual.d >= ventana) continue;
				cargar(t, actual.e, meta);
				for (int a = 0; a < 12; a++) {
					int modo = a / 4;
					if (t.colgando() && modo != 0) continue;
					u.copiar_de(t);
					if (!u.actuar(DIRS[a % 4].x, DIRS[a % 4].z, modo)) continue;
					uint64_t k = clave_sim(u);
					if (vist.count(k)) continue;
					vist[k] = actual.d + 1;
					Estado ne; guardar(u, ne);
					cola.push_back({ne, idx_actual, a, actual.d + 1});
					auto it = indice.find(k);
					if (it != indice.end() && it->second > i && it->second - i > actual.d + 1) {
						int ahorro = it->second - i - (actual.d + 1);
						if (ahorro > mejor_ahorro) {
							mejor_ahorro = ahorro; mejor_i = i; mejor_k = it->second;
							mejor_tramo.clear();
							for (int q = (int)cola.size() - 1; cola[q].padre >= 0; q = cola[q].padre) mejor_tramo.push_back(cola[q].a);
							reverse(mejor_tramo.begin(), mejor_tramo.end());
						}
					}
				}
			}
		}
		if (mejor_ahorro <= 0) break;
		vector<int> nuevo(acc.begin(), acc.begin() + mejor_i);
		nuevo.insert(nuevo.end(), mejor_tramo.begin(), mejor_tramo.end());
		nuevo.insert(nuevo.end(), acc.begin() + mejor_k, acc.end());
		acc = nuevo;
	}
	// comprobación: jugado de punta a punta tiene que ganar
	Sim v;
	cargar(v, e0, meta);
	for (int a : acc) v.actuar(DIRS[a % 4].x, DIRS[a % 4].z, a / 4);
	return v.ganado ? acc : vector<int>();
}

// A* exacto con poca memoria, para demostrar mínimos de salas altas con muchísimos nodos: de cada nodo sólo se guarda el padre, la acción y la distancia (12 bytes);
// el estado completo se guarda cada 8 pasos y se reconstruye repitiendo las acciones desde el último guardado. La tabla de estados vistos es de direccionamiento abierto
// (10 bytes por estado). Con la misma memoria alcanza para unas 5 veces más nodos que resolver().
struct TablaVistos {
	vector<uint64_t> clave;
	vector<uint16_t> val;   // distancia + 1 (0 = vacío)
	size_t n = 0, mascara = 0;
	TablaVistos() { clave.assign(1 << 20, 0); val.assign(1 << 20, 0); mascara = (1 << 20) - 1; }
	size_t pos(uint64_t k) const { size_t p = (size_t)(k * 0x9E3779B97F4A7C15ULL >> 20) & mascara; while (val[p] && clave[p] != k) p = (p + 1) & mascara; return p; }
	int get(uint64_t k) const { size_t p = pos(k); return val[p] ? (int)val[p] - 1 : -1; }
	void crecer() {
		vector<uint64_t> ck; vector<uint16_t> cv;
		ck.swap(clave); cv.swap(val);
		size_t nuevo = (mascara + 1) * 2;
		clave.assign(nuevo, 0); val.assign(nuevo, 0); mascara = nuevo - 1;
		for (size_t i = 0; i < ck.size(); i++) if (cv[i]) { size_t p = pos(ck[i]); clave[p] = ck[i]; val[p] = cv[i]; }
	}
	void poner(uint64_t k, int g) {
		if ((n + 1) * 10 > (mascara + 1) * 7) crecer();
		size_t p = pos(k);
		if (!val[p]) n++;
		clave[p] = k; val[p] = (uint16_t)(g + 1);
	}
};

struct NodoC { int padre; uint16_t g; uint8_t a; int32_t est; };

static Resolucion resolver_compacto(const Estado& e0, int meta, long tope, int ub) {
	Resolucion res;
	bool hay_k = false;
	for (uint32_t b : e0.bloques) if ((b & 255) == K) hay_k = true;
	auto heur = [&](int py) { int falta = meta + 1 - py; if (falta <= 0) return 0; return hay_k ? (falta + 6) / 7 : falta; };
	vector<NodoC> nodos;
	vector<Estado> pool;
	pool.push_back(e0);
	nodos.push_back({-1, 0, 255, 0});
	TablaVistos vistos;
	vistos.poner(clave_estado(e0), 0);
	vector<vector<int>> cubos(512);
	int f_min = heur(e0.py);
	cubos[f_min].push_back(0);
	Sim s, t;
	int meta_nodo = -1;
	vector<int> acciones;
	while (true) {
		while (f_min < (int)cubos.size() && cubos[f_min].empty()) f_min++;
		if (f_min >= (int)cubos.size()) break;
		int id = cubos[f_min].back(); cubos[f_min].pop_back();
		// reconstruir el estado: desde el último guardado, repitiendo las acciones
		acciones.clear();
		int cur = id;
		while (nodos[cur].est < 0) { acciones.push_back(nodos[cur].a); cur = nodos[cur].padre; }
		cargar(s, pool[nodos[cur].est], meta);
		for (int q = (int)acciones.size() - 1; q >= 0; q--) s.actuar(DIRS[acciones[q] % 4].x, DIRS[acciones[q] % 4].z, acciones[q] / 4);
		int g0 = nodos[id].g;
		res.expandidos++;
		for (int a = 0; a < 12; a++) {
			int dx = DIRS[a % 4].x, dz = DIRS[a % 4].z, modo = a / 4;
			if (s.colgando() && modo != 0) continue;
			t.copiar_de(s);
			if (!t.actuar(dx, dz, modo)) continue;
			uint64_t k = clave_sim(t);
			int gn = g0 + 1;
			int previo = vistos.get(k);
			if (previo >= 0 && previo <= gn) continue;
			vistos.poner(k, gn);
			int32_t est = -1;
			if (gn % 8 == 0) { Estado ne; guardar(t, ne); pool.push_back(ne); est = (int32_t)pool.size() - 1; }
			nodos.push_back({id, (uint16_t)gn, (uint8_t)a, est});
			int ni = (int)nodos.size() - 1;
			if (t.ganado) { meta_nodo = ni; break; }
			int f = gn + heur(t.py);
			if (f > ub) continue;
			if (f >= (int)cubos.size()) cubos.resize(f + 64);
			cubos[f].push_back(ni);
			if (f < f_min) f_min = f;
		}
		if (meta_nodo >= 0) break;
		if ((long)nodos.size() > tope) { res.tope = true; res.nodos = nodos.size(); res.cota = f_min; return res; }
	}
	res.nodos = nodos.size();
	if (meta_nodo < 0) return res;
	for (int i = meta_nodo; nodos[i].padre >= 0; i = nodos[i].padre) res.acc.push_back(nodos[i].a);
	reverse(res.acc.begin(), res.acc.end());
	res.ok = true;
	res.moves = (int)res.acc.size();
	estadisticas(e0, meta, res.acc, res.agarres, res.distintos);
	return res;
}

static string kind_letra(int k) {
	const char* L = "?nfhictskp";   // (el orden de Kind: T = trampa va antes que S = pinchos)
	if (k == BD) return "d";
	if (es_bomba(k)) return "b" + to_string(k - BOMBA0);
	return string(1, L[k < 10 ? k : 0]);
}

static string estado_json(const Estado& e) {
	string s = "[";
	bool primero = true;
	for (uint32_t b : e.bloques) {
		int i = b >> 8;
		if (!primero) s += ",";
		primero = false;
		s += "[" + to_string(ix(i)) + "," + to_string(iy(i)) + "," + to_string(iz(i)) + ",\"" + kind_letra(b & 255) + "\"]";
	}
	return s + "]";
}

static string camino_json(const vector<int>& acc) {
	string s = "[";
	for (size_t i = 0; i < acc.size(); i++) {
		if (i) s += ",";
		s += "[" + to_string(DIRS[acc[i] % 4].x) + "," + to_string(DIRS[acc[i] % 4].z) + "," + to_string(acc[i] / 4) + "]";
	}
	return s + "]";
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Generador: parte de la sala RESUELTA (una escalera de un bloque por piso dentro de la huella, el jugador parado sobre el bloque checkpoint
// de la salida) y va hacia atrás: cada paso hacia atrás es un estado desde el cual UNA acción del motor lleva exactamente al actual (se comprueba
// simulando hacia adelante), así que la sala que sale siempre se puede resolver (con ese camino al revés, o uno más corto).
// ---------------------------------------------------------------------------------------------------------------------------------

static int g_fx0 = -99, g_fz0 = -99, g_fx1 = 99, g_fz1 = 99;   // la huella de la sala que se está generando: los bloques no salen de ella al desordenar

struct Pred { Estado e; int a; bool bloque; int desde, hasta; };   // desde/hasta: celdas del bloque movido (si bloque)

static bool iguales(const Sim& a, const Sim& b) {
	return a.px == b.px && a.py == b.py && a.pz == b.pz && a.hx == b.hx && a.hz == b.hz && memcmp(a.g, b.g, a.lim) == 0;
}

static bool estable(const Sim& c) {
	if (c.hay(c.px, c.py, c.pz)) return false;
	if (c.colgando()) { if (!c.hay(c.px + c.hx, c.py, c.pz + c.hz)) return false; }
	else if (!c.hay(c.px, c.py - 1, c.pz)) return false;
	static thread_local Sim t;
	t.copiar_de(c);
	return t.asentar_bloques() == 0;
}

static void predecesores(const Sim& cur, int radio, vector<Pred>& out) {
	out.clear();
	static thread_local Sim c, t;
	static const int HD[5][2] = {{0, 0}, {1, 0}, {-1, 0}, {0, 1}, {0, -1}};
	// a) se movió el jugador
	for (int dx = -1; dx <= 1; dx++) for (int dz = -1; dz <= 1; dz++) for (int dy = -1; dy <= 1; dy++) for (int ch = 0; ch < 5; ch++) {
		c.copiar_de(cur);
		c.ganado = false; c.perdido = false;
		c.px += dx; c.py += dy; c.pz += dz;
		c.hx = HD[ch][0]; c.hy = 0; c.hz = HD[ch][1];
		if (c.px == cur.px && c.py == cur.py && c.pz == cur.pz && c.hx == cur.hx && c.hz == cur.hz) continue;
		if (!c.en_limites(c.px, c.py, c.pz) || c.py < 2) continue;
		if (!estable(c)) continue;
		for (int a = 0; a < 12; a++) {
			int modo = a / 4;
			if (c.colgando() && modo != 0) continue;
			t.copiar_de(c);
			if (!t.actuar(DIRS[a % 4].x, DIRS[a % 4].z, modo)) continue;
			if (iguales(t, cur)) {
				Pred p; guardar(c, p.e); p.a = a; p.bloque = false; p.desde = p.hasta = -1;
				out.push_back(p);
				break;
			}
		}
	}
	// b) se empujó o se tiró un bloque
	for (int i : cur.cel) {
		if (cur.g[i] == F || cur.g[i] == CP) continue;   // (el fijo y la entrada no se mueven al desordenar)
		int x = ix(i), y = iy(i), z = iz(i);
		if (abs(x - cur.px) > radio || abs(z - cur.pz) > radio || abs(y - cur.py) > 2) continue;
		for (int k = 0; k < 4; k++) {
			int ax = x - DIRS[k].x, az = z - DIRS[k].z;
			if (!dentro(ax, y, az) || cur.hay(ax, y, az)) continue;
			if (ax < g_fx0 || ax > g_fx1 || az < g_fz0 || az > g_fz1) continue;
			for (int mj = 0; mj < 2; mj++) {
				c.copiar_de(cur);
				c.ganado = false; c.perdido = false;
				{ Kind kk = (Kind)c.g[i]; c.quitar(x, y, z); c.poner(ax, y, az, kk); }
				if (mj) { c.px -= DIRS[k].x; c.pz -= DIRS[k].z; }
				if (!c.en_limites(c.px, c.py, c.pz)) continue;
				if (!estable(c)) continue;
				t.copiar_de(c);
				if (!t.actuar(DIRS[k].x, DIRS[k].z, 1)) continue;
				if (iguales(t, cur)) {
					Pred p; guardar(c, p.e); p.a = 4 + k; p.bloque = true; p.desde = i; p.hasta = idx(ax, y, az);
					out.push_back(p);
				}
			}
		}
	}
}

struct Traza { int padre; int a; };

struct NodoH {
	Estado e;
	int traza;
	int ef = 0;
	vector<pair<int, int>> ids;      // celda -> identidad
	vector<int> cnt;                  // movimientos por identidad
	vector<vector<int>> vis;          // celdas visitadas por identidad
	int tocados = 0;
};

static int id_de(const NodoH& n, int celda) { for (auto& p : n.ids) if (p.first == celda) return p.second; return -1; }

struct Candidata { double puntaje; Estado e; int traza; };

struct Param {
	string tipo = "3x3";
	int h = 6, extras = 3, ancho = 10, profundidad = 40, tope_bloque = 2, min_ef = 4, min_dist = 3, evaluar = 24, radio = 3;
	long tope_eval = 300000;
	int min_distintos_exactos = 0;
	double ruido = 4.0;
	unsigned long long semilla = 1;
	int cuantas = 1;
	int limite_cand = 160;
	int exacto = 1, pre = 24;
	double wd = 6.0;   // peso de los bloques distintos movidos en el valor
	int escalada = 0;   // iteraciones de mejora local sobre la mejor sala
	long tope_escalada = 60000;
	double temp = 0.0;
	long tope_nivel = 20000;
	int h_exacto = 9;   // por encima de esta altura se evalúa por lonjas en vez del solucionador exacto
	int salto = 2;
	int riesgo = 1;
	int giro = 0;   // 1: la salida queda a 90 grados de la entrada (5x3 y 8x3: sobre el lado largo, en el bloque del extremo contrario; 3x3: en el lado perpendicular)
	long refinar = 2000000;   // en salas altas (por lonjas) se intenta al final el solucionador exacto con este tope de nodos
};

static void huella(const string& tipo, int& x0, int& z0, int& w, int& d) {
	if (tipo == "5x3") { x0 = 3; z0 = 0; w = 5; d = 3; }
	else if (tipo == "8x3") { x0 = 0; z0 = 0; w = 8; d = 3; }
	else { x0 = 0; z0 = 0; w = 3; d = 3; }
}

// ¿La celda (ex, ez) sirve de salida si se entra por (sx, sz)? Entrada y salida son puntos externos y opuestos de la huella:
// 3x3: salida en el borde y lejos de la entrada (a 3 o más celdas); 5x3 y 8x3: en la punta contraria.
static int g_giro = 0;   // (lo fija sala_resuelta: salida a 90 grados de la entrada)
static bool fin_valido(const string& tipo, int w, int d, int sx, int sz, int ex, int ez) {
	if (tipo == "5x3" || tipo == "8x3") {
		if (g_giro) {   // la salida sobre un lado largo, dentro del bloque de 3 del extremo contrario (sin ser la punta: ahí sería una sala recta)
			bool lado = ez == 0 || ez == d - 1;
			return lado && (sx == 0 ? (ex >= w - 3 && ex <= w - 2) : (ex >= 1 && ex <= 2));
		}
		return sx == 0 ? ex == w - 1 : ex == 0;
	}
	if (g_giro) return ez == d - 1 - sz && ex != w - 1 - sx && abs(ex - sx) + abs(ez - sz) >= 3;
	bool borde = ex == 0 || ex == w - 1 || ez == 0 || ez == d - 1;
	return borde && abs(ex - sx) + abs(ez - sz) >= 3;
}

static bool camino_dfs(const string& tipo, mt19937_64& rng, int w, int d, int largo, vector<int>& camino, vector<char>& usado, long& presupuesto) {
	if ((int)camino.size() == largo) return fin_valido(tipo, w, d, camino[0] % w, camino[0] / w, camino.back() % w, camino.back() / w);
	if (--presupuesto < 0) return false;
	int ult = camino.back();
	int cx = ult % w, cz = ult / w;
	int orden[4] = {0, 1, 2, 3};
	shuffle(orden, orden + 4, rng);
	for (int q = 0; q < 4; q++) {
		int nx = cx + DIRS[orden[q]].x, nz = cz + DIRS[orden[q]].z;
		if (nx < 0 || nx >= w || nz < 0 || nz >= d || usado[nz * w + nx]) continue;
		usado[nz * w + nx] = 1;
		camino.push_back(nz * w + nx);
		if (camino_dfs(tipo, rng, w, d, largo, camino, usado, presupuesto)) return true;
		camino.pop_back();
		usado[nz * w + nx] = 0;
		if (presupuesto < 0) return false;
	}
	return false;
}

// La sala resuelta: escalera de h bloques (nivel 1 = bloque de entrada "p", nivel h = bloque de salida "p"), un bloque fijo al lado de la salida
// (lo que la toca en la sala de arriba) y `extras` bloques más pegados a lo que ya hay. El jugador queda parado sobre la salida.
static bool sala_resuelta(const Param& P, mt19937_64& rng, Sim& out) {
	int x0, z0, w, d;
	huella(P.tipo, x0, z0, w, d);
	if (P.h > w * d || P.h < 2) return false;
	g_giro = P.giro;
	vector<int> camino;
	vector<char> usado(w * d, 0);
	bool ok = false;
	for (int intento = 0; intento < 60 && !ok; intento++) {
		camino.clear();
		fill(usado.begin(), usado.end(), 0);
		int ix0, iz0;   // la entrada: una esquina (3x3) o una de las dos puntas (5x3 y 8x3)
		if (P.tipo == "5x3" || P.tipo == "8x3") { ix0 = (rng() & 1) ? 0 : w - 1; iz0 = (int)(rng() % d); }
		else { ix0 = (rng() & 1) ? 0 : w - 1; iz0 = (rng() & 1) ? 0 : d - 1; }
		int ini = iz0 * w + ix0;
		camino.push_back(ini);
		usado[ini] = 1;
		long pres = 30000;
		ok = camino_dfs(P.tipo, rng, w, d, P.h, camino, usado, pres);
	}
	if (!ok) return false;
	out.limpiar();
	out.fijar_alto(P.h);
	for (int k = 0; k < P.h; k++) {
		int cx = x0 + camino[k] % w, cz = z0 + camino[k] / w;
		out.poner(cx, k + 1, cz, k == 0 ? CP : (k == P.h - 1 ? F : N));   // entrada = checkpoint común, salida = el checkpoint fijo (el ancla de la sala)
	}
	int ex = x0 + camino[P.h - 1] % w, ez = z0 + camino[P.h - 1] / w;
	out.px = ex; out.py = P.h + 1; out.pz = ez;
	// extras: pegados a los bloques de la sala, DENTRO de la huella (la sala se arma en su 3x3, 5x3 u 8x3), entre los niveles 1 y h
	int puestos = 0;
	for (int intento = 0; intento < P.extras * 120 && puestos < P.extras; intento++) {
		vector<int> celdas;
		for (int i = 0; i < out.lim; i++) if (out.g[i] != NONE) celdas.push_back(i);
		int b = celdas[rng() % celdas.size()];
		int vx = ix(b), vy = iy(b), vz = iz(b);
		int dxs[3] = {-1, 0, 1};
		int nx = vx + dxs[rng() % 3], nz = vz + dxs[rng() % 3], ny = vy + dxs[rng() % 3];
		int ndx = (nx != vx) + (ny != vy) + (nz != vz);
		if (ndx == 0 || ndx == 3) continue;
		if (ndx == 2 && ny == vy) continue;
		if (ny < 2 || ny > P.h - 1 || nx < x0 || nx >= x0 + w || nz < z0 || nz >= z0 + d || out.hay(nx, ny, nz)) continue;
		if (nx == out.px && ny == out.py && nz == out.pz) continue;
		out.poner(nx, ny, nz, N);
		Sim t = out;
		if (t.asentar_bloques() != 0) { out.quitar(nx, ny, nz); continue; }
		puestos++;
	}
	return true;
}

static bool es_inicio(const Sim& s) {
	return !s.colgando() && s.py == 2 && s.kind(s.px, s.py - 1, s.pz) == CP;
}

// Riesgo: a lo largo del camino más corto, de todos los movimientos legales cuántos son letales (se cae en el acto o la sala deja de tener solución).
static void riesgo(const Estado& e0, int meta, const vector<int>& acc, long tope, int& legales, int& letales) {
	legales = 0; letales = 0;
	Sim s;
	cargar(s, e0, meta);
	for (int a_opt : acc) {
		for (int a = 0; a < 12; a++) {
			int modo = a / 4;
			if (s.colgando() && modo != 0) continue;
			Sim t = s;
			if (!t.actuar(DIRS[a % 4].x, DIRS[a % 4].z, modo)) {
				if (t.perdido) { legales++; letales++; }
				continue;
			}
			legales++;
			if (t.ganado) continue;
			Estado ne; guardar(t, ne);
			Resolucion r = resolver(ne, meta, (int)tope, false);
			if (!r.ok && !r.tope) letales++;
		}
		s.actuar(DIRS[a_opt % 4].x, DIRS[a_opt % 4].z, a_opt / 4);
	}
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Métrica de complejidad (ver docs/metrica_dificultad.md). A lo largo de UN camino más corto, en cada estado se prueban TODOS los movimientos legales y
// se resuelve cada hijo con el solucionador exacto:
//   legales_i  = movimientos legales (los que no se rechazan: incluye los que matan en el acto)
//   optimos_i  = los que dejan al jugador a (restante - 1) pasos de ganar, o sea los que siguen un camino más corto
//   letales_i  = los que matan en el acto o dejan la sala sin solución
//   bits_opt   = suma de log2(legales_i / optimos_i): la información que hace falta para seguir un camino más corto entre todos los legales
//   bits_letal = suma de -log2(1 - letales_i / legales_i): lo "peligroso" que es moverse al azar (una cada vez que hay una trampa a mano)
//   complejidad = bits_opt + bits_letal  (pesos 1 y 1; provisorio hasta calibrar con el jugador)
// Si algún hijo se queda sin presupuesto no se sabe su distancia: se cuenta aparte (desconocidos) y la métrica es aproximada.
// ---------------------------------------------------------------------------------------------------------------------------------
struct Metricas {
	int legales = 0, letales = 0, optimos = 0, desconocidos = 0;
	double bits_opt = 0, bits_letal = 0;
	int criticos = 0;   // pasos en los que sólo un movimiento legal sigue un camino más corto y hay otros legales
};

static void medir(const Estado& e0, int meta, const vector<int>& acc, long tope_hijo, Metricas& m) {
	Sim s, t;
	cargar(s, e0, meta);
	int restante = (int)acc.size();
	for (int a_opt : acc) {
		int leg = 0, let = 0, opt = 0, desc = 0;
		for (int a = 0; a < 12; a++) {
			int modo = a / 4;
			if (s.colgando() && modo != 0) continue;
			t.copiar_de(s);
			if (!t.actuar(DIRS[a % 4].x, DIRS[a % 4].z, modo)) {
				if (t.perdido) { leg++; let++; }
				continue;
			}
			leg++;
			if (t.ganado) { if (restante - 1 == 0) opt++; continue; }
			Estado ne; guardar(t, ne);
			Resolucion r = resolver(ne, meta, (int)tope_hijo, false);
			if (r.ok) { if (r.moves == restante - 1) opt++; }
			else if (r.tope) desc++;
			else let++;
		}
		m.legales += leg; m.letales += let; m.optimos += opt; m.desconocidos += desc;
		if (leg > 0) {
			int o = max(opt, 1);
			m.bits_opt += log2((double)leg / (double)o);
			if (let < leg) m.bits_letal += -log2(1.0 - (double)let / (double)leg);
			if (opt == 1 && leg > 1) m.criticos++;
		}
		s.actuar(DIRS[a_opt % 4].x, DIRS[a_opt % 4].z, a_opt / 4);
		restante--;
	}
}

static string metricas_json(const Metricas& m) {
	char buf[320];
	snprintf(buf, sizeof(buf), "\"legales\":%d,\"letales\":%d,\"optimos\":%d,\"desconocidos\":%d,\"criticos\":%d,\"bits_opt\":%.2f,\"bits_letal\":%.2f,\"complejidad\":%.2f", m.legales, m.letales, m.optimos, m.desconocidos, m.criticos, m.bits_opt, m.bits_letal, m.bits_opt + m.bits_letal);
	return string(buf);
}

static string sala_json(const Param& P, const Estado& e, const Resolucion& r, int armado, bool exacto, const Metricas& mt) {
	string s = "{\"tipo\":\"" + P.tipo + "\",\"meta\":" + to_string(P.h) + ",\"jugador\":[" + to_string(e.px) + "," + to_string(e.py) + "," + to_string(e.pz) + "],\"colgado\":[" + to_string(e.hx) + "," + to_string(e.hz) + "],";
	s += "\"bloques\":" + estado_json(e) + ",\"pasos\":" + to_string(r.moves) + ",\"agarres\":" + to_string(r.agarres) + ",\"distintos\":" + to_string(r.distintos);
	s += ",\"giro\":" + to_string(P.giro) + ",\"armado\":" + to_string(armado) + ",\"exacto\":" + string(exacto ? "true" : "false") + ",\"extras\":" + to_string(P.extras) + ",\"camino\":" + camino_json(r.acc) + "}";
	s.pop_back();
	s += "," + metricas_json(mt) + "}";
	return s;
}

// Un cambio chico a la sala (mover un bloque, agregar uno o sacar uno) que la deja estable; el jugador queda sobre el bloque de entrada.
static bool mutar(const Sim& base, const Param& P, mt19937_64& rng, Sim& out) {
	int x0, z0, w, d;
	huella(P.tipo, x0, z0, w, d);
	out = base;
	out.ganado = false; out.perdido = false;
	vector<int> comunes;
	for (int i = 0; i < out.lim; i++) if (out.g[i] != NONE && out.g[i] != F && out.g[i] != CP) comunes.push_back(i);
	int tipo = (int)(rng() % 10);
	if (tipo < 7) {   // mover un bloque a otra celda del mismo nivel
		int b = comunes[rng() % comunes.size()];
		int y = iy(b);
		int nx = x0 + (int)(rng() % w), nz = z0 + (int)(rng() % d);
		if (out.hay(nx, y, nz)) return false;
		Kind k = (Kind)out.g[b];
		out.quitar(ix(b), iy(b), iz(b));
		out.poner(nx, y, nz, k);
	} else if (tipo < 9) {   // agregar un común
		int b = comunes[rng() % comunes.size()];
		int dxs[3] = {-1, 0, 1};
		int nx = ix(b) + dxs[rng() % 3], nz = iz(b) + dxs[rng() % 3], ny = iy(b) + dxs[rng() % 3];
		int nd = (nx != ix(b)) + (ny != iy(b)) + (nz != iz(b));
		if (nd == 0 || nd == 3 || (nd == 2 && ny == iy(b))) return false;
		if (ny < 2 || ny > P.h - 1 || nx < x0 || nx >= x0 + w || nz < z0 || nz >= z0 + d || out.hay(nx, ny, nz)) return false;
		out.poner(nx, ny, nz, N);
	} else {   // sacar un común
		int b = comunes[rng() % comunes.size()];
		if (out.g[b] != N) return false;
		out.quitar(ix(b), iy(b), iz(b));
	}
	// el jugador sobre el bloque de entrada (el checkpoint del nivel 1)
	int pc = -1;
	for (int i = 0; i < GZ * GX * 2 && i < out.lim; i++) if (out.g[i] == CP && iy(i) == 1) pc = i;
	if (pc < 0 || out.hay(ix(pc), 2, iz(pc))) return false;
	out.px = ix(pc); out.py = 2; out.pz = iz(pc); out.hx = 0; out.hz = 0;
	return estable(out);
}

static Resolucion evaluar_sala(const Estado& e, const Param& P, long tope) {
	if (P.h <= P.h_exacto) return resolver(e, P.h, (int)tope);
	return resolver_lonjas(e, P.h, (int)tope, P.salto);
}

static double valor_de(const Resolucion& r, const Param& P) { return r.moves + 3.0 * r.agarres + P.wd * r.distintos; }

static double ahora() { return (double)clock() / CLOCKS_PER_SEC; }

static bool generar_una(const Param& P, mt19937_64& rng, string& salida) {
	double t_ini = ahora();
	{ int hx0, hz0, hw, hd; huella(P.tipo, hx0, hz0, hw, hd); g_fx0 = hx0; g_fz0 = hz0; g_fx1 = hx0 + hw - 1; g_fz1 = hz0 + hd - 1; }
	Sim e;
	if (!sala_resuelta(P, rng, e)) { if (getenv("SALAS_LOG")) fprintf(stderr, "sala resuelta: no se pudo armar (%.1f s)\n", ahora() - t_ini); return false; }
	if (getenv("SALAS_LOG")) fprintf(stderr, "sala resuelta lista (%.1f s)\n", ahora() - t_ini);
	e.ganado = true;
	vector<Traza> trazas;
	trazas.push_back({-1, 0});
	NodoH raiz;
	guardar(e, raiz.e);
	raiz.traza = 0;
	{ int n = 0; for (int i = 0; i < e.lim; i++) if (e.g[i] != NONE && e.g[i] != F) { raiz.ids.push_back({i, n++}); } raiz.cnt.assign(n, 0); raiz.vis.assign(n, {}); }
	unordered_set<uint64_t> vistos;
	vistos.insert(clave_estado(raiz.e));
	vector<NodoH> capa;
	capa.push_back(raiz);
	vector<Candidata> cands;
	vector<pair<double, Estado>> pool;   // sin evaluación exacta en cada capa (salas altas): los estados que pasan la exigencia, para armar las variantes al final
	Sim cur;
	vector<Pred> preds;
	for (int nivel = 0; nivel < P.profundidad && (int)cands.size() < P.limite_cand; nivel++) {
		vector<pair<double, NodoH>> sig;
		for (auto& nodo : capa) {
			cargar(cur, nodo.e, P.h);
			predecesores(cur, P.radio, preds);
			for (auto& p : preds) {
				uint64_t k = clave_estado(p.e);
				if (!vistos.insert(k).second) continue;
				NodoH h2;
				h2.e = p.e;
				h2.ef = nodo.ef; h2.ids = nodo.ids; h2.cnt = nodo.cnt; h2.vis = nodo.vis; h2.tocados = nodo.tocados;
				if (p.bloque) {
					int id = id_de(nodo, p.hasta + 0 * 0);
					// el bloque estaba en `hasta`... en el estado ANTERIOR (hacia atrás) está en `hasta`; antes (en `cur`) estaba en `desde`
					id = id_de(nodo, p.desde);
					if (id < 0) continue;
					for (auto& q : h2.ids) if (q.first == p.desde) q.first = p.hasta;
					h2.cnt[id]++;
					bool ya = false;
					for (int c : h2.vis[id]) if (c == p.hasta) ya = true;
					if (!ya && h2.cnt[id] <= P.tope_bloque) {
						h2.ef++;
						h2.vis[id].push_back(p.hasta);
						if (h2.vis[id].size() == 1) h2.tocados++;
					}
				}
				trazas.push_back({nodo.traza, p.a});
				h2.traza = (int)trazas.size() - 1;
				Sim ps;
				cargar(ps, h2.e, P.h);
				double puntaje = 6.0 * h2.ef + 20.0 * h2.tocados - 0.5 * ps.py + (double)(rng() % 1000) / 1000.0 * P.ruido - (ps.colgando() ? 2.0 : 0.0);
				if (es_inicio(ps) && h2.ef >= P.min_ef && h2.tocados >= P.min_dist) cands.push_back({puntaje, h2.e, h2.traza});
				if (!P.exacto && h2.ef >= P.min_ef && h2.tocados >= P.min_dist) pool.push_back({puntaje, h2.e});
				sig.push_back({puntaje, std::move(h2)});
			}
		}
		if (getenv("SALAS_LOG")) fprintf(stderr, "nivel %d: candidatos %zu, capa %zu, iniciales %zu\n", nivel, sig.size(), capa.size(), cands.size());
		if (sig.empty()) break;
		sort(sig.begin(), sig.end(), [](const pair<double, NodoH>& a, const pair<double, NodoH>& b) { return a.first > b.first; });
		if (P.exacto) {
			// se evalúan con el solucionador exacto los mejores por el puntaje barato; se queda el haz con los que están más lejos de ganar
			if ((int)sig.size() > P.pre) sig.resize(P.pre);
			for (auto& q : sig) {
				Resolucion r = evaluar_sala(q.second.e, P, P.tope_nivel);
				double v;
				if (r.ok) v = r.moves + 3.0 * r.agarres + P.wd * r.distintos;
				else v = 40.0 + 1.5 * (nivel + 1);   // (sin presupuesto: se supone difícil)
				q.first = v + (double)(rng() % 1000) / 1000.0 * 2.0;
				for (auto& cd : cands) if (cd.traza == q.second.traza) cd.puntaje = q.first;
				// variante con el jugador puesto sobre el bloque de entrada (el checkpoint del nivel 1): es el estado con el que se arrancaría
				static int c_gate = 0, c_ok = 0, c_fail = 0, c_tope = 0;
				if (q.second.ef >= P.min_ef && q.second.tocados >= P.min_dist) {
					c_gate++;
					Sim ts;
					cargar(ts, q.second.e, P.h);
					int pc = -1;
					for (int i = 0; i < ts.lim && i < GZ * GX * 2; i++) if (ts.g[i] == CP && iy(i) == 1) pc = i;
					if (pc >= 0 && !ts.hay(ix(pc), 2, iz(pc))) {
						ts.px = ix(pc); ts.py = 2; ts.pz = iz(pc); ts.hx = 0; ts.hz = 0;
						Estado te; guardar(ts, te);
						Resolucion r2 = evaluar_sala(te, P, P.tope_nivel);
						if (r2.ok) { c_ok++; cands.push_back({r2.moves + 3.0 * r2.agarres + P.wd * r2.distintos, te, -1}); } else if (r2.tope) c_tope++; else c_fail++;
					}
				}
				if (getenv("SALAS_LOG") && (c_gate % 20 == 1)) fprintf(stderr, "  teleport: gate %d ok %d fail %d tope %d\n", c_gate, c_ok, c_fail, c_tope);
			}
			sort(sig.begin(), sig.end(), [](const pair<double, NodoH>& a, const pair<double, NodoH>& b) { return a.first > b.first; });
		}
		capa.clear();
		for (int i = 0; i < (int)sig.size() && i < P.ancho; i++) capa.push_back(std::move(sig[i].second));
	}
	if (getenv("SALAS_LOG")) fprintf(stderr, "fin del haz: %zu iniciales (%.1f s)\n", cands.size(), ahora() - t_ini);
	if (!P.exacto && !pool.empty()) {
		// variantes con el jugador puesto sobre la entrada, de los mejores estados por el puntaje barato
		sort(pool.begin(), pool.end(), [](const pair<double, Estado>& a, const pair<double, Estado>& b) { return a.first > b.first; });
		int hechas = 0;
		for (auto& q : pool) {
			if (hechas >= P.evaluar * 2) break;
			Sim ts;
			cargar(ts, q.second, P.h);
			int pc = -1;
			for (int i = 0; i < ts.lim && i < GZ * GX * 2; i++) if (ts.g[i] == CP && iy(i) == 1) pc = i;
			if (pc < 0 || ts.hay(ix(pc), 2, iz(pc))) continue;
			ts.px = ix(pc); ts.py = 2; ts.pz = iz(pc); ts.hx = 0; ts.hz = 0;
			Estado te; guardar(ts, te);
			cands.push_back({q.first, te, -1});
			hechas++;
		}
	}
	if (cands.empty()) return false;
	sort(cands.begin(), cands.end(), [](const Candidata& a, const Candidata& b) { return a.puntaje > b.puntaje; });
	// entre las mejores candidatas se elige la que pide más con el solucionador exacto
	double mejor_valor = -1;
	int mejor = -1;
	Resolucion mejor_res;
	for (int i = 0; i < (int)cands.size() && i < P.evaluar; i++) {
		Resolucion r = evaluar_sala(cands[i].e, P, P.tope_eval);
		if (getenv("SALAS_LOG")) fprintf(stderr, "  candidata %d: ok=%d pasos=%d distintos=%d tope=%d\n", i, (int)r.ok, r.moves, r.distintos, (int)r.tope);
		if (!r.ok) continue;
		double v = r.moves + 3.0 * r.agarres + P.wd * r.distintos;
		if (v > mejor_valor) { mejor_valor = v; mejor = i; mejor_res = r; }
	}
	if (mejor < 0) return false;
	if (getenv("SALAS_LOG")) fprintf(stderr, "evaluadas las candidatas (%.1f s)\n", ahora() - t_ini);
	if (P.escalada > 0) {
		Estado actual = cands[mejor].e;
		Resolucion ract = mejor_res;
		double vact = valor_de(ract, P);
		Sim base, cand;
		for (int it = 0; it < P.escalada; it++) {
			cargar(base, actual, P.h);
			if (!mutar(base, P, rng, cand)) continue;
			Estado ce; guardar(cand, ce);
			Resolucion rc = evaluar_sala(ce, P, P.tope_escalada);
			if (!rc.ok) continue;
			double vc = valor_de(rc, P);
			bool acepta = vc >= vact;
			if (!acepta && P.temp > 0.0) acepta = ((double)(rng() % 10000) / 10000.0) < exp((vc - vact) / P.temp);
			if (acepta) { actual = ce; ract = rc; vact = vc; }
		}
		if (getenv("SALAS_LOG")) fprintf(stderr, "escalada terminada (%.1f s)\n", ahora() - t_ini);
		cands[mejor].e = actual;
		cands[mejor].traza = -1;
		mejor_res = ract;
	}
	if (mejor_res.distintos < P.min_distintos_exactos) return false;   // (la exigencia de bloques distintos vale para la sala ya mejorada)
	int armado = -1;
	if (cands[mejor].traza >= 0) { armado = 0; for (int t = cands[mejor].traza; trazas[t].padre >= 0; t = trazas[t].padre) armado++; }
	bool es_exacto = P.h <= P.h_exacto;
	if (!es_exacto && P.refinar > 0) {
		Resolucion rx = resolver(cands[mejor].e, P.h, (int)P.refinar, true, -1, mejor_res.moves);
		if (rx.ok) { mejor_res = rx; es_exacto = true; }
	}
	Metricas mt;
	if (P.riesgo && es_exacto) medir(cands[mejor].e, P.h, mejor_res.acc, 60000, mt);
	salida = sala_json(P, cands[mejor].e, mejor_res, armado, es_exacto, mt);
	return true;
}

static int resolver_main() {
	Sim base;
	base.limpiar();
	int alto = 8, tope = 1500000;
	int jx = 0, jy = 2, jz = 0, cx = 0, cz = 0;
	vector<array<int, 4>> bl;
	string linea;
	while (getline(cin, linea)) {
		istringstream ss(linea);
		string w;
		ss >> w;
		if (w == "meta") ss >> alto;
		else if (w == "jugador") ss >> jx >> jy >> jz;
		else if (w == "colgado") { int dy; ss >> cx >> dy >> cz; }
		else if (w == "tope") ss >> tope;
		else if (w == "b") { int x, y, z; string k; ss >> x >> y >> z >> k; bl.push_back({x, y, z, codigo_de(k)}); }
	}
	base.fijar_alto(alto);
	for (auto& b : bl) base.poner(b[0], b[1], b[2], (Kind)b[3]);
	base.px = jx; base.py = jy; base.pz = jz; base.hx = cx; base.hz = cz;
	Estado e0; guardar(base, e0);
	Resolucion r = getenv("SALAS_LONJAS") ? resolver_lonjas(e0, alto, tope, atoi(getenv("SALAS_LONJAS"))) : resolver(e0, alto, tope);
	if (r.ok) {
		printf("RESULT ok %d %ld %zu %d %d\n", r.moves, r.expandidos, r.nodos, r.agarres, r.distintos);
		printf("PATH");
		for (int a : r.acc) printf(" %d %d %d", DIRS[a % 4].x, DIRS[a % 4].z, a / 4);
		printf("\n");
	} else {
		printf("RESULT %s %ld %zu\n", r.tope ? "budget" : "fail", r.expandidos, r.nodos);
	}
	return 0;
}

static bool leer_sala(Estado& e0, int& meta, int& tope) {
	Sim base;
	base.limpiar();
	meta = 8; tope = 1500000;
	int jx = 0, jy = 2, jz = 0, cx = 0, cz = 0;
	vector<array<int, 4>> bl;
	string linea;
	while (getline(cin, linea)) {
		istringstream ss(linea);
		string w;
		ss >> w;
		if (w == "meta") ss >> meta;
		else if (w == "jugador") ss >> jx >> jy >> jz;
		else if (w == "colgado") { int dy; ss >> cx >> dy >> cz; }
		else if (w == "tope") ss >> tope;
		else if (w == "b") { int x, y, z; string k; ss >> x >> y >> z >> k; bl.push_back({x, y, z, codigo_de(k)}); }
	}
	base.fijar_alto(meta);
	for (auto& b : bl) base.poner(b[0], b[1], b[2], (Kind)b[3]);
	base.px = jx; base.py = jy; base.pz = jz; base.hx = cx; base.hz = cz;
	guardar(base, e0);
	return !bl.empty();
}

static long arg_largo(int argc, char** argv, const char* clave, long def) {
	string k = string(clave) + "=";
	for (int i = 2; i < argc; i++) { string a = argv[i]; if (a.rfind(k, 0) == 0) return atol(a.c_str() + k.size()); }
	return def;
}

// --medir [tope=N] [tope_hijo=N]: lee una sala (texto) y escribe sus métricas de complejidad (JSON, una línea).
static int medir_main(int argc, char** argv) {
	Estado e0; int meta, tope;
	leer_sala(e0, meta, tope);
	tope = (int)arg_largo(argc, argv, "tope", tope);
	long tope_hijo = arg_largo(argc, argv, "tope_hijo", 60000);
	Resolucion r = resolver(e0, meta, tope);
	if (!r.ok) { printf("{\"ok\":false,\"tope\":%s,\"cota_inferior\":%d}\n", r.tope ? "true" : "false", r.cota); return 0; }
	Metricas m;
	medir(e0, meta, r.acc, tope_hijo, m);
	printf("{\"ok\":true,\"pasos\":%d,\"agarres\":%d,\"distintos\":%d,%s,\"nodos\":%zu}\n", r.moves, r.agarres, r.distintos, metricas_json(m).c_str(), r.nodos);
	return 0;
}

// --minimo [ub=N] [tope=N]: busca el camino más corto REAL de una sala (texto) sin pasar de la cota superior `ub` (un camino conocido).
// Escribe { minimo, cota_inferior, cota_superior, exacto }: si el tope de nodos no alcanza, `cota_inferior` es una cota demostrada
// (el menor f que quedaba abierto en el A*) y el mínimo está entre las dos.
static int minimo_main(int argc, char** argv) {
	Estado e0; int meta, tope;
	leer_sala(e0, meta, tope);
	int ub = (int)arg_largo(argc, argv, "ub", 1 << 28);
	long tope_largo = arg_largo(argc, argv, "tope", tope);
	Resolucion r = arg_largo(argc, argv, "compacto", 1) ? resolver_compacto(e0, meta, tope_largo, ub) : resolver(e0, meta, tope, true, -1, ub);
	if (r.ok) {
		printf("{\"exacto\":true,\"minimo\":%d,\"cota_inferior\":%d,\"cota_superior\":%d,\"agarres\":%d,\"distintos\":%d,\"nodos\":%zu,\"camino\":%s}\n", r.moves, r.moves, ub < (1 << 28) ? ub : r.moves, r.agarres, r.distintos, r.nodos, camino_json(r.acc).c_str());
	} else if (r.tope) {
		printf("{\"exacto\":false,\"minimo\":null,\"cota_inferior\":%d,\"cota_superior\":%d,\"nodos\":%zu}\n", r.cota, ub < (1 << 28) ? ub : -1, r.nodos);
	} else {
		// se agotó el espacio sin encontrar nada de a lo sumo `ub`: no hay camino mejor que el conocido (si ub es un camino real, es el mínimo)
		printf("{\"exacto\":%s,\"minimo\":%d,\"cota_inferior\":%d,\"cota_superior\":%d,\"nodos\":%zu,\"nota\":\"sin camino de a lo sumo ub: el camino conocido es el mínimo\"}\n", ub < (1 << 28) ? "true" : "false", ub < (1 << 28) ? ub : -1, ub < (1 << 28) ? ub : -1, ub < (1 << 28) ? ub : -1, r.nodos);
	}
	return 0;
}

// --conocido [tope_lonja=N] [ventana=N] [tope_bfs=N]: el mejor camino que se consigue sin demostrar nada: lonjas de 3, 4, 5 y 6 pisos, cada una acortada por
// ventanas, y se queda con el más corto (en las pruebas queda entre 0% y 7% sobre el mínimo demostrado). JSON de una línea.
static int conocido_main(int argc, char** argv) {
	Estado e0; int meta, tope;
	leer_sala(e0, meta, tope);
	long tope_lonja = arg_largo(argc, argv, "tope_lonja", 300000);
	int ventana = (int)arg_largo(argc, argv, "ventana", 8);
	long tope_bfs = arg_largo(argc, argv, "tope_bfs", 30000);
	vector<int> mejor;
	int mejor_salto = 0, primero = 0;
	for (int salto = 3; salto <= 6; salto++) {
		Resolucion r = resolver_lonjas(e0, meta, (int)tope_lonja, salto);
		if (!r.ok) continue;
		if (!primero) primero = r.moves;
		vector<int> acc = acortar(e0, meta, r.acc, ventana, tope_bfs);
		if (acc.empty()) acc = r.acc;
		if (mejor.empty() || acc.size() < mejor.size()) { mejor = acc; mejor_salto = salto; }
	}
	if (mejor.empty()) { printf("{\"ok\":false}\n"); return 0; }
	int ag = 0, di = 0;
	estadisticas(e0, meta, mejor, ag, di);
	printf("{\"ok\":true,\"lonjas\":%d,\"mejor\":%d,\"salto\":%d,\"agarres\":%d,\"distintos\":%d,\"camino\":%s}\n", primero, (int)mejor.size(), mejor_salto, ag, di, camino_json(mejor).c_str());
	return 0;
}

// Celdas (del estado inicial) de los bloques que el jugador mueve a lo largo de un camino: la identidad viaja con el bloque.
static vector<int> celdas_movidas(const Estado& e0, int meta, const vector<int>& acc) {
	Sim r;
	cargar(r, e0, meta);
	r.track = true;
	r.ids.assign(NC, 0);
	for (int i = 0; i < NC; i++) if (r.g[i] != NONE) r.ids[i] = (int16_t)i;
	vector<uint8_t> movido(NC, 0);
	for (int a : acc) {
		r.actuar(DIRS[a % 4].x, DIRS[a % 4].z, a / 4);
		if (a / 4 == 1) for (auto& m : r.mov_jugador) { int id = (uint16_t)r.ids[m.second]; if (id < NC) movido[id] = 1; }
	}
	vector<int> out;
	for (int i = 0; i < NC; i++) if (movido[i]) out.push_back(i);
	return out;
}

static string arg_texto(int argc, char** argv, const char* clave, const string& def) {
	string k = string(clave) + "=";
	for (int i = 2; i < argc; i++) { string a = argv[i]; if (a.rfind(k, 0) == 0) return a.substr(k.size()); }
	return def;
}

// ---------------------------------------------------------------------------------------------------------------------------------
// Especialización por propósito (ver docs/plan_generador_especiales.md): segundo paso sobre una sala ya generada.
//   --especializar rol=pesado|pinchos|agrietado|hielo|trampolin [tipo=3x3] [max=4] [ganancia=2] [tope=200000] [wd=12] [seed=1]   (la sala por la entrada, en texto)
// Cada rol pone el especial donde le cambia el paso más barato a la solución, vuelve a resolver con el solucionador exacto, y sólo lo acepta si cumple su papel
// (ver `acepta`); al final cada especial pasa la prueba de necesidad (volverlo común cambia el resultado).
// ---------------------------------------------------------------------------------------------------------------------------------

struct Uso {
	vector<int> movidas;   // celdas (del estado inicial) de los bloques que el jugador movió
	vector<int> pisadas;   // celdas (del estado inicial) de los bloques sobre los que estuvo parado
	int saltos = 0;        // acciones en las que el jugador subió 3 o más pisos de golpe (catapulta)
	int deslizamientos = 0;   // acciones en las que algo se movió 2 o más celdas de golpe (hielo)
};

// Resolver una sala para especializarla: exacto hasta 10 pisos y por lonjas de 3 pisos más arriba (válido, no necesariamente el más corto).
static Resolucion resolver_sala(const Estado& e, int meta, int tope) {
	if (meta <= 10) return resolver(e, meta, tope);
	return resolver_lonjas(e, meta, tope, 3);
}

static double valor_sala(const Resolucion& r) { return r.moves + 3.0 * r.agarres + 12.0 * r.distintos; }

static Uso usos_del_camino(const Estado& e0, int meta, const vector<int>& acc) {
	Uso u;
	Sim r;
	cargar(r, e0, meta);
	r.track = true;
	r.ids.assign(NC, 0);
	for (int i = 0; i < NC; i++) if (r.g[i] != NONE) r.ids[i] = (int16_t)i;
	vector<uint8_t> mov(NC, 0), pis(NC, 0);
	for (int a : acc) {
		int py0 = r.py, px0 = r.px, pz0 = r.pz;
		r.actuar(DIRS[a % 4].x, DIRS[a % 4].z, a / 4);
		if (r.py - py0 >= 3) u.saltos++;
		bool desliza = max(abs(r.px - px0), abs(r.pz - pz0)) >= 2;
		if (a / 4 == 1) for (auto& m : r.mov_jugador) {
			int id = (uint16_t)r.ids[m.second];
			if (id < NC) mov[id] = 1;
			if (abs(ix(m.second) - ix(m.first)) + abs(iz(m.second) - iz(m.first)) >= 2) desliza = true;
		}
		if (desliza) u.deslizamientos++;
		if (!r.colgando() && r.hay(r.px, r.py - 1, r.pz)) { int id = (uint16_t)r.ids[idx(r.px, r.py - 1, r.pz)]; if (id < NC) pis[id] = 1; }
	}
	for (int i = 0; i < NC; i++) { if (mov[i]) u.movidas.push_back(i); if (pis[i]) u.pisadas.push_back(i); }
	return u;
}

// Rol bomba: obliga a jugar lo más eficiente posible dentro de su zona (desactivarla pisándola o tirándola al vacío, o pasar antes de que explote).
// Para cada bloque común que el camino pisa o mueve se busca la MECHA MÍNIMA con la que la sala todavía se resuelve (búsqueda binaria: más mecha
// nunca quita soluciones) y se queda con la bomba que más aprieta: la que sube más la fracción de movimientos letales a lo largo del camino.
// Prueba de necesidad: con la bomba vuelta un común el resultado o la fracción letal cambian.
static int bomba_rol(const Estado& e0, int meta, const Resolucion& base, int tope_eval, const string& tipo, mt19937_64& rng) {
	auto error = [&](const char* msg) { printf("{\"ok\":false,\"error\":\"%s\"}\n", msg); return 0; };
	auto letales_de = [&](const Estado& e, const Resolucion& r, int& legales) {
		int leg = 0, let = 0;
		riesgo(e, meta, r.acc, 4000, leg, let);
		legales = leg;
		return let;
	};
	Uso uso = usos_del_camino(e0, meta, base.acc);
	vector<int> cand = uso.pisadas;
	for (int c : uso.movidas) cand.push_back(c);
	sort(cand.begin(), cand.end());
	cand.erase(unique(cand.begin(), cand.end()), cand.end());
	shuffle(cand.begin(), cand.end(), rng);
	int leg0 = 0, let0 = letales_de(e0, base, leg0);
	double frac0 = leg0 > 0 ? (double)let0 / leg0 : 0.0;
	const int MECHA_MAX = 40;
	double mejor = -1e9; int mejor_celda = -1, mejor_mecha = 0;
	Resolucion mejor_res; Estado mejor_estado;
	int probadas = 0;
	for (int c : cand) {
		if (probadas >= 8) break;
		Sim t; cargar(t, e0, meta);
		if (t.g[c] != N) continue;
		probadas++;
		auto con_mecha = [&](int f, Estado& ne) { Sim u; cargar(u, e0, meta); u.g[c] = (uint8_t)(BOMBA0 + f); guardar(u, ne); return resolver_sala(ne, meta, tope_eval); };
		Estado ne; Resolucion rmax = con_mecha(MECHA_MAX, ne);
		if (!rmax.ok) continue;
		int lo = 1, hi = MECHA_MAX;   // la menor mecha con solución
		while (lo < hi) { int m = (lo + hi) / 2; Estado tmp; if (con_mecha(m, tmp).ok) hi = m; else lo = m + 1; }
		if (lo < 3) continue;   // una mecha de 1 o 2 sólo se esquiva sin tocar la zona: no obliga a nada
		Estado nb; Resolucion r = con_mecha(lo, nb);
		if (!r.ok) continue;
		// la solución tiene que pasar tiempo dentro de la zona (si no, la bomba no aprieta)
		int dentro_zona = 0;
		{
			Sim sim; cargar(sim, nb, meta);
			for (int a : r.acc) {
				sim.actuar(DIRS[a % 4].x, DIRS[a % 4].z, a / 4);
				if (en_zona(ix(c), iy(c), iz(c), sim.px, sim.py, sim.pz)) dentro_zona++;
			}
		}
		if (dentro_zona < 3) continue;
		int leg = 0; int let = letales_de(nb, r, leg);
		double frac = leg > 0 ? (double)let / leg : 0.0;
		double puntaje = (frac - frac0) * 100.0 + (valor_sala(r) - valor_sala(base)) * 0.1;
		if (puntaje > mejor) { mejor = puntaje; mejor_celda = c; mejor_mecha = lo; mejor_res = r; mejor_estado = nb; }
	}
	if (mejor_celda < 0) return error("ninguna bomba cumplió su papel");
	// prueba de necesidad: con la bomba común cambia el camino o cuánto pesa cada movimiento
	{
		Sim u; cargar(u, mejor_estado, meta);
		u.g[mejor_celda] = N;
		Estado ne; guardar(u, ne);
		Resolucion r = resolver_sala(ne, meta, tope_eval);
		bool distinto = !r.ok || r.moves != mejor_res.moves || r.distintos != mejor_res.distintos;
		if (!distinto) {
			int leg = 0; int let = letales_de(ne, r, leg);
			double f = leg > 0 ? (double)let / leg : 0.0;
			int leg2 = 0; int let2 = letales_de(mejor_estado, mejor_res, leg2);
			double f2 = leg2 > 0 ? (double)let2 / leg2 : 0.0;
			if (fabs(f2 - f) >= 0.005) distinto = true;
		}
		if (!distinto) return error("la bomba es decorativa");
	}
	Metricas mt;
	medir(mejor_estado, meta, mejor_res.acc, 60000, mt);
	Param P; P.tipo = tipo; P.h = meta;
	string js = sala_json(P, mejor_estado, mejor_res, -1, true, mt);
	js.pop_back();
	char buf[64];
	snprintf(buf, sizeof(buf), "%.0f", mejor);
	js += ",\"rol\":\"bomba\",\"especiales\":{\"b\":1},\"mecha\":" + to_string(mejor_mecha) + ",\"necesarios\":1,\"ganancias\":[" + buf + "]}";
	printf("%s\n", js.c_str());
	return 0;
}

static int especializar_main(int argc, char** argv) {
	Estado e0; int meta, tope;
	leer_sala(e0, meta, tope);
	string rol = arg_texto(argc, argv, "rol", "pesado");
	string tipo = arg_texto(argc, argv, "tipo", "3x3");
	int maximo = (int)arg_largo(argc, argv, "max", 4);
	double ganancia = (double)arg_largo(argc, argv, "ganancia", 2);
	long tope_eval = arg_largo(argc, argv, "tope", 200000);
	double wd = (double)arg_largo(argc, argv, "wd", 12);
	int ahorro_min = (int)arg_largo(argc, argv, "salto", 18);   // trampolín: sin él la sala no se resuelve o cuesta al menos tantos pasos más
	mt19937_64 rng((unsigned long long)arg_largo(argc, argv, "seed", 1));
	auto error = [&](const char* msg) { printf("{\"ok\":false,\"error\":\"%s\"}\n", msg); return 0; };
	Kind especial; char letra;
	if (rol == "pesado") { especial = H; letra = 'h'; }
	else if (rol == "pinchos") { especial = S; letra = 's'; }
	else if (rol == "agrietado") { especial = C; letra = 'c'; }
	else if (rol == "hielo") { especial = I; letra = 'i'; }
	else if (rol == "trampolin") { especial = K; letra = 'k'; }
	else if (rol == "bomba") { especial = N; letra = 'b'; }
	else return error("rol desconocido");
	Resolucion base = resolver_sala(e0, meta, (int)tope_eval);
	if (!base.ok) return error("la sala base no se resolvió");
	if (rol == "bomba") return bomba_rol(e0, meta, base, (int)tope_eval, tipo, rng);
	auto valor = [&](const Resolucion& r) { return r.moves + 3.0 * r.agarres + wd * r.distintos; };
	// riesgo barato: movimientos letales a lo largo del camino (para pinchos, agrietado y hielo)
	auto letales_de = [&](const Estado& e, const Resolucion& r, int& legales) {
		int leg = 0, let = 0;
		riesgo(e, meta, r.acc, 4000, leg, let);   // (tope chico por hijo: lo que no se resuelve enseguida no se cuenta como letal)
		legales = leg;
		return let;
	};
	// hielo: la línea mide entre 1 y 6 celdas según el tamaño de la sala (3x3 hasta 3, 5x3 hasta 5, 8x3 hasta 6) y cada sala sortea su largo
	int largo_hielo = 1;
	if (rol == "hielo") {
		int tope_largo = tipo == "3x3" ? 3 : tipo == "5x3" ? 5 : 6;
		largo_hielo = 1 + (int)(rng() % (unsigned long long)tope_largo);
		if (getenv("SALAS_LARGO")) largo_hielo = atoi(getenv("SALAS_LARGO"));   // (para probar)
		maximo = max(maximo, largo_hielo);
	}
	int n_hielo = 0;
	unordered_set<int> previo;   // celdas del mismo tipo que ya había (en una sala mixta los especiales de los pasos anteriores no se tocan ni se prueban)
	{ Sim t0; cargar(t0, e0, meta); for (int i : t0.cel) if (t0.g[i] == especial) previo.insert(i); }
	Estado actual = e0;
	Resolucion res = base;
	vector<int> elegidos;      // celdas (en el estado de partida) de los especiales
	vector<double> ganancias;
	int legales0 = 0;
	int letales_actual = (rol == "pesado" || rol == "trampolin") ? 0 : letales_de(actual, res, legales0);
	double frac_actual = legales0 > 0 ? (double)letales_actual / legales0 : 0.0;
	for (int ronda = 0; ronda < maximo; ronda++) {
		Uso uso = usos_del_camino(actual, meta, res.acc);
		vector<int> cand = (rol == "pesado" || rol == "hielo") ? uso.movidas : uso.pisadas;
		if (rol == "hielo") for (int c : uso.pisadas) cand.push_back(c);
		sort(cand.begin(), cand.end());
		cand.erase(unique(cand.begin(), cand.end()), cand.end());
		shuffle(cand.begin(), cand.end(), rng);
		// opciones: grupos de celdas que se vuelven especial a la vez (el hielo va en LÍNEA: de a dos al principio y después se alarga la misma línea)
		vector<vector<int>> opciones;
		if (rol == "hielo") {
			Sim t0; cargar(t0, actual, meta);
			vector<int> hielos;
			for (int i : t0.cel) if (t0.g[i] == I && !previo.count(i)) hielos.push_back(i);
			const int dxs[4] = {1, -1, 0, 0}, dzs[4] = {0, 0, 1, -1};
			auto vecina = [&](int c, int k) {
				int x = ix(c) + dxs[k], z = iz(c) + dzs[k];
				if (abs(x) > 8 || abs(z) > 8) return -1;
				int n = idx(x, iy(c), z);
				if (t0.g[n] == N) return n;
				// una celda vacía dentro de la huella también sirve (el cubo de hielo nuevo queda pegado a la línea, así que se sostiene): si no, las líneas largas
				// dependen de que la sala ya tenga bloques en fila, y casi nunca los tiene
				int hx0, hz0, hw, hd;
				huella(tipo, hx0, hz0, hw, hd);
				if (t0.g[n] == NONE && x >= hx0 && x < hx0 + hw && z >= hz0 && z < hz0 + hd && iy(c) >= 2 && iy(c) <= meta - 1 && n != idx(t0.px, t0.py, t0.pz)) return n;
				return -1;
			};
			n_hielo = (int)hielos.size();
			if (n_hielo >= largo_hielo) break;   // (la línea ya tiene el largo que le tocó)
			if (hielos.empty() && largo_hielo == 1) {
				for (int c : cand) opciones.push_back({c});
			} else if (hielos.empty()) {
				for (int c : cand) for (int k = 0; k < (largo_hielo > 3 ? 2 : 4); k++) { int n = vecina(c, k); if (n >= 0) opciones.push_back({c, n}); }   // (las líneas de más de 3 van a lo largo de la sala: en el ancho de 3 no entran)
			} else {
				for (int h : hielos) for (int k = 0; k < 4; k++) {
					int n = vecina(h, k);
					if (n < 0) continue;
					bool misma_x = true, misma_z = true;
					for (int o : hielos) { if (ix(o) != ix(n)) misma_x = false; if (iz(o) != iz(n)) misma_z = false; }
					if (misma_x || misma_z) opciones.push_back({n});
				}
			}
			shuffle(opciones.begin(), opciones.end(), rng);
			if (opciones.size() > 40) opciones.resize(40);
		} else {
			for (int c : cand) opciones.push_back({c});
		}
		double mejor_puntaje = -1e9;
		int mejor_celda = -1;
		Resolucion mejor_res;
		Estado mejor_estado;
		double mejor_frac = frac_actual;
		int con_riesgo = 0;   // cuántos candidatos se evaluaron con el riesgo (es lo caro): como mucho 5 por ronda
		for (auto& grupo : opciones) {
			int c = grupo[0];
			if (con_riesgo >= 5 && (rol == "agrietado" || rol == "hielo")) break;
			Sim t;
			cargar(t, actual, meta);
			bool todos_comunes = true;
			for (int o : grupo) if (t.g[o] != N && !(rol == "hielo" && t.g[o] == NONE)) todos_comunes = false;
			if (!todos_comunes) continue;   // (sólo se cambian los comunes -el hielo también puede ocupar una celda vacía-: no la entrada, la salida ni otro especial)
			for (int o : grupo) t.poner(ix(o), iy(o), iz(o), especial);
			Estado ne; guardar(t, ne);
			Resolucion r = resolver_sala(ne, meta, (int)tope_eval);
			static int c_prob = 0, c_sinsol = 0;
			c_prob++;
			if (!r.ok) { c_sinsol++; if (getenv("SALAS_LOG") && n_hielo > 0) fprintf(stderr, "  ext: sin solución\n"); if (getenv("SALAS_LOG") && c_prob % 10 == 0) fprintf(stderr, "  candidatos %d, sin solución %d\n", c_prob, c_sinsol); continue; }   // no puede dejar la sala sin solución
			double g = valor(r) - valor(res);
			double puntaje = g;
			double frac = frac_actual;
			if (rol == "pinchos") {
				if (g < ganancia) continue;   // los pinchos tienen que obligar a rodear: la solución tiene que costar más
			} else if (rol == "pesado") {
				if (g < ganancia) continue;
			} else if (rol == "agrietado") {
				// que cada decisión pese: sube la fracción de movimientos letales a lo largo del camino
				con_riesgo++;
				int leg = 0; int let = letales_de(ne, r, leg);
				frac = leg > 0 ? (double)let / leg : 0.0;
				puntaje = (frac - frac_actual) * 100.0;
				if (puntaje < 0.5) continue;
			} else if (rol == "hielo") {
				// que la solución USE un deslizamiento (transporte) y que haya algún resbalón letal más que antes
				// (al ALARGAR una línea que ya cumplió su papel alcanza con que se siga usando y el riesgo no baje: si no, casi nunca pasan de dos cubos)
				Uso u2 = usos_del_camino(ne, meta, r.acc);
				if (u2.deslizamientos < 1) { if (getenv("SALAS_LOG") && n_hielo > 0) fprintf(stderr, "  ext: sin deslizamiento\n"); continue; }
				con_riesgo++;
				int leg = 0; int let = letales_de(ne, r, leg);
				frac = leg > 0 ? (double)let / leg : 0.0;
				if (getenv("SALAS_LOG") && n_hielo > 0) fprintf(stderr, "  ext: frac %.4f contra %.4f (n_hielo %d)\n", frac, frac_actual, n_hielo);
				if (n_hielo == 0 && frac <= frac_actual) continue;   // (al alargar la línea no se pide que suba el riesgo: la línea entera tiene que ser necesaria, y eso se prueba al final)
				puntaje = 10.0 * u2.deslizamientos + (frac - frac_actual) * 100.0;
			} else if (rol == "trampolin") {
				Uso u2 = usos_del_camino(ne, meta, r.acc);
				if (u2.saltos < 1) continue;   // la solución tiene que saltar
				puntaje = 100.0 - (valor(res) - valor(r));   // (se prefiere el salto que MENOS ahorra: el más tardío, para que el camino hasta el trampolín siga costando)
			}
			if (puntaje > mejor_puntaje) { mejor_puntaje = puntaje; mejor_celda = c; mejor_res = r; mejor_estado = ne; mejor_frac = frac; }
		}
		if (mejor_celda < 0) break;
		actual = mejor_estado;
		res = mejor_res;
		frac_actual = mejor_frac;
		elegidos.push_back(mejor_celda);
		ganancias.push_back(mejor_puntaje);
		if (rol == "trampolin") {
			// para que el salto sea NECESARIO: mientras la sala se resuelva sin el trampolín (con la catapulta vuelta un común), se le saca un bloque
			// que usaba ESE camino de escalera, siempre que con el trampolín siga teniendo solución
			for (int vuelta = 0; vuelta < 20; vuelta++) {
				Sim ta; cargar(ta, actual, meta);
				for (int i : ta.cel) if (ta.g[i] == K) ta.g[i] = N;
				Estado sin_k; guardar(ta, sin_k);
				Resolucion rn = resolver_sala(sin_k, meta, (int)tope_eval);
				if (!rn.ok) break;   // sin el trampolín no se resuelve: es necesario
				Uso un = usos_del_camino(sin_k, meta, rn.acc);
				vector<int> quitables;
				for (int c : un.pisadas) if (ta.g[c] == N) quitables.push_back(c);
				for (int c : un.movidas) if (ta.g[c] == N) quitables.push_back(c);
				sort(quitables.begin(), quitables.end());
				quitables.erase(unique(quitables.begin(), quitables.end()), quitables.end());
				shuffle(quitables.begin(), quitables.end(), rng);
				bool quito = false;
				for (int c : quitables) {
					Sim t; cargar(t, actual, meta);
					t.g[c] = NONE; t.cel.clear(); for (int i = 0; i < t.lim; i++) if (t.g[i] != NONE) t.cel.push_back(i);
					if (!estable(t)) continue;
					Estado ne; guardar(t, ne);
					Resolucion r = resolver_sala(ne, meta, (int)tope_eval);
					if (!r.ok) continue;
					actual = ne; res = r; quito = true;
					break;
				}
				if (!quito) break;
			}
			{
				Sim ta; cargar(ta, actual, meta);
				for (int i : ta.cel) if (ta.g[i] == K) ta.g[i] = N;
				Estado sin_k; guardar(ta, sin_k);
				Resolucion rn = resolver_sala(sin_k, meta, (int)tope_eval);
				if (rn.ok && rn.moves < res.moves + ahorro_min) return error("el trampolín ahorra poco");
			}
			break;   // (un trampolín por sala)
		}
	}
	if (elegidos.empty()) return error("ningún especial cumplió su papel");
	// prueba de necesidad: cada especial vuelto común tiene que cambiar el resultado
	int necesarios = 0;
	{
		Estado ref = actual;
		for (int idx0 : elegidos) {
			// (la celda de partida puede haber cambiado de lugar si el bloque se movía: se busca por tipo)
			(void)idx0;
		}
		Sim t; cargar(t, actual, meta);
		vector<int> celdas;
		for (int i : t.cel) if (t.g[i] == especial && !previo.count(i)) celdas.push_back(i);
		if (rol == "hielo") n_hielo = (int)celdas.size();
		vector<vector<int>> unidades;
		if (rol == "hielo") unidades.push_back(celdas); else for (int c : celdas) unidades.push_back({c});
		for (auto& unidad : unidades) {
			Sim u; cargar(u, actual, meta);
			for (int c : unidad) u.g[c] = N;
			Estado ne; guardar(u, ne);
			Resolucion r = resolver_sala(ne, meta, (int)tope_eval);
			bool distinto = !r.ok || r.moves != res.moves || r.distintos != res.distintos || fabs(valor(r) - valor(res)) > 0.5;
			if (rol == "trampolin") distinto = !r.ok || r.moves >= res.moves + ahorro_min;
			if (!distinto && r.ok && (rol == "agrietado" || rol == "hielo")) {   // (su efecto no siempre cambia el largo: cambia cuánto pesa cada decisión)
				int leg = 0; int let = letales_de(ne, r, leg);
				double f = leg > 0 ? (double)let / leg : 0.0;
				if (fabs(f - frac_actual) >= 0.005) distinto = true;
			}
			if (distinto) necesarios += (int)unidad.size();
		}
		if (necesarios < (int)celdas.size()) return error("hay especiales decorativos");
	}
	Metricas mt;
	medir(actual, meta, res.acc, 60000, mt);
	Param P; P.tipo = tipo; P.h = meta;
	string js = sala_json(P, actual, res, -1, true, mt);
	js.pop_back();
	char buf[64];
	js += ",\"rol\":\"" + rol + "\",\"especiales\":{\"" + string(1, letra) + "\":" + to_string(rol == "hielo" ? n_hielo : (int)elegidos.size()) + "},\"necesarios\":" + to_string(necesarios) + ",\"ganancias\":[";
	for (size_t i = 0; i < ganancias.size(); i++) { snprintf(buf, sizeof(buf), "%s%.0f", i ? "," : "", ganancias[i]); js += buf; }
	js += "]}";
	printf("%s\n", js.c_str());
	return 0;
}

// --revisar: ¿cada especial de la sala es necesario? Vuelve común cada unidad (un bloque; una línea de hielo entera) y mira si cambia el resultado
// (largo, bloques distintos, valor, o la fracción de movimientos letales; el trampolín: sin solución o mucho más largo).
static int revisar_main(int argc, char** argv) {
	Estado e0; int meta, tope;
	leer_sala(e0, meta, tope);
	int tope_eval = (int)arg_largo(argc, argv, "tope", 100000);
	int ahorro_min = (int)arg_largo(argc, argv, "salto", 18);
	Resolucion res = resolver_sala(e0, meta, tope_eval);
	if (!res.ok) { printf("{\"ok\":false,\"error\":\"no se resuelve\"}\n"); return 0; }
	auto valor = [&](const Resolucion& r) { return r.moves + 3.0 * r.agarres + 12.0 * r.distintos; };
	auto frac_de = [&](const Estado& e, const Resolucion& r) {
		int leg = 0, let = 0;
		riesgo(e, meta, r.acc, 4000, leg, let);
		return leg > 0 ? (double)let / leg : 0.0;
	};
	Sim t; cargar(t, e0, meta);
	vector<vector<int>> unidades;
	vector<int> tipos;
	unordered_set<int> hecho;
	for (int i : t.cel) {
		int k = t.g[i];
		if (k == H || k == S || k == C || k == K || es_bomba(k)) { unidades.push_back({i}); tipos.push_back(k); }
		else if (k == I && !hecho.count(i)) {   // una línea de hielo: las celdas de hielo pegadas (mismo nivel, de a una por lado)
			vector<int> comp, cola = {i};
			hecho.insert(i);
			while (!cola.empty()) {
				int c = cola.back(); cola.pop_back();
				comp.push_back(c);
				const int dxs[4] = {1, -1, 0, 0}, dzs[4] = {0, 0, 1, -1};
				for (int q = 0; q < 4; q++) {
					int x = ix(c) + dxs[q], z = iz(c) + dzs[q];
					if (abs(x) > 8 || abs(z) > 8) continue;
					int n = idx(x, iy(c), z);
					if (t.g[n] == I && !hecho.count(n)) { hecho.insert(n); cola.push_back(n); }
				}
			}
			unidades.push_back(comp); tipos.push_back(I);
		}
	}
	double f0 = frac_de(e0, res);
	int necesarias = 0;
	string det = "[";
	for (size_t u = 0; u < unidades.size(); u++) {
		Sim v; cargar(v, e0, meta);
		for (int c : unidades[u]) v.g[c] = N;
		Estado ne; guardar(v, ne);
		Resolucion r = resolver_sala(ne, meta, tope_eval);
		bool distinto;
		if (tipos[u] == K) distinto = !r.ok || r.moves >= res.moves + ahorro_min;
		else {
			distinto = !r.ok || r.moves != res.moves || r.distintos != res.distintos || fabs(valor(r) - valor(res)) > 0.5;
			if (!distinto && r.ok && fabs(frac_de(ne, r) - f0) >= 0.005) distinto = true;
		}
		if (distinto) necesarias++;
		det += string(u ? "," : "") + (distinto ? "true" : "false");
	}
	det += "]";
	printf("{\"ok\":true,\"unidades\":%d,\"necesarias\":%d,\"detalle\":%s}\n", (int)unidades.size(), necesarias, det.c_str());
	return 0;
}

static int generar_main(int argc, char** argv) {
	Param P;
	for (int i = 2; i < argc; i++) {
		string a = argv[i];
		size_t eq = a.find('=');
		if (eq == string::npos) continue;
		string k = a.substr(0, eq), v = a.substr(eq + 1);
		if (k == "tipo") P.tipo = v;
		else if (k == "h") P.h = atoi(v.c_str());
		else if (k == "extras") P.extras = atoi(v.c_str());
		else if (k == "ancho") P.ancho = atoi(v.c_str());
		else if (k == "prof") P.profundidad = atoi(v.c_str());
		else if (k == "tope_bloque") P.tope_bloque = atoi(v.c_str());
		else if (k == "ef") P.min_ef = atoi(v.c_str());
		else if (k == "dist") P.min_dist = atoi(v.c_str());
		else if (k == "evaluar") P.evaluar = atoi(v.c_str());
		else if (k == "tope_eval") P.tope_eval = atol(v.c_str());
		else if (k == "dist_exactos") P.min_distintos_exactos = atoi(v.c_str());
		else if (k == "ruido") P.ruido = atof(v.c_str());
		else if (k == "seed") P.semilla = strtoull(v.c_str(), nullptr, 10);
		else if (k == "n") P.cuantas = atoi(v.c_str());
		else if (k == "cand") P.limite_cand = atoi(v.c_str());
		else if (k == "radio") P.radio = atoi(v.c_str());
		else if (k == "exacto") P.exacto = atoi(v.c_str());
		else if (k == "pre") P.pre = atoi(v.c_str());
		else if (k == "wd") P.wd = atof(v.c_str());
		else if (k == "climb") P.escalada = atoi(v.c_str());
		else if (k == "tope_climb") P.tope_escalada = atol(v.c_str());
		else if (k == "temp") P.temp = atof(v.c_str());
		else if (k == "h_exacto") P.h_exacto = atoi(v.c_str());
		else if (k == "giro") P.giro = atoi(v.c_str());
		else if (k == "salto") P.salto = atoi(v.c_str());
		else if (k == "riesgo") P.riesgo = atoi(v.c_str());
		else if (k == "refinar") P.refinar = atol(v.c_str());
		else if (k == "tope_nivel") P.tope_nivel = atol(v.c_str());
	}
	int hechas = 0, intentos = 0;
	while (hechas < P.cuantas && intentos < P.cuantas * 30) {
		mt19937_64 rng(P.semilla * 1000003ULL + intentos);
		intentos++;
		string salida;
		if (generar_una(P, rng, salida)) {
			printf("%s\n", salida.c_str());
			fflush(stdout);
			hechas++;
		} else {
			fprintf(stderr, "intento %d: sin sala\n", intentos);
		}
	}
	return 0;
}

int main(int argc, char** argv) {
	init_tablas();
	if (argc > 1 && string(argv[1]) == "--gen") return generar_main(argc, argv);
	if (argc > 1 && string(argv[1]) == "--medir") return medir_main(argc, argv);
	if (argc > 1 && string(argv[1]) == "--minimo") return minimo_main(argc, argv);
	if (argc > 1 && string(argv[1]) == "--conocido") return conocido_main(argc, argv);
	if (argc > 1 && string(argv[1]) == "--especializar") return especializar_main(argc, argv);
	if (argc > 1 && string(argv[1]) == "--revisar") return revisar_main(argc, argv);
	return resolver_main();
}
