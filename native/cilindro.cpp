// Motor y solucionador del cilindro en C++ (port de cilindro/motor.gd + cilindro/reglas.gd + cilindro/solucionador.gd).
// Uso: cilindro.exe < entrada.txt   (formato abajo)  ->  salida por stdout.
//
// Entrada (texto, una cosa por línea):
//   alto N
//   jugador X Y Z
//   colgado DX DY DZ        (opcional; 0 0 0 = de pie)
//   tope N                  (opcional: máximo de nodos, por defecto 1500000)
//   b X Y Z K               (un bloque; K = n,f,h,i,c,t,s,k)  ...  (la cima 'f' se pone sola si no hay ninguna)
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
#include <iostream>
#include <sstream>

using namespace std;

static const int GX = 16, GZ = 16, GY = 48;   // x,z en -4..11 (se guarda x+4), y en 0..47
static const int NC = GX * GZ * GY;
static const int OFF = 4;

static inline int idx(int x, int y, int z) { return (y * GZ + (z + OFF)) * GX + (x + OFF); }
static inline int ix(int i) { return (i % GX) - OFF; }
static inline int iz(int i) { return ((i / GX) % GZ) - OFF; }
static inline int iy(int i) { return i / (GX * GZ); }
static inline bool dentro(int x, int y, int z) { return x >= -OFF && x < GX - OFF && z >= -OFF && z < GZ - OFF && y >= 0 && y < GY; }

enum Kind : uint8_t { NONE = 0, N = 1, F = 2, H = 3, I = 4, C = 5, T = 6, S = 7, K = 8 };
static Kind kind_de(char c) {
	switch (c) {
		case 'n': return N; case 'f': return F; case 'h': return H; case 'i': return I;
		case 'c': return C; case 't': return T; case 's': return S; case 'k': return K;
	}
	return N;
}

static bool es_anillo(int x, int z) { return x >= 0 && x < 8 && z >= 0 && z < 8 && (x == 0 || x == 7 || z == 0 || z == 7); }
static bool es_masa(int x, int z) { return x >= 1 && x <= 6 && z >= 1 && z <= 6 && !(x >= 3 && x <= 4 && z >= 3 && z <= 4); }

struct V { int x, y, z; };
static const V DIRS[4] = {{1, 0, 0}, {-1, 0, 0}, {0, 0, 1}, {0, 0, -1}};
static vector<V> VECINOS;

static uint64_t ZOB[NC][9];
static uint64_t ZJ[NC], ZH[8];

static uint64_t splitmix(uint64_t v) {
	v += 0x9E3779B97F4A7C15ULL;
	v = (v ^ (v >> 30)) * 0xBF58476D1CE4E5B9ULL;
	v = (v ^ (v >> 27)) * 0x94D049BB133111EBULL;
	return v ^ (v >> 31);
}

static void init_tablas() {
	for (int i = 0; i < NC; i++) {
		for (int k = 0; k < 9; k++) ZOB[i][k] = splitmix((uint64_t)i * 16 + k + 1);
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
	void fijar_alto(int a) { alto = a; lim = min(NC, (a + 6) * GZ * GX); }

	void limpiar() { memset(g, 0, sizeof(g)); }
	bool hay(int x, int y, int z) const { return dentro(x, y, z) && g[idx(x, y, z)] != NONE; }
	Kind kind(int x, int y, int z) const { return dentro(x, y, z) ? (Kind)g[idx(x, y, z)] : NONE; }
	bool colgando() const { return hx != 0 || hy != 0 || hz != 0; }
	bool solido(int x, int y, int z) const { return hay(x, y, z) || (y == 0 && es_anillo(x, z)); }
	bool en_limites(int x, int y, int z) const { return x >= -3 && x <= 10 && z >= -3 && z <= 10 && y >= 0 && y <= alto + 4; }
	bool en_huella(int x, int y, int z) const { return x >= 0 && x < 8 && z >= 0 && z < 8 && y >= 0; }
	bool alcance_cuelgue(int x, int y, int z) const { return x >= -4 && x <= 11 && z >= -4 && z <= 11 && y >= 0; }

	void poner(int x, int y, int z, Kind k) {
		if (!dentro(x, y, z)) return;
		g[idx(x, y, z)] = k;
		if (track) { if (ids.empty()) ids.assign(NC, 0); ids[idx(x, y, z)] = sig_id++; }
	}
	void quitar(int x, int y, int z) { if (dentro(x, y, z)) g[idx(x, y, z)] = NONE; }

	void mover_bloque(int fx, int fy, int fz, int tx, int ty, int tz, bool del_jugador) {
		int a = idx(fx, fy, fz);
		Kind k = (Kind)g[a];
		g[a] = NONE;
		if (!dentro(tx, ty, tz)) { return; }   // se fue lejísimo: se pierde
		int b = idx(tx, ty, tz);
		g[b] = k;
		if (track) ids[b] = ids[a];
		if (del_jugador) mov_jugador.push_back({a, b});
	}

	// --- sostén ---
	void anclados(vector<uint8_t>& ok) const {
		ok.assign(lim, 0);
		vector<int> cola;
		for (int i = 0; i < lim; i++) if (g[i] != NONE && iy(i) == alto) { ok[i] = 1; cola.push_back(i); }
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
	void sostenidos(vector<uint8_t>& ok) const {
		anclados(ok);
		for (int i = 0; i < lim; i++) {   // (el índice crece con la altura: una sola pasada alcanza)
			if (g[i] == NONE || ok[i]) continue;
			int x = ix(i), y = iy(i), z = iz(i);
			bool apoya = (y == 1 && es_anillo(x, z)) || (y >= 1 && ok[idx(x, y - 1, z)]);
			if (apoya) ok[i] = 1;
		}
	}
	// Devuelve cuántos cayeron + cuántos se perdieron (>0 = hubo cambios)
	int asentar_bloques() {
		int cambios = 0;
		vector<uint8_t>& quietos = quietos_;
		quietos.assign(lim, 0);
		vector<uint8_t>& ok = ok_;
		for (int guardia = 0; guardia < 200; guardia++) {
			sostenidos(ok);
			int s = -1;
			int smin_y = 1000;
			for (int i = 0; i < lim; i++) {
				if (g[i] == NONE || ok[i] || quietos[i]) continue;
				int y = iy(i);
				if (y < smin_y) { smin_y = y; s = i; }
			}
			if (s < 0) break;
			int sx = ix(s), sy = iy(s), sz = iz(s);
			Kind tipo = (Kind)g[s];
			int16_t id = track ? ids[s] : (int16_t)0;
			g[s] = NONE;
			int y = sy;
			bool aterrizo = false;
			while (y > 0) {
				y -= 1;
				bool es_jug = (sx == px && y == py && sz == pz);
				if (es_jug) { aterrizo = true; y += 1; break; }
				int a = idx(sx, y, sz);
				if (g[a] != NONE) {
					// apoya en bloque: sostenido (ok) o no suelto (todo bloque restante que no esté en la lista de sueltos)
					bool suelto = !ok[a] && !quietos[a];   // (como en el motor GDScript: apoya en uno sostenido o que no está entre los sueltos)
					if (!suelto) { aterrizo = true; y += 1; break; }
				}
				if (y == 0 && es_anillo(sx, sz)) { aterrizo = true; y = 1; break; }
			}
			if (aterrizo && y >= 1) {
				int d = idx(sx, y, sz);
				g[d] = tipo;
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
		if (!colgando() && py == alto + 1 && kind(px, py - 1, pz) == F) ganado = true;
		return true;
	}

};

struct Estado {
	vector<uint32_t> bloques;   // (idx << 4) | kind, ordenado
	int16_t px, py, pz;
	int8_t hx, hz;
};

static void cargar(Sim& s, const Estado& e, int alto) {
	s.fijar_alto(alto);
	s.limpiar();
	for (uint32_t b : e.bloques) s.g[b >> 4] = (uint8_t)(b & 15);
	s.px = e.px; s.py = e.py; s.pz = e.pz;
	s.hx = e.hx; s.hy = 0; s.hz = e.hz;
	s.perdido = false; s.ganado = false;
}
static void guardar(const Sim& s, Estado& e) {
	e.bloques.clear();
	for (int i = 0; i < s.lim; i++) if (s.g[i] != NONE) e.bloques.push_back(((uint32_t)i << 4) | s.g[i]);
	e.px = s.px; e.py = s.py; e.pz = s.pz; e.hx = s.hx; e.hz = s.hz;
}
static uint64_t clave_estado(const Estado& e) {
	uint64_t h = 0;
	for (uint32_t b : e.bloques) { int k = b & 15; if (k != F) h ^= ZOB[b >> 4][k]; }
	h ^= ZJ[idx(e.px, e.py, e.pz)] * 31;
	h ^= splitmix(1000 + (e.hx + 2) * 5 + (e.hz + 2)) * 17;
	return h;
}

struct Nodo { Estado e; int padre; uint8_t accion; int g; };

int main(int argc, char** argv) {
	init_tablas();
	Sim base;
	base.limpiar();
	int alto = 8, tope = 1500000;
	int jx = 0, jy = 1, jz = 0, cx = 0, cz = 0;
	vector<array<int, 4>> bl;
	bool hay_cima = false;
	string linea;
	while (getline(cin, linea)) {
		istringstream ss(linea);
		string w;
		ss >> w;
		if (w == "alto") ss >> alto;
		else if (w == "jugador") ss >> jx >> jy >> jz;
		else if (w == "colgado") { int dy; ss >> cx >> dy >> cz; }
		else if (w == "tope") ss >> tope;
		else if (w == "b") { int x, y, z; string k; ss >> x >> y >> z >> k; bl.push_back({x, y, z, (int)kind_de(k.empty() ? 'n' : k[0])}); if (k == "f") hay_cima = true; }
	}
	base.fijar_alto(alto);
	if (!hay_cima) for (int x = 1; x <= 6; x++) for (int z = 1; z <= 6; z++) if (x == 1 || x == 6 || z == 1 || z == 6) base.poner(x, alto, z, F);
	for (auto& b : bl) base.poner(b[0], b[1], b[2], (Kind)b[3]);
	base.px = jx; base.py = jy; base.pz = jz; base.hx = cx; base.hz = cz;
	bool hay_k = false;
	for (int i = 0; i < base.lim; i++) if (base.g[i] == K) hay_k = true;

	auto heur = [&](int py) { int falta = alto + 1 - py; if (falta <= 0) return 0; return hay_k ? (falta + 6) / 7 : falta; };

	vector<Nodo> nodos;
	Estado e0; guardar(base, e0);
	nodos.push_back({e0, -1, 255, 0});
	unordered_map<uint64_t, int> vistos;
	vistos[clave_estado(e0)] = 0;
	vector<vector<int>> cubos(512);
	int f_min = heur(e0.py);
	cubos[f_min].push_back(0);
	int expandidos = 0;
	Sim s;
	int meta = -1;
	while (true) {
		while (f_min < (int)cubos.size() && cubos[f_min].empty()) f_min++;
		if (f_min >= (int)cubos.size()) break;
		int id = cubos[f_min].back(); cubos[f_min].pop_back();
		cargar(s, nodos[id].e, alto);
		int g0 = nodos[id].g;
		// ¿ganado? (se detecta al generar el hijo; el inicial no está ganado)
		expandidos++;
		for (int a = 0; a < 12; a++) {
			int dx = DIRS[a % 4].x, dz = DIRS[a % 4].z, modo = a / 4;
			if (s.colgando() && modo != 0) continue;
			Sim t = s;
			if (!t.actuar(dx, dz, modo)) continue;
			Estado ne; guardar(t, ne);
			uint64_t k = clave_estado(ne);
			int gn = g0 + 1;
			auto it = vistos.find(k);
			if (it != vistos.end() && it->second <= gn) continue;
			vistos[k] = gn;
			nodos.push_back({ne, id, (uint8_t)a, gn});
			int ni = (int)nodos.size() - 1;
			if (t.ganado) { meta = ni; break; }
			int f = gn + heur(t.py);
			if (f >= (int)cubos.size()) cubos.resize(f + 64);
			cubos[f].push_back(ni);
			if (f < f_min) f_min = f;
		}
		if (meta >= 0) break;
		if ((int)nodos.size() > tope) { printf("RESULT budget %d %zu\n", expandidos, nodos.size()); return 0; }
	}
	if (meta < 0) { printf("RESULT fail %d %zu\n", expandidos, nodos.size()); return 0; }
	// camino
	vector<int> acc;
	for (int i = meta; nodos[i].padre >= 0; i = nodos[i].padre) acc.push_back(nodos[i].accion);
	reverse(acc.begin(), acc.end());
	// repetir con identidad para contar agarres y bloques distintos
	Sim r;
	cargar(r, nodos[0].e, alto);
	r.track = true;
	r.ids.assign(NC, 0);
	for (int i = 0; i < NC; i++) if (r.g[i] != NONE) r.ids[i] = (int16_t)i;
	vector<uint8_t> movido(NC, 0);
	int agarres = 0;
	for (int a : acc) {
		int dx = DIRS[a % 4].x, dz = DIRS[a % 4].z, modo = a / 4;
		r.actuar(dx, dz, modo);
		if (modo == 1 && !r.mov_jugador.empty()) {
			agarres++;
			for (auto& m : r.mov_jugador) movido[m.second] = 0;   // (la identidad viaja con ids[])
			for (auto& m : r.mov_jugador) movido[(uint16_t)r.ids[m.second] < NC ? (uint16_t)r.ids[m.second] : 0] = 1;
		}
	}
	int distintos = 0;
	for (int i = 0; i < NC; i++) distintos += movido[i];
	printf("RESULT ok %zu %d %zu %d %d\n", acc.size(), expandidos, nodos.size(), agarres, distintos);
	printf("PATH");
	for (int a : acc) printf(" %d %d %d", DIRS[a % 4].x, DIRS[a % 4].z, a / 4);
	printf("\n");
	return 0;
}
