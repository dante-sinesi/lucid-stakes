// Solucionador nativo de salas. Es un port en C++ de las reglas de scripts/tower_logic.gd (caminar, empujar, tirar, colgarse, gravedad con apoyo por vecinos y aristas) y del A* de scripts/solver.gd.
// Tipos de bloque: común (0), hielo (1), bomba (2), catapulta (3), agrietado (4), pesado (5), trampa (6) y pinchos (7), más los bloques fijos.
// Uso:  solver_nativo ENTRADA SALIDA     (archivos de texto; ver scripts/native_solver.gd, que los arma y los lee)
// Se compila con native/construir.bat (g++ -O2 -static). Las pruebas contra GDScript están en tests/test_native.gd.
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iostream>
#include <memory>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>

using namespace std;
typedef int64_t i64;
typedef uint64_t u64;
typedef uint8_t u8;

// --- el mundo --------------------------------------------------------------------------------------------------------------------
static const int OUTSIDE = 5;
static const int MAX_ROW = 3;
static const int SLIDE_LIMIT = 40;
enum Kind { NORMAL = 0, ICE = 1, BOMB = 2, CATAPULT = 3, CRACKED = 4, HEAVY = 5, TRAP = 6, SPIKES = 7 };

static const int OFF = 8;
static const int GX = 28, GZ = 28, GY = 44;
static const int CELLS = GX * GZ * GY;

static int sizeX = 8, sizeZ = 8, floorY = 0, goalY = 0;
static bool goalAny = false;   // sin bloques meta: basta con llegar a la altura

struct V { int x, y, z; };
static inline V operator+(V a, V b) { return {a.x + b.x, a.y + b.y, a.z + b.z}; }
static inline V operator-(V a, V b) { return {a.x - b.x, a.y - b.y, a.z - b.z}; }
static inline V operator-(V a) { return {-a.x, -a.y, -a.z}; }
static inline bool operator==(V a, V b) { return a.x == b.x && a.y == b.y && a.z == b.z; }
static inline bool operator!=(V a, V b) { return !(a == b); }
static const V UP = {0, 1, 0}, DOWN = {0, -1, 0}, ZERO = {0, 0, 0};
static const V DIRS[4] = {{1, 0, 0}, {-1, 0, 0}, {0, 0, 1}, {0, 0, -1}};
static const V NEIGHBORS[6] = {{1, 0, 0}, {-1, 0, 0}, {0, 0, 1}, {0, 0, -1}, {0, 1, 0}, {0, -1, 0}};
static const V EDGE_SUPPORT[4] = {{1, -1, 0}, {-1, -1, 0}, {0, -1, 1}, {0, -1, -1}};

static inline int cellIdx(V c) {
	int ax = c.x + OFF, az = c.z + OFF;
	if (ax < 0 || ax >= GX || az < 0 || az >= GZ || c.y < 0 || c.y >= GY) return -1;
	return (c.y * GZ + az) * GX + ax;
}
static inline V cellOf(int i) { return {(i % GX) - OFF, i / (GX * GZ), ((i / GX) % GZ) - OFF}; }

static inline bool inBounds(V c) { return c.x >= -OUTSIDE && c.x < sizeX + OUTSIDE && c.z >= -OUTSIDE && c.z < sizeZ + OUTSIDE && c.y >= 0; }
static inline bool inHangReach(V c) { return c.x >= -OUTSIDE - 1 && c.x <= sizeX + OUTSIDE && c.z >= -OUTSIDE - 1 && c.z <= sizeZ + OUTSIDE && c.y >= 0; }
static inline bool inFootprint(V c) { return c.x >= 0 && c.x < sizeX && c.z >= 0 && c.z < sizeZ && c.y >= 0; }

// Hash de Zobrist idéntico al de GDScript (scripts/tower_logic.gd: zob_hash): mismas constantes y desplazamientos aritméticos de 64 bits con signo.
static inline i64 zobHash(V c, int kind) {
	i64 v = (i64)(c.x + 16) + 64 * ((i64)(c.z + 16) + 64 * ((i64)(c.y + 64) + 256 * (i64)kind)) + 1;
	u64 u = (u64)v;
	u = (u64)(((i64)u ^ ((i64)u >> 30))) * (u64)(-4658895280553007687LL);
	u = (u64)(((i64)u ^ ((i64)u >> 27))) * (u64)(-7723592293110705685LL);
	return (i64)u ^ ((i64)u >> 31);
}

// Bloques de la capa estática (fijos: el piso, la meta) y de la dinámica (los que se mueven o caen).
static vector<u8> S;            // 0 = vacío; si no, 8 | tipo | 32 si es meta
static vector<int> fixedCells;
static vector<V> goalStatic;
static i64 staticZob = 0;
static bool anyIce = false, anyBomb = false;
static int gainG = 1;   // lo que puede subir una acción: 1, o el impulso de la catapulta + 1 si hay catapultas en el estado inicial
static vector<V> trailV;   // celdas que ocupó el jugador en la última acción (las bombas de abajo se purifican)
static const u8 PRESENT = 8, STAND = 16, GOALF = 32;

struct Data {
	vector<u8> g;
	vector<u8> tm;   // cuenta de cada bomba (0 = desactivada)
	vector<int> list;
};

static long long wVersion = 0;   // cuenta cada cambio de los bloques de W (mover, sacar, anotar apoyados): si no cambió, la configuración es la misma
static Data W;   // el estado de trabajo: las acciones se prueban sobre él y se deshacen (ver snapshot y restore)

struct Sim {
	Data *d = &W;
	i64 zob = 0;
	V p = {0, 0, 0};
	V hang = {0, 0, 0};
	bool lost = false, won = false, dirty = true;
	V crackFrom = {0, 0, 0};
	int crackCell = -1;
};

static inline void own(Sim &) {}
static inline void setP(Sim &s, V c) {
	s.p = c;
	if (anyBomb) trailV.push_back(c);
}

static vector<int> snapList;
static vector<u8> snapVal, snapTm;
// Guarda los bloques de W (todo lo que no es cero en W.g está en W.list) para poder deshacer una acción.
static inline void snapshot() {
	snapList = W.list;
	snapVal.resize(snapList.size());
	snapTm.resize(snapList.size());
	for (size_t i = 0; i < snapList.size(); i++) {
		snapVal[i] = W.g[snapList[i]];
		snapTm[i] = W.tm[snapList[i]];
	}
}
static inline void restore() {
	for (int ci : W.list) {
		W.g[ci] = 0;
		W.tm[ci] = 0;
	}
	W.list = snapList;
	for (size_t i = 0; i < snapList.size(); i++) {
		W.g[snapList[i]] = snapVal[i];
		W.tm[snapList[i]] = snapTm[i];
	}
}
struct RestoreGuard {
	~RestoreGuard() { restore(); }
};
static inline u8 dynAt(const Sim &s, V c) {
	int i = cellIdx(c);
	return i < 0 ? 0 : s.d->g[i];
}
static inline u8 statAt(V c) {
	int i = cellIdx(c);
	return i < 0 ? 0 : S[i];
}
static inline bool has(const Sim &s, V c) {
	int i = cellIdx(c);
	return i >= 0 && (s.d->g[i] || S[i]);
}
static inline bool isFixed(V c) { return statAt(c) != 0; }
static inline int kindAt(const Sim &s, V c) {
	int i = cellIdx(c);
	if (i < 0) return -1;
	if (s.d->g[i]) return s.d->g[i] & 7;
	if (S[i]) return S[i] & 7;
	return -1;
}
static inline bool goalAt(const Sim &s, V c) {
	int i = cellIdx(c);
	if (i < 0) return false;
	if (s.d->g[i]) return (s.d->g[i] & GOALF) != 0;
	return S[i] && (S[i] & GOALF);
}

static void listErase(vector<int> &l, int ci) {
	for (size_t i = 0; i < l.size(); i++) {
		if (l[i] == ci) {
			l[i] = l.back();
			l.pop_back();
			return;
		}
	}
}

static void removeBlock(Sim &s, V c) {
	own(s);
	int i = cellIdx(c);
	u8 f = s.d->g[i];
	s.zob ^= zobHash(c, f & 7);
	s.d->g[i] = 0;
	s.d->tm[i] = 0;
	listErase(s.d->list, i);
	s.dirty = true;
	wVersion++;
}

static void moveBlock(Sim &s, V from, V to) {
	own(s);
	int fi = cellIdx(from), ti = cellIdx(to);
	u8 f = s.d->g[fi];
	int k = f & 7;
	u8 tmv = s.d->tm[fi];
	s.d->g[fi] = 0;
	s.d->tm[fi] = 0;
	listErase(s.d->list, fi);
	s.dirty = true;
	wVersion++;
	if (ti < 0) {   // salió del mundo que se simula: cae al vacío
		s.zob ^= zobHash(from, k);
		return;
	}
	s.zob ^= zobHash(from, k) ^ zobHash(to, k);
	if (from.y == to.y) f &= ~STAND;   // empujado o tirado de costado: se sostiene de sus vecinos
	s.d->g[ti] = f;
	s.d->tm[ti] = tmv;
	s.d->list.push_back(ti);
}

// --- gravedad ---------------------------------------------------------------------------------------------------------------------
static vector<int> heldStamp;
static vector<u8> T;          // celdas que sostiene directamente un bloque fijo: la de encima, las apoyadas en su arista y las pegadas (se llena en buildRoot)
static vector<u8> lowCell;    // celdas a la altura del piso de abajo (floorY o menos)
static vector<u8> interior;   // celdas con todos sus vecinos dentro de la grilla (se puede usar aritmética de índices)
static const int OFFY = GX * GZ;
static const int nbOff[6] = {1, -1, GX, -GX, OFFY, -OFFY};
static const int edgeOff[4] = {-1 + OFFY, 1 + OFFY, -GX + OFFY, GX + OFFY};   // - EDGE_SUPPORT
static int stampNow = 0;

static inline bool heldAt(int ci) { return heldStamp[ci] == stampNow; }

static void markStanding(Sim &s) {
	own(s);
	for (int ci : s.d->list) {
		u8 &f = s.d->g[ci];
		if (!(f & STAND) && has(s, cellOf(ci) + DOWN)) f |= STAND;
	}
}

static bool settleBlocks(Sim &s) {
	if (!s.dirty) return false;
	own(s);
	bool moved = false, skipped = false;
	int guard = 0;
	static vector<int> queue;
	static vector<int> loose;
	while (guard < 400) {
		guard++;
		for (int ci : s.d->list) {
			u8 &f = s.d->g[ci];
			if (!(f & STAND) && has(s, cellOf(ci) + DOWN)) {
				f |= STAND;
				wVersion++;
			}
		}
		stampNow++;
		queue.clear();
		for (int ci : s.d->list) {   // lo que sostiene directamente un bloque fijo (T), y el piso de abajo, que se sostiene solo mientras tenga algún vecino
			bool seed = T[ci] != 0;
			if (!seed && lowCell[ci]) {
				V c = cellOf(ci);
				for (int k = 0; k < 6 && !seed; k++) seed = has(s, c + NEIGHBORS[k]);
				for (int k = 0; k < 4 && !seed; k++) seed = has(s, c + EDGE_SUPPORT[k]);
			}
			if (seed) {
				heldStamp[ci] = stampNow;
				queue.push_back(ci);
			}
		}
		size_t qi = 0;
		while (qi < queue.size()) {
			int sc = queue[qi++];
			if (interior[sc]) {
				int ui = sc + OFFY;
				if (s.d->g[ui] && !heldAt(ui)) {
					heldStamp[ui] = stampNow;
					queue.push_back(ui);
				}
				for (int k = 0; k < 4; k++) {
					int ei = sc + edgeOff[k];
					if (s.d->g[ei] && !heldAt(ei)) {
						heldStamp[ei] = stampNow;
						queue.push_back(ei);
					}
				}
				for (int k = 0; k < 6; k++) {
					int oi = sc + nbOff[k];
					if (s.d->g[oi] && !heldAt(oi) && !(s.d->g[oi] & STAND)) {
						heldStamp[oi] = stampNow;
						queue.push_back(oi);
					}
				}
				continue;
			}
			V sv = cellOf(sc);
			int ui = cellIdx(sv + UP);
			if (ui >= 0 && s.d->g[ui] && !heldAt(ui)) {
				heldStamp[ui] = stampNow;
				queue.push_back(ui);
			}
			for (int k = 0; k < 4; k++) {
				int ei = cellIdx(sv - EDGE_SUPPORT[k]);
				if (ei >= 0 && s.d->g[ei] && !heldAt(ei)) {
					heldStamp[ei] = stampNow;
					queue.push_back(ei);
				}
			}
			for (int k = 0; k < 6; k++) {
				int oi = cellIdx(sv + NEIGHBORS[k]);
				if (oi < 0 || !s.d->g[oi] || heldAt(oi)) continue;
				if (!(s.d->g[oi] & STAND)) {
					heldStamp[oi] = stampNow;
					queue.push_back(oi);
				}
			}
		}
		loose.clear();
		for (int ci : s.d->list)
			if (!heldAt(ci)) loose.push_back(ci);
		if (loose.empty()) break;
		sort(loose.begin(), loose.end(), [](int a, int b) { return cellOf(a).y < cellOf(b).y; });
		bool progressed = false;
		for (int ci : loose) {
			V c = cellOf(ci);
			if (!s.d->g[ci]) continue;   // (ya se movió en esta pasada)
			V below = c + DOWN;
			if (below == s.p) {
				skipped = true;
				continue;
			}
			if (has(s, below)) continue;
			if (c.y <= floorY) removeBlock(s, c);
			else moveBlock(s, c, below);
			progressed = true;
			moved = true;
		}
		if (!progressed) break;
	}
	s.dirty = skipped;
	return moved;
}

static void settlePlayer(Sim &s) {
	if (s.lost) return;
	if (s.hang != ZERO) {
		if (has(s, s.p + s.hang)) return;
		s.hang = ZERO;
	}
	while (!has(s, s.p + DOWN)) {
		if (s.p.y <= floorY) {
			s.lost = true;
			s.p.y -= 3;
			return;
		}
		setP(s, s.p + DOWN);
	}
}

static void settle(Sim &s) {
	bool changed = true;
	while (changed) {
		changed = settleBlocks(s);
		V bp = s.p, bh = s.hang;
		settlePlayer(s);
		if (s.p != bp || s.hang != bh) changed = true;
	}
}

// --- acciones -----------------------------------------------------------------------------------------------------------------------
static void slide(Sim &s, V d) {
	for (int i = 0; i < SLIDE_LIMIT; i++) {
		V t = s.p + d;
		if (has(s, t)) return;
		if (!inFootprint(t)) {   // resbaló hasta el borde: se cae
			s.lost = true;
			s.p = {t.x, max(t.y - 3, -3), t.z};
			return;
		}
		setP(s, t);
		if (kindAt(s, s.p + DOWN) != ICE) return;
	}
}

static void launch(Sim &s, V d) {   // la catapulta dispara hacia arriba y el jugador se agarra del borde de un bloque vecino
	V origin = s.p;
	for (int i = 0; i < 4; i++) {
		V cell = s.p + UP;
		if (!inBounds(cell) || has(s, cell)) break;
		setP(s, cell);
	}
	if (s.p == origin) return;
	int topY = s.p.y;
	for (int i = 0; i < 2; i++) {
		V above = {s.p.x, topY + 1, s.p.z};
		if (!inBounds(above) || has(s, above)) break;
		topY++;
	}
	for (int y = topY; y > origin.y; y--) {
		V gd[4] = {d, {-d.z, 0, d.x}, {d.z, 0, -d.x}, -d};
		for (int k = 0; k < 4; k++) {
			V g = V{s.p.x, y, s.p.z} + gd[k];
			if (has(s, g) && !has(s, g + UP) && kindAt(s, g) != ICE) {
				while (s.p.y < y) setP(s, s.p + UP);
				while (s.p.y > y) setP(s, s.p + DOWN);
				s.hang = gd[k];
				return;
			}
		}
	}
}

static void arrive(Sim &s, V d) {
	int k = kindAt(s, s.p + DOWN);
	if (k == ICE) slide(s, d);
	else if (k == CATAPULT) launch(s, d);
}

static bool actWalk(Sim &s, V d) {
	V t = s.p + d;
	if (!inBounds(t)) return false;
	if (has(s, t)) {
		if (has(s, t + UP) || has(s, s.p + UP)) return false;
		setP(s, t + UP);
		arrive(s, d);
		return true;
	}
	if (has(s, t + DOWN)) {
		setP(s, t);
		arrive(s, d);
		return true;
	}
	if (has(s, t + DOWN + DOWN)) {
		setP(s, t + DOWN);
		arrive(s, d);
		return true;
	}
	return false;
}

static bool pushRow(Sim &s, V t, V d) {
	V line[MAX_ROW + 1];
	int n = 0;
	V c = t;
	while (has(s, c)) {
		if (isFixed(c)) return false;
		if (kindAt(s, c) == HEAVY) return false;
		line[n++] = c;
		if (n > MAX_ROW) return false;
		c = c + d;
	}
	for (int i = n - 1; i >= 0; i--) moveBlock(s, line[i], line[i] + d);
	return true;
}

static bool actGrab(Sim &s, V d) {
	V t = s.p + d;
	if (has(s, t)) {
		if (isFixed(t)) return false;
		if (kindAt(s, t) == HEAVY) return false;
		V dest = t + d;
		if (has(s, dest)) return pushRow(s, t, d);
		if (kindAt(s, t) == ICE) {
			while (inFootprint(dest)) {
				V n = dest + d;
				if (has(s, n) || n == s.p) break;
				dest = n;
			}
		}
		moveBlock(s, t, dest);
		return true;
	}
	V back = s.p - d;
	if (has(s, back)) {
		if (isFixed(back)) return false;
		if (kindAt(s, back) == HEAVY) return false;
		if (!inBounds(t)) return false;
		if (!has(s, t + DOWN)) {
			V h = t + DOWN;
			if (has(s, h + DOWN)) {   // un escalón más abajo: se baja, como al caminar
				moveBlock(s, back, s.p);
				setP(s, h);
				arrive(s, d);
				return true;
			}
			if (has(s, s.p + DOWN) && !has(s, h) && inHangReach(h)) {   // sin piso atrás: el bloque viene y el jugador queda colgado del que pisaba
				if (kindAt(s, s.p + DOWN) == ICE) return false;
				moveBlock(s, back, s.p);
				setP(s, h);
				s.hang = -d;
				return true;
			}
			return false;
		}
		moveBlock(s, back, s.p);
		setP(s, t);
		arrive(s, d);
		return true;
	}
	return false;
}

static bool actHangOver(Sim &s, V d) {
	V t = s.p + d;
	V h = t + DOWN;
	if (kindAt(s, s.p + DOWN) == ICE) return false;
	if (!inHangReach(t) || has(s, t)) return false;
	if (has(s, h) || has(s, h + DOWN)) return false;
	setP(s, h);
	s.hang = -d;
	return true;
}

static bool actHanging(Sim &s, V d) {
	V w = s.hang;
	if (d == w) {
		V up = s.p + w + UP;
		if (has(s, up) || has(s, s.p + UP)) return false;
		setP(s, up);
		s.hang = ZERO;
		return true;
	}
	if (d == -w) {
		s.hang = ZERO;
		return true;
	}
	V h2 = s.p + d;
	V g2 = h2 + w;
	if (!inHangReach(h2)) return false;
	if (has(s, h2)) {
		if (has(s, h2 + UP)) return false;
		if (kindAt(s, h2) == ICE) return false;
		s.hang = d;
		return true;
	}
	if (has(s, g2)) {
		if (has(s, g2 + UP)) return false;
		if (kindAt(s, g2) == ICE) return false;
		setP(s, h2);
		return true;
	}
	if (inHangReach(g2) && !has(s, s.p + w + UP)) {
		setP(s, g2);
		s.hang = -d;
		return true;
	}
	if (has(s, g2 + DOWN)) {   // el borde del bloque termina y del otro lado hay piso: se sube a ese piso y queda parado
		s.hang = ZERO;
		setP(s, g2);
		arrive(s, d);
		return true;
	}
	return false;
}

static bool onGoal(const Sim &s) {
	if (s.p.y < goalY) return false;
	if (goalAny) return true;
	return goalAt(s, s.p + DOWN);
}

static void hazards(Sim &s) {   // trampa: se desarma y cae con el jugador; pinchos: se pierde
	for (int i = 0; i < 8; i++) {
		if (s.lost || s.hang != ZERO) return;
		int k = kindAt(s, s.p + DOWN);
		if (k == TRAP) {
			removeBlock(s, s.p + DOWN);
			settle(s);
		} else if (k == SPIKES) {
			s.lost = true;
			return;
		} else {
			return;
		}
	}
}

static void afterAction(Sim &s) {
	if (s.crackCell >= 0 && s.p != s.crackFrom && s.d->g[s.crackCell]) removeBlock(s, cellOf(s.crackCell));   // el agrietado se rompe al bajarte de él
	settle(s);
	hazards(s);
	if (s.lost) return;
	if (anyBomb) {   // pisar una bomba la desactiva
		auto purify = [&](V c) {
			int i = cellIdx(c);
			if (i >= 0 && s.d->g[i] && (s.d->g[i] & 7) == BOMB && s.d->tm[i]) {
				s.d->tm[i] = 0;
				wVersion++;
			}
		};
		for (V c : trailV) purify(c + DOWN);
		if (s.hang != ZERO) purify(s.p + s.hang);
	}
	if (onGoal(s)) {
		s.won = true;
		return;
	}
	if (anyBomb) {   // una bomba cuenta sólo cuando el jugador está en su fila; al llegar a 0 explota
		for (int ci : s.d->list) {
			if ((s.d->g[ci] & 7) != BOMB || !s.d->tm[ci] || cellOf(ci).y != s.p.y) continue;
			s.d->tm[ci]--;
			wVersion++;
			if (s.d->tm[ci] == 0) {   // explota: la torre se derrumba
				s.lost = true;
				s.p.y -= 3;
				s.zob = 0;
				return;
			}
		}
	}
}

static bool tryAction(Sim &s, V dir, int mode) {   // mode: 0 caminar, 1 empujar/tirar, 2 colgarse
	if (s.won || s.lost) return false;
	s.crackCell = -1;
	if (anyBomb) {
		trailV.clear();
		trailV.push_back(s.p);
	}
	if (s.hang == ZERO && has(s, s.p + DOWN) && kindAt(s, s.p + DOWN) == CRACKED) {
		s.crackCell = cellIdx(s.p + DOWN);
		s.crackFrom = s.p;
	}
	bool ok;
	if (s.hang != ZERO) ok = actHanging(s, dir);
	else if (mode == 1) ok = actGrab(s, dir);
	else if (mode == 2) ok = actHangOver(s, dir);
	else ok = actWalk(s, dir);
	if (ok) afterAction(s);
	return ok;
}

// --- carga del estado -----------------------------------------------------------------------------------------------------------
struct BlockIn { V c; int kind; bool fixed, goal, standing; int timer; };
static vector<BlockIn> blocksIn;
static V startP = {0, 0, 0}, startH = {0, 0, 0};
static bool standingReady = false, startDirty = true;

static Sim buildRoot() {
	Sim s;
	W.g.assign(CELLS, 0);
	W.tm.assign(CELLS, 0);
	W.list.clear();
	s.d = &W;
	s.zob = 0;
	for (auto &b : blocksIn) {
		int i = cellIdx(b.c);
		if (i < 0) continue;
		s.zob ^= zobHash(b.c, b.kind);
		if (b.fixed) {
			S[i] = PRESENT | b.kind | (b.goal ? GOALF : 0);
			fixedCells.push_back(i);
			staticZob ^= zobHash(b.c, b.kind);
			if (b.goal) goalStatic.push_back(b.c);
			if (b.kind == ICE) anyIce = true;
		} else {
			s.d->g[i] = PRESENT | b.kind | (b.goal ? GOALF : 0) | (b.standing ? STAND : 0);
				if (b.kind == BOMB) {
					s.d->tm[i] = (u8)b.timer;
					anyBomb = true;
				}
				if (b.kind == CATAPULT) gainG = 5;
			s.d->list.push_back(i);
			if (b.kind == ICE) anyIce = true;
		}
	}
	T.assign(CELLS, 0);
	lowCell.assign(CELLS, 0);
	interior.assign(CELLS, 0);
	for (int i = 0; i < CELLS; i++) {
		V c = cellOf(i);
		lowCell[i] = c.y <= floorY ? 1 : 0;
		int ax = c.x + OFF, az = c.z + OFF;
		interior[i] = (ax >= 1 && ax <= GX - 2 && az >= 1 && az <= GZ - 2 && c.y >= 1 && c.y <= GY - 2) ? 1 : 0;
	}
	for (int fc : fixedCells) {
		V v = cellOf(fc);
		int i = cellIdx(v + UP);
		if (i >= 0) T[i] = 1;
		for (int k = 0; k < 4; k++) {
			i = cellIdx(v - EDGE_SUPPORT[k]);
			if (i >= 0) T[i] = 1;
		}
		for (int k = 0; k < 6; k++) {
			i = cellIdx(v + NEIGHBORS[k]);
			if (i >= 0) T[i] = 1;
		}
	}
	s.p = startP;
	s.hang = startH;
	s.dirty = startDirty;
	if (!standingReady) markStanding(s);   // (try_action marca los apoyados antes de la primera acción)
	return s;   // (los apoyados se anotan en la primera revisión de apoyo, igual que en GDScript)
}

// --- heurística ------------------------------------------------------------------------------------------------------------------
static int heurMode = 1;      // 0 ninguna, 1 admisible (subida + distancia a la meta), 2 producción (la anterior más el déficit de la columna de la meta, que no es admisible)
static double weightH = 1.0;
static int unitCost = 1;   // 16 con PLAIN: entre los caminos más cortos gana el de menos empujes, tirones y colgadas (cada acción cuesta 16 y esas 17)
static bool noGrab = false;

static int goalDeficit(const Sim &s) {
	int best = 1000;
	auto one = [&](V p) {
		for (int k = 0; k < 4; k++) {
			V n = p + DIRS[k];
			int missing = 0, y = p.y - 1;
			while (y >= 0 && missing <= 12) {
				if (has(s, {n.x, y, n.z})) break;
				missing++;
				y--;
			}
			best = min(best, missing);
		}
	};
	for (V g : goalStatic) one(g);
	for (int ci : s.d->list)
		if (s.d->g[ci] & GOALF) one(cellOf(ci));
	return best >= 1000 ? 0 : best;
}

static int heuristic(const Sim &s) {
	if (heurMode == 0) return 0;
	int h = (max(0, goalY - s.p.y) + gainG - 1) / gainG;
	if (!goalAny && !anyIce && gainG == 1) {
		int best = 1000;
		auto cheb = [&](V p) { best = min(best, max(abs(p.x - s.p.x), abs(p.z - s.p.z))); };
		for (V g : goalStatic) cheb(g);
		for (int ci : s.d->list)
			if (s.d->g[ci] & GOALF) cheb(cellOf(ci));
		if (best < 1000) h = max(h, best);
	}
	if (heurMode == 2 && !goalAny) h += goalDeficit(s);
	return (int)(h * weightH + (h * weightH >= 0 ? 0.5 : -0.5));
}

// --- A* -------------------------------------------------------------------------------------------------------------------------
struct Key {
	i64 z;
	int ps;
	bool operator==(const Key &o) const { return z == o.z && ps == o.ps; }
};
struct KeyHash {
	size_t operator()(const Key &k) const { return (size_t)((u64)k.z * 0x9E3779B97F4A7C15ULL ^ (u64)k.ps * 0xC2B2AE3D27D4EB4FULL); }
};

static inline int encDir(V d) { return (d.x + 1) + 3 * ((d.y + 1) + 3 * (d.z + 1)); }
static inline Key keyOf(const Sim &s) {
	int pe = (s.p.x + 40) + 128 * ((s.p.z + 40) + 128 * (s.p.y + 40));
	i64 z = s.zob;
	if (anyBomb)
		for (int ci : s.d->list)
			if ((s.d->g[ci] & 7) == BOMB && s.d->tm[ci]) z ^= zobHash(cellOf(ci), 40 + min((int)s.d->tm[ci], 200));
	return {z, pe * 27 + encDir(s.hang)};
}

struct Node {
	int cfg;
	V p;
	V hang;
	int g, parent;
	u8 action;
	bool dirty, won;
};

// Las configuraciones de bloques de los nodos, una detrás de otra en un solo arreglo: cuatro bytes por bloque (celda en dos bytes, banderas y cuenta de la bomba).
static vector<u8> cfgBytes;
static vector<unsigned> cfgOff(1, 0);
struct CfgView {
	const u8 *p;
	size_t n;
	size_t size() const { return n; }
	u8 operator[](size_t i) const { return p[i]; }
};
static inline CfgView cfgGet(int i) { return {cfgBytes.data() + cfgOff[i], cfgOff[i + 1] - cfgOff[i]}; }
static inline int cfgCount() { return (int)cfgOff.size() - 1; }
static inline void cfgReset() {
	cfgBytes.clear();
	cfgOff.assign(1, 0);
}
static int addCfg(const Sim &s) {
	for (int ci : s.d->list) {
		cfgBytes.push_back((u8)(ci & 255));
		cfgBytes.push_back((u8)((ci >> 8) & 255));
		cfgBytes.push_back(s.d->g[ci]);
		cfgBytes.push_back(s.d->tm[ci]);
	}
	cfgOff.push_back((unsigned)cfgBytes.size());
	return cfgCount() - 1;
}
static Sim simFromNode(const Node &n, i64 zob) {
	Sim s;
	for (int ci : W.list) {
		W.g[ci] = 0;
		W.tm[ci] = 0;
	}
	W.list.clear();
	s.d = &W;
	CfgView c = cfgGet(n.cfg);
	s.d->list.reserve(c.size() / 3);
	for (size_t i = 0; i < c.size(); i += 4) {
		int ci = c[i] | (c[i + 1] << 8);
		s.d->g[ci] = c[i + 2];
		s.d->tm[ci] = c[i + 3];
		s.d->list.push_back(ci);
	}
	s.zob = zob;
	s.p = n.p;
	s.hang = n.hang;
	s.dirty = n.dirty;
	return s;
}

static string pathText(const vector<Node> &nodes, int idx) {
	vector<int> acts;
	while (nodes[idx].parent != -1) {
		acts.push_back(nodes[idx].action);
		idx = nodes[idx].parent;
	}
	reverse(acts.begin(), acts.end());
	static const char dirc[4] = {'E', 'W', 'S', 'N'};
	static const char modec[3] = {'m', 'g', 'h'};
	string out;
	for (int a : acts) {
		out += modec[a % 3];
		out += dirc[a / 3];
	}
	return out;
}

// --- excavar: el grafo de estados cerca de una sala, con la distancia exacta a la meta de cada estado ----------------------------------------------------------
// Explora a lo ancho desde el estado inicial hasta MAXNODES estados, guarda todas las aristas, y calcula hacia atrás (desde los estados ganadores) cuántas acciones faltan para ganar
// desde cada estado y cuántas de ellas son empujar o tirar (entre los caminos más cortos, el de menos agarres). Los candidatos son los estados donde el jugador está en la entrada, de pie,
// cuyos bloques sueltos forman columnas apoyadas en el piso (un formato que la biblioteca de salas puede guardar): son salas nuevas, alcanzables desde la inicial, de dificultad exacta conocida.
static long long exMaxNodes = 1000000;
static bool exKeepSpecials = false;            // los bloques especiales (todos menos común y pesado) tienen que quedar en su lugar
static bool exNoFloor = false;                 // sin piso: no se exige que haya piso debajo de cada celda
static vector<char> exArenaOk;                  // si no está vacío, las celdas (x, z) permitidas (x * 64 + z)
static int exTopK = 20, exEntryX = 0, exEntryZ = 0, exExitX = -99, exExitZ = -99, exMinD = 0, exColumns = 1, exMaxY = 19;

struct EdgeRec { int u, v; u8 grab; };

static string exPath;   // camino solución conocido (letras como las de la salida): se exploran los estados alrededor de todo el camino

static void excavate(Sim &root, ofstream &out) {
	auto t0 = chrono::steady_clock::now();
	vector<Node> nodes;
	unordered_map<Key, int, KeyHash> idx;
	unordered_map<i64, int> cfgIndex;
	vector<EdgeRec> edges;
	vector<i64> nodeZob;
	vector<int> tmp;
	cfgReset();
	nodes.reserve(1 << 18);
	idx.reserve(1 << 20);
	addCfg(root);
	nodes.push_back({0, root.p, root.hang, 0, -1, 255, root.dirty, root.won});
	nodeZob.push_back(root.zob);
	idx[keyOf(root)] = 0;
	bool capped = false;
	// agrega (o encuentra) el estado `n` que sale de `ui` con la acción (di, m); -1 si ya no entran más nodos
	auto visit = [&](Sim &n, int ui, int di, int m, bool changed) -> int {
		Key k = keyOf(n);
		auto it = idx.find(k);
		int vi;
		if (it != idx.end()) {
			vi = it->second;
		} else {
			if ((long long)nodes.size() >= exMaxNodes) {
				capped = true;
				return -1;
			}
			int cfg = nodes[ui].cfg;
			if (changed) cfg = addCfg(n);
			nodes.push_back({cfg, n.p, n.hang, nodes[ui].g + 1, ui, (u8)(di * 3 + m), n.dirty, n.won});
			nodeZob.push_back(n.zob);
			vi = (int)nodes.size() - 1;
			idx[k] = vi;
		}
		edges.push_back({ui, vi, (u8)(m == 1 ? 1 : 0)});
		return vi;
	};
	{   // el camino conocido entra primero: la exploración rodea todo el camino y los estados cercanos llegan a la meta
		Sim cur = root;
		int prev = 0;
		for (size_t i = 0; i + 1 < exPath.size(); i += 2) {
			int m = exPath[i] == 'm' ? 0 : (exPath[i] == 'g' ? 1 : 2);
			int di = exPath[i + 1] == 'E' ? 0 : (exPath[i + 1] == 'W' ? 1 : (exPath[i + 1] == 'S' ? 2 : 3));
			Sim n = cur;
			if (!tryAction(n, DIRS[di], m) || n.lost) break;
			int vi = visit(n, prev, di, m, true);
			if (vi < 0) break;
			prev = vi;
			cur = n;
			if (n.won) break;
		}
	}
	size_t head = 0;
	while (head < nodes.size()) {
		int ui = (int)head++;
		const Node cur = nodes[ui];
		if (cur.won) continue;
		Sim base = simFromNode(cur, nodeZob[ui]);
		for (int di = 0; di < 4; di++) {
			V dd = DIRS[di];
			for (int m = 0; m < 3; m++) {
				if (cur.hang != ZERO && m != 0) continue;
				if (m == 1 && !(has(base, base.p + dd) || has(base, base.p - dd))) continue;
				if (m == 2) {
					V ht = base.p + dd;
					if (has(base, ht) || has(base, ht + DOWN) || has(base, ht + DOWN + DOWN)) continue;
				}
				snapshot();
				RestoreGuard rg;
				long long ver0 = wVersion;
				Sim n = base;
				if (!tryAction(n, dd, m) || n.lost) continue;
				visit(n, ui, di, m, wVersion != ver0);
			}
		}
	}
	// hacia atrás desde los ganadores
	int N = (int)nodes.size();
	vector<int> start(N + 2, 0);
	for (auto &e : edges) start[e.v + 1]++;
	for (int i = 0; i < N; i++) start[i + 1] += start[i];
	vector<int> fill(start.begin(), start.end() - 1);
	vector<int> radj(edges.size());
	for (size_t i = 0; i < edges.size(); i++) radj[fill[edges[i].v]++] = (int)i;
	vector<int> dist(N, -1), gm(N, 0);
	vector<int> q;
	for (int i = 0; i < N; i++)
		if (nodes[i].won) {
			dist[i] = 0;
			q.push_back(i);
		}
	size_t qh = 0;
	while (qh < q.size()) {
		int v = q[qh++];
		for (int k = start[v]; k < start[v + 1]; k++) {
			const EdgeRec &e = edges[radj[k]];
			int u = e.u;
			int cand = e.grab + gm[v];
			if (dist[u] < 0) {
				dist[u] = dist[v] + 1;
				gm[u] = cand;
				q.push_back(u);
			} else if (dist[u] == dist[v] + 1 && cand < gm[u]) {
				gm[u] = cand;
			}
		}
	}
	// candidatos: una disposición de bloques (con el jugador donde mejor le quede) expresable en columnas apoyadas en el piso
	vector<signed char> exprOk(cfgCount(), -1);
	auto specialsOf = [&](int cfg) {
		CfgView c = cfgGet(cfg);
		vector<int> out;
		for (size_t j = 0; j < c.size(); j += 4) {
			int k = c[j + 2] & 7;
			if (k != NORMAL && k != HEAVY) out.push_back((c[j] | (c[j + 1] << 8)) * 8 + k);
		}
		sort(out.begin(), out.end());
		return out;
	};
	vector<int> rootSpecials = specialsOf(0);
	auto expressible = [&](int cfg) -> bool {
		if (exprOk[cfg] >= 0) return exprOk[cfg] != 0;
		if (exKeepSpecials && specialsOf(cfg) != rootSpecials) {
			exprOk[cfg] = 0;
			return false;
		}
		CfgView c = cfgGet(cfg);
		vector<int> cells;
		for (size_t j = 0; j < c.size(); j += 4) cells.push_back(c[j] | (c[j + 1] << 8));
		sort(cells.begin(), cells.end());
		bool ok = true;
		for (int ci : cells) {
			V b = cellOf(ci);
			if (b.x == exExitX && b.z == exExitZ) continue;   // el pilar de la salida
			bool cellOk = exNoFloor ? true : (S[cellIdx({b.x, 0, b.z})] != 0);
			if (!exArenaOk.empty() && !exArenaOk[b.x * 64 + b.z]) cellOk = false;
			if (b.y < 1 || b.y > exMaxY || !cellOk) {
				ok = false;
				break;
			}
			if (exColumns && b.y > 1 && !binary_search(cells.begin(), cells.end(), cellIdx({b.x, b.y - 1, b.z}))) {
				ok = false;
				break;
			}
		}
		exprOk[cfg] = ok ? 1 : 0;
		return ok;
	};
	struct Lay { int node, d, g; };
	unordered_map<i64, Lay> layouts;
	for (int i = 0; i < N; i++) {
		const Node &nd = nodes[i];
		if (nd.won || dist[i] <= 0 || dist[i] < exMinD) continue;
		if (nodeZob[i] == nodeZob[0]) continue;   // la sala de partida
		if (!expressible(nd.cfg)) continue;
		auto it = layouts.find(nodeZob[i]);
		if (it == layouts.end()) {
			layouts[nodeZob[i]] = {i, dist[i], gm[i]};
		} else if (gm[i] > it->second.g || (gm[i] == it->second.g && dist[i] < it->second.d)) {   // (el jugador mejor parado: menos pasos para los mismos agarres)
			it->second = {i, dist[i], gm[i]};
		}
	}
	vector<Lay> cands;
	for (auto &kv : layouts) cands.push_back(kv.second);
	// se ordena por dificultad (agarres sobre pasos); entre las parecidas, las de más agarres
	sort(cands.begin(), cands.end(), [](const Lay &a, const Lay &b) {
		long long l = (long long)a.g * b.d, r = (long long)b.g * a.d;
		if (l != r) return l > r;
		return a.g != b.g ? a.g > b.g : a.node < b.node;
	});
	long long ms = chrono::duration_cast<chrono::milliseconds>(chrono::steady_clock::now() - t0).count();
	int maxd = 0, maxg = 0, wins = 0;
	for (int i = 0; i < N; i++) {
		if (nodes[i].won) wins++;
		if (dist[i] > maxd) maxd = dist[i];
		if (dist[i] >= 0 && gm[i] > maxg) maxg = gm[i];
	}
	out << "STATUS " << (capped ? "capped" : "complete") << "\n";
	out << "NODES " << N << "\n";
	out << "EDGES " << edges.size() << "\n";
	out << "WINS " << wins << "\n";
	out << "MAXD " << maxd << "\n";
	out << "MAXG " << maxg << "\n";
	out << "CANDS " << cands.size() << "\n";
	out << "MS " << ms << "\n";
	for (int i = 0; i < (int)cands.size() && i < exTopK; i++) {
		const Lay &cd = cands[i];
		out << "CAND " << cd.d << " " << cd.g << " ";
		CfgView c = cfgGet(nodes[cd.node].cfg);
		bool first = true;
		for (size_t j = 0; j < c.size(); j += 4) {
			int ci = c[j] | (c[j + 1] << 8);
			V b = cellOf(ci);
			if (b.x == exExitX && b.z == exExitZ) continue;
			if (!first) out << ";";
			first = false;
			out << b.x << "," << b.y << "," << b.z << "," << (c[j + 2] & 7);
		}
		out << "\n";
	}
}

int main(int argc, char **argv) {
	if (argc < 3) {
		fprintf(stderr, "uso: solver_nativo ENTRADA SALIDA\n");
		return 2;
	}
	ifstream in(argv[1]);
	if (!in) return 2;
	long long maxStates = 2000000, maxMs = 0;
	string mode = "solve";
	vector<pair<int, int>> simActions;   // (dirección, modo)
	int goalCount = 0;
	string tok;
	bool unsupported = false;
	while (in >> tok) {
		if (tok == "SIZE") in >> sizeX >> sizeZ;
		else if (tok == "FLOORY") in >> floorY;
		else if (tok == "GOALY") in >> goalY;
		else if (tok == "MAXSTATES") in >> maxStates;
		else if (tok == "MAXMS") in >> maxMs;
		else if (tok == "HEUR") {
			string h;
			in >> h;
			heurMode = h == "none" ? 0 : (h == "prod" ? 2 : 1);
		} else if (tok == "WEIGHT") in >> weightH;
		else if (tok == "PLAIN") {
			int v;
			in >> v;
			unitCost = v != 0 ? 16 : 1;
		} else if (tok == "MAXNODES") in >> exMaxNodes;
		else if (tok == "TOPK") in >> exTopK;
		else if (tok == "MIND") in >> exMinD;
		else if (tok == "ENTRY") in >> exEntryX >> exEntryZ;
		else if (tok == "EXIT") in >> exExitX >> exExitZ;
		else if (tok == "PATH") in >> exPath;
		else if (tok == "KEEPSPECIALS") {
			int v;
			in >> v;
			exKeepSpecials = v != 0;
		} else if (tok == "NOFLOOR") {
			int v;
			in >> v;
			exNoFloor = v != 0;
		} else if (tok == "ARENA") {
			int n;
			in >> n;
			exArenaOk.assign(64 * 64, 0);
			for (int i = 0; i < n; i++) {
				int x, z;
				in >> x >> z;
				if (x >= 0 && x < 64 && z >= 0 && z < 64) exArenaOk[x * 64 + z] = 1;
			}
		} else if (tok == "COLUMNS") in >> exColumns;
		else if (tok == "MAXY") in >> exMaxY;
		else if (tok == "NOGRAB") {
			int v;
			in >> v;
			noGrab = v != 0;
		} else if (tok == "READY") {
			int v;
			in >> v;
			standingReady = v != 0;
		} else if (tok == "DIRTY") {
			int v;
			in >> v;
			startDirty = v != 0;
		} else if (tok == "MODE") in >> mode;
		else if (tok == "PLAYER") in >> startP.x >> startP.y >> startP.z;
		else if (tok == "HANG") in >> startH.x >> startH.y >> startH.z;
		else if (tok == "BLOCK") {
			BlockIn b;
			int f, g, st, tmv;
			in >> b.c.x >> b.c.y >> b.c.z >> b.kind >> f >> g >> st >> tmv;
			b.timer = tmv;
			b.fixed = f != 0;
			b.goal = g != 0;
			b.standing = st != 0;
			if (b.goal) goalCount++;
			blocksIn.push_back(b);
		} else if (tok == "ACTION") {
			int d, m;
			in >> d >> m;
			simActions.push_back({d, m});
		} else if (tok == "END") break;
	}
	ofstream out(argv[2]);
	if (unsupported) {
		out << "STATUS unsupported\n";
		return 0;
	}
	goalAny = goalCount == 0;
	S.assign(CELLS, 0);
	heldStamp.assign(CELLS, 0);
	Sim root = buildRoot();

	if (mode == "excavate") {
		excavate(root, out);
		return 0;
	}
	if (mode == "sim") {   // aplica las acciones una por una y cuenta cómo queda cada paso (para compararlo con GDScript)
		Sim s = root;
		for (auto &a : simActions) {
			bool ok = tryAction(s, DIRS[a.first], a.second);
			out << "R " << (ok ? 1 : 0) << " " << s.p.x << " " << s.p.y << " " << s.p.z << " " << s.hang.x << " " << s.hang.y << " " << s.hang.z << " " << (s.lost ? 1 : 0) << " " << (s.won ? 1 : 0) << " "
				<< (long long)(s.zob) << " " << (s.dirty ? 1 : 0) << "\n";
		}
		return 0;
	}

	auto t0 = chrono::steady_clock::now();
	vector<Node> nodes;
	unordered_map<Key, int, KeyHash> best;
	unordered_map<i64, int> cfgIndex;
	vector<vector<int>> buckets;
	nodes.reserve(1 << 16);
	best.reserve(1 << 18);
	vector<int> tmp;
	cfgReset();
	{
		addCfg(root);
			Node n0 = {0, root.p, root.hang, 0, -1, 255, root.dirty, root.won};
		nodes.push_back(n0);
		best[keyOf(root)] = 0;
	}
	int f0 = heuristic(root) * unitCost;
	buckets.resize(f0 + 64);
	buckets[f0].push_back(0);
	long long open = 1, generated = 1, expanded = 0;
	int f = f0;
	string status = "unsolvable";
	int solvedIdx = -1;
	int fReached = f0;
	while (open > 0) {
		if (maxMs > 0 && (expanded & 255) == 0) {
			long long ms = chrono::duration_cast<chrono::milliseconds>(chrono::steady_clock::now() - t0).count();
			if (ms > maxMs) {
				status = "limit";
				break;
			}
		}
		if (f >= (int)buckets.size()) buckets.resize(f + 64);
		if (buckets[f].empty()) {
			f++;
			continue;
		}
		int idx = buckets[f].back();
		buckets[f].pop_back();
		open--;
		fReached = f;
		const Node cur = nodes[idx];
		if (cur.won) {
			status = "solved";
			solvedIdx = idx;
			break;
		}
		expanded++;
		Sim base = simFromNode(cur, 0);
		// el zob del nodo: se recalcula desde la configuración (la identidad del estado es id-agnóstica)
		{
			i64 z = staticZob;
			for (int ci : base.d->list) z ^= zobHash(cellOf(ci), base.d->g[ci] & 7);
			base.zob = z;
		}
		bool limitHit = false;
		for (int di = 0; di < 4 && !limitHit; di++) {
			V dd = DIRS[di];
			for (int mode2 = 0; mode2 < 3; mode2++) {
				if (noGrab && mode2 == 1) continue;
				if (cur.hang != ZERO && mode2 != 0) continue;
				if (mode2 == 1 && !(has(base, base.p + dd) || has(base, base.p - dd))) continue;
				if (mode2 == 2) {
					V ht = base.p + dd;
					if (has(base, ht) || has(base, ht + DOWN) || has(base, ht + DOWN + DOWN)) continue;
				}
				snapshot();
				RestoreGuard rg;
				long long ver0 = wVersion;
				Sim n = base;
				if (!tryAction(n, dd, mode2) || n.lost) continue;
				Key k = keyOf(n);
				auto it = best.find(k);
				int ng = cur.g + unitCost + ((unitCost > 1 && mode2 != 0) ? 1 : 0);
				if (it != best.end() && it->second <= ng) continue;
				best[k] = ng;
				int cfg = cur.cfg;
				if (wVersion != ver0) cfg = addCfg(n);
				Node nn = {cfg, n.p, n.hang, ng, idx, (u8)(di * 3 + mode2), n.dirty, n.won};
				nodes.push_back(nn);
				int nf = ng + heuristic(n) * unitCost;
				if (nf >= (int)buckets.size()) buckets.resize(nf + 64);
				buckets[nf].push_back((int)nodes.size() - 1);
				open++;
				generated++;
				if (generated >= maxStates) {
					status = "limit";
					limitHit = true;
					break;
				}
			}
		}
		if (limitHit) break;
	}
	out << "STATUS " << status << "\n";
	out << "STATES " << generated << "\n";
	out << "EXPANDED " << expanded << "\n";
	out << "FREACHED " << fReached << "\n";
	if (solvedIdx >= 0) {
		string p = pathText(nodes, solvedIdx);
		out << "MOVES " << p.size() / 2 << "\n";
		out << "PATH " << (p.empty() ? "-" : p) << "\n";
	}
	long long ms = chrono::duration_cast<chrono::milliseconds>(chrono::steady_clock::now() - t0).count();
	out << "MS " << ms << "\n";
	return 0;
}
