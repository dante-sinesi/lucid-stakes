// Motor y solucionador de la torre de salas sin núcleo en C++ (port de salas_nuevas/motor.gd + reglas.gd + solucionador.gd).
// Uso: salas_nuevas.exe < entrada.txt   (formato abajo)  ->  salida por stdout.
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

enum Kind : uint8_t { NONE = 0, N = 1, F = 2, H = 3, I = 4, C = 5, T = 6, S = 7, K = 8, CP = 9 };
static Kind kind_de(char c) {
	switch (c) {
		case 'n': return N; case 'f': return F; case 'h': return H; case 'i': return I;
		case 'c': return C; case 't': return T; case 's': return S; case 'k': return K; case 'p': return CP;
	}
	return N;
}

static const int LADO = 11;   // la torre: un anillo de 11 x 11 alrededor de un vacío de 5 x 5

struct V { int x, y, z; };
static const V DIRS[4] = {{1, 0, 0}, {-1, 0, 0}, {0, 0, 1}, {0, 0, -1}};
static vector<V> VECINOS;

static uint64_t ZOB[NC][16];
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
		if (!colgando() && py == alto + 1 && kind(px, py - 1, pz) == CP) ganado = true;
		return true;
	}

};

struct Estado {
	vector<uint32_t> bloques;   // (idx << 4) | kind, ordenado
	int16_t px, py, pz;
	int8_t hx, hz;
};

static void cargar(Sim& s, const Estado& e, int alto) {
	memset(s.g, 0, s.lim);
	s.fijar_alto(alto);
	memset(s.g, 0, s.lim);
	s.cel.clear();
	for (uint32_t b : e.bloques) { s.g[b >> 4] = (uint8_t)(b & 15); s.cel.push_back((int)(b >> 4)); }
	s.px = e.px; s.py = e.py; s.pz = e.pz;
	s.hx = e.hx; s.hy = 0; s.hz = e.hz;
	s.perdido = false; s.ganado = false;
}
static void guardar(const Sim& s, Estado& e) {
	e.bloques.clear();
	for (int i : s.cel) e.bloques.push_back(((uint32_t)i << 4) | s.g[i]);
	e.px = s.px; e.py = s.py; e.pz = s.pz; e.hx = s.hx; e.hz = s.hz;
}
static uint64_t clave_estado(const Estado& e) {
	uint64_t h = 0;
	for (uint32_t b : e.bloques) { int k = b & 15; if (k != F) h ^= ZOB[b >> 4][k]; }
	h ^= ZJ[idx(e.px, e.py, e.pz)] * 31;
	h ^= splitmix(1000 + (e.hx + 2) * 5 + (e.hz + 2)) * 17;
	return h;
}

static uint64_t clave_sim(const Sim& s) {
	uint64_t h = 0;
	for (int i : s.cel) { int k = s.g[i]; if (k != F) h ^= ZOB[i][k]; }
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
	for (uint32_t b : e0.bloques) if ((b & 15) == K) hay_k = true;
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

static string kind_letra(int k) {
	const char* L = "?nfhicstkp";
	return string(1, L[k < 10 ? k : 0]);
}

static string estado_json(const Estado& e) {
	string s = "[";
	bool primero = true;
	for (uint32_t b : e.bloques) {
		int i = b >> 4;
		if (!primero) s += ",";
		primero = false;
		s += "[" + to_string(ix(i)) + "," + to_string(iy(i)) + "," + to_string(iz(i)) + ",\"" + kind_letra(b & 15) + "\"]";
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
		if (cur.g[i] == F) continue;
		int x = ix(i), y = iy(i), z = iz(i);
		if (abs(x - cur.px) > radio || abs(z - cur.pz) > radio || abs(y - cur.py) > 2) continue;
		for (int k = 0; k < 4; k++) {
			int ax = x - DIRS[k].x, az = z - DIRS[k].z;
			if (!dentro(ax, y, az) || cur.hay(ax, y, az)) continue;
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
	long refinar = 2000000;   // en salas altas (por lonjas) se intenta al final el solucionador exacto con este tope de nodos
};

static void huella(const string& tipo, int& x0, int& z0, int& w, int& d) {
	if (tipo == "5x3") { x0 = 3; z0 = 0; w = 5; d = 3; }
	else if (tipo == "8x3") { x0 = 0; z0 = 0; w = 8; d = 3; }
	else { x0 = 0; z0 = 0; w = 3; d = 3; }
}

static bool camino_dfs(mt19937_64& rng, int w, int d, int largo, vector<int>& camino, vector<char>& usado, long& presupuesto) {
	if ((int)camino.size() == largo) return true;
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
		if (camino_dfs(rng, w, d, largo, camino, usado, presupuesto)) return true;
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
	vector<int> camino;
	vector<char> usado(w * d, 0);
	bool ok = false;
	for (int intento = 0; intento < 60 && !ok; intento++) {
		camino.clear();
		fill(usado.begin(), usado.end(), 0);
		int ini = (int)(rng() % (w * d));
		camino.push_back(ini);
		usado[ini] = 1;
		long pres = 30000;
		ok = camino_dfs(rng, w, d, P.h, camino, usado, pres);
	}
	if (!ok) return false;
	out.limpiar();
	out.fijar_alto(P.h);
	for (int k = 0; k < P.h; k++) {
		int cx = x0 + camino[k] % w, cz = z0 + camino[k] / w;
		out.poner(cx, k + 1, cz, (k == 0 || k == P.h - 1) ? CP : N);
	}
	int ex = x0 + camino[P.h - 1] % w, ez = z0 + camino[P.h - 1] / w;
	// el fijo: al lado de la salida, a su misma altura, en una celda libre (hacia afuera si se puede)
	int orden[4] = {0, 1, 2, 3};
	shuffle(orden, orden + 4, rng);
	bool puesto = false;
	for (int q = 0; q < 4 && !puesto; q++) {
		int nx = ex + DIRS[orden[q]].x, nz = ez + DIRS[orden[q]].z;
		if (!out.hay(nx, P.h, nz)) { out.poner(nx, P.h, nz, F); puesto = true; }
	}
	if (!puesto) return false;
	out.px = ex; out.py = P.h + 1; out.pz = ez;
	// extras: pegados a los bloques de la sala, dentro de la huella y un borde de margen, entre los niveles 1 y h
	int puestos = 0;
	for (int intento = 0; intento < P.extras * 120 && puestos < P.extras; intento++) {
		vector<int> celdas;
		for (int i = 0; i < out.lim; i++) if (out.g[i] != NONE && out.g[i] != F) celdas.push_back(i);
		int b = celdas[rng() % celdas.size()];
		int vx = ix(b), vy = iy(b), vz = iz(b);
		int dxs[3] = {-1, 0, 1};
		int nx = vx + dxs[rng() % 3], nz = vz + dxs[rng() % 3], ny = vy + dxs[rng() % 3];
		int ndx = (nx != vx) + (ny != vy) + (nz != vz);
		if (ndx == 0 || ndx == 3) continue;
		if (ndx == 2 && ny == vy) continue;
		if (ny < 1 || ny > P.h || nx < x0 - 1 || nx > x0 + w || nz < z0 - 1 || nz > z0 + d || out.hay(nx, ny, nz)) continue;
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
	s += ",\"armado\":" + to_string(armado) + ",\"exacto\":" + string(exacto ? "true" : "false") + ",\"extras\":" + to_string(P.extras) + ",\"camino\":" + camino_json(r.acc) + "}";
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
	for (int i = 0; i < out.lim; i++) if (out.g[i] != NONE && out.g[i] != F) comunes.push_back(i);
	int tipo = (int)(rng() % 10);
	if (tipo < 7) {   // mover un bloque a otra celda del mismo nivel
		int b = comunes[rng() % comunes.size()];
		int y = iy(b);
		int nx = x0 - 1 + (int)(rng() % (w + 2)), nz = z0 - 1 + (int)(rng() % (d + 2));
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
		if (ny < 1 || ny > P.h || nx < x0 - 1 || nx > x0 + w || nz < z0 - 1 || nz > z0 + d || out.hay(nx, ny, nz)) return false;
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

static bool generar_una(const Param& P, mt19937_64& rng, string& salida) {
	Sim e;
	if (!sala_resuelta(P, rng, e)) return false;
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
				sig.push_back({puntaje, std::move(h2)});
			}
		}
		if (getenv("SN_LOG")) fprintf(stderr, "nivel %d: candidatos %zu, capa %zu, iniciales %zu\n", nivel, sig.size(), capa.size(), cands.size());
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
				if (q.second.ef >= P.min_ef && q.second.tocados >= P.min_dist) {
					Sim ts;
					cargar(ts, q.second.e, P.h);
					int pc = -1;
					for (int i = 0; i < ts.lim && i < GZ * GX * 2; i++) if (ts.g[i] == CP && iy(i) == 1) pc = i;
					if (pc >= 0 && !ts.hay(ix(pc), 2, iz(pc))) {
						ts.px = ix(pc); ts.py = 2; ts.pz = iz(pc); ts.hx = 0; ts.hz = 0;
						Estado te; guardar(ts, te);
						Resolucion r2 = evaluar_sala(te, P, P.tope_nivel);
						if (r2.ok) cands.push_back({r2.moves + 3.0 * r2.agarres + P.wd * r2.distintos, te, -1});
					}
				}
			}
			sort(sig.begin(), sig.end(), [](const pair<double, NodoH>& a, const pair<double, NodoH>& b) { return a.first > b.first; });
		}
		capa.clear();
		for (int i = 0; i < (int)sig.size() && i < P.ancho; i++) capa.push_back(std::move(sig[i].second));
	}
	if (getenv("SN_LOG")) fprintf(stderr, "fin del haz: %zu iniciales\n", cands.size());
	if (cands.empty()) return false;
	sort(cands.begin(), cands.end(), [](const Candidata& a, const Candidata& b) { return a.puntaje > b.puntaje; });
	// entre las mejores candidatas se elige la que pide más con el solucionador exacto
	double mejor_valor = -1;
	int mejor = -1;
	Resolucion mejor_res;
	for (int i = 0; i < (int)cands.size() && i < P.evaluar; i++) {
		Resolucion r = evaluar_sala(cands[i].e, P, P.tope_eval);
		if (getenv("SN_LOG")) fprintf(stderr, "  candidata %d: ok=%d pasos=%d distintos=%d tope=%d\n", i, (int)r.ok, r.moves, r.distintos, (int)r.tope);
		if (!r.ok) continue;
		if (r.distintos < P.min_distintos_exactos) continue;
		double v = r.moves + 3.0 * r.agarres + P.wd * r.distintos;
		if (v > mejor_valor) { mejor_valor = v; mejor = i; mejor_res = r; }
	}
	if (mejor < 0) return false;
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
		cands[mejor].e = actual;
		cands[mejor].traza = -1;
		mejor_res = ract;
	}
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
		else if (w == "b") { int x, y, z; string k; ss >> x >> y >> z >> k; bl.push_back({x, y, z, (int)kind_de(k.empty() ? 'n' : k[0])}); }
	}
	base.fijar_alto(alto);
	for (auto& b : bl) base.poner(b[0], b[1], b[2], (Kind)b[3]);
	base.px = jx; base.py = jy; base.pz = jz; base.hx = cx; base.hz = cz;
	Estado e0; guardar(base, e0);
	Resolucion r = getenv("SN_LONJAS") ? resolver_lonjas(e0, alto, tope, atoi(getenv("SN_LONJAS"))) : resolver(e0, alto, tope);
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
		else if (w == "b") { int x, y, z; string k; ss >> x >> y >> z >> k; bl.push_back({x, y, z, (int)kind_de(k.empty() ? 'n' : k[0])}); }
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
	tope = (int)arg_largo(argc, argv, "tope", tope);
	int ub = (int)arg_largo(argc, argv, "ub", 1 << 28);
	Resolucion r = resolver(e0, meta, tope, true, -1, ub);
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
	return resolver_main();
}
