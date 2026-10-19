// Generador nativo de salas: el minero completo en C++ (sin GDScript en ningún lazo caliente). Usa el motor del solucionador nativo (solver_nativo.cpp: mismas reglas, A* y excavación).
// Hace todo lo que antes hacían el minero, la auditoría y el empaquetador, una sala por vez y ya con calidad de biblioteca:
//   - semillas: una escalera a pie hasta la salida (la sala resuelta);
//   - excavar: explora el grafo de estados alrededor de la sala y de su camino y propone las disposiciones más difíciles que se alcanzan desde ella (sube los empujes y tirones);
//   - tipos: cambia unos bloques por especiales (hielo, agrietado, bomba, catapulta, trampa, pinchos) y se queda con la sala si el especial HACE FALTA (la auditoría);
//   - mutar: cambios chicos al azar;
//   - cada sala se resuelve con el solucionador exacto (camino más corto, y entre los más cortos el de menos agarres), se comprueba que no se resuelva caminando, se afina la cuenta de las bombas,
//     se cambian por comunes los especiales que no hacen falta y se mide el alcance de los empujes (reach). Sólo salen las que pasan todo.
// Glaciar: --types=i,h,c,s --p-ice=0.7 --min-ice=3 --min-slides=3 (sólo salas con hielo que hace falta, con pesado, agrietado y pinchos como compañeros)
// Uso:  generador mina    --out=ARCHIVO [--seed=N] [--steps=N] [--shapes=3x3,3x5,3x8,L,U] [--hlo=5] [--hhi=20] [--part=I --parts=N] [--min-diff=0.2] [--min-reach=0.5] [--nodes=N] [--eval=N]
//       generador auditar --in=ARCHIVO --out=ARCHIVO [--min-reach=0.5]       (salas ya hechas, una por línea: se vuelven a resolver, auditar y medir)
// Formato de una sala (una por línea):  R|forma|h|fuse|moves|grabs|reach|especiales|camino|x,z:columna;x,z:columna...      (columna: un carácter por bloque de abajo hacia arriba; '.' es un hueco)
// Se compila con native/construir.bat. La verificación final (reglas del juego en GDScript, hashes) la hace scripts/generador_final.gd con una sola pasada por sala.
#define SOLVER_LIB
#include "solver_nativo.cpp"

#include <functional>
#include <map>
#include <random>
#include <set>

// --- formas --------------------------------------------------------------------------------------------------------------------
static inline int ck(int x, int z) { return (x + 2) * 16 + (z + 2); }
static inline int ckx(int k) { return k / 16 - 2; }
static inline int ckz(int k) { return k % 16 - 2; }

struct Shape {
	string name;
	vector<int> cells;       // claves ck de las celdas de la arena
	set<int> cellSet;
	int nx = -1, nz = 0, ex = 0, ez = 0;   // llegada (afuera) y salida
	vector<int> freeCells;
};
static map<string, Shape> SHAPES;
static const char KIND_CH[8] = {'n', 'i', 'b', 'k', 'c', 'h', 't', 's'};   // por tipo del motor: 0 común, 1 hielo, 2 bomba, 3 catapulta, 4 agrietado, 5 pesado, 6 trampa, 7 pinchos
static int kindOfChar(char c) {
	for (int i = 0; i < 8; i++)
		if (KIND_CH[i] == c) return i;
	return -1;
}
static const int MAXH_ALL = 20, MINH = 5;

static void addShape(const string &name, vector<array<int, 2>> cells, int nx, int nz, int ex, int ez) {
	Shape s;
	s.name = name;
	for (auto &c : cells) {
		s.cells.push_back(ck(c[0], c[1]));
		s.cellSet.insert(ck(c[0], c[1]));
	}
	s.nx = nx;
	s.nz = nz;
	s.ex = ex;
	s.ez = ez;
	for (int k : s.cells) {
		int x = ckx(k), z = ckz(k);
		if (x == ex && z == ez) continue;
		int dx = x - nx, dz = z - nz;
		if (dx * dx + dz * dz < 2.25 * 1.0 + 1e-9 && dx * dx + dz * dz <= 2) continue;   // pegadas a la llegada (distancia menor a 1,5)
		s.freeCells.push_back(k);
	}
	SHAPES[name] = s;
}

static void initShapes() {
	for (int n : {3, 5, 8}) {
		vector<array<int, 2>> cells;
		for (int x = 0; x < n; x++)
			for (int z = 0; z < 3; z++) cells.push_back({x, z});
		addShape("3x" + to_string(n), cells, -1, 0, n - 1, 2);
	}
	{
		vector<array<int, 2>> cells;
		for (int x = 0; x < 8; x++)
			for (int z = 0; z < 3; z++) cells.push_back({x, z});
		for (int x = 0; x < 3; x++)
			for (int z = 3; z < 5; z++) cells.push_back({x, z});
		addShape("L", cells, 1, 5, 7, 0);
	}
	{
		vector<array<int, 2>> cells;
		for (int x = 0; x < 5; x++)
			for (int z = 0; z < 3; z++) {
				cells.push_back({x, z});
				cells.push_back({x, z + 5});
			}
		for (int x = 0; x < 3; x++)
			for (int z = 3; z < 5; z++) cells.push_back({x, z});
		addShape("U", cells, 5, 0, 4, 7);
	}
}

static int maxHeight(const string &shape) {
	int cap = MAXH_ALL;
	if (shape == "3x3") cap = 7;
	else if (shape == "3x5") cap = 8;
	int n = (int)SHAPES[shape].freeCells.size() + 1;
	return max(MINH, min(MAXH_ALL, min(cap, n)));
}

// --- salas ---------------------------------------------------------------------------------------------------------------------
struct Room {
	string shape = "3x3";
	int h = 5;
	int fuse = 0;
	map<int, string> cols;   // ck de la celda -> columna
};

static string trimGaps(string s) {
	while (!s.empty() && s.back() == '.') s.pop_back();
	return s;
}
static void cleanCols(Room &r) {
	for (auto it = r.cols.begin(); it != r.cols.end();) {
		it->second = trimGaps(it->second);
		if (it->second.empty()) it = r.cols.erase(it);
		else ++it;
	}
}
static bool hasBombRoom(const Room &r) {
	for (auto &kv : r.cols)
		if (kv.second.find('b') != string::npos) return true;
	return false;
}
static bool hasGapsRoom(const Room &r) {
	for (auto &kv : r.cols)
		if (kv.second.find('.') != string::npos) return true;
	return false;
}
static string roomKey(const Room &r) {   // texto único de la sala (sin simetrías: el final canónico lo calcula el finalizador)
	string s = r.shape + "|" + to_string(r.h) + "|" + to_string(r.fuse);
	for (auto &kv : r.cols) s += "|" + to_string(kv.first) + ":" + kv.second;
	return s;
}
static string colsText(const Room &r) {
	string s;
	bool first = true;
	for (auto &kv : r.cols) {
		if (!first) s += ";";
		first = false;
		s += to_string(ckx(kv.first)) + "," + to_string(ckz(kv.first)) + ":" + kv.second;
	}
	return s;
}
static bool parseCols(const string &text, Room &r) {
	r.cols.clear();
	size_t i = 0;
	while (i < text.size()) {
		size_t j = text.find(';', i);
		if (j == string::npos) j = text.size();
		string item = text.substr(i, j - i);
		i = j + 1;
		size_t c1 = item.find(',');
		size_t c2 = item.find(':');
		if (c1 == string::npos || c2 == string::npos) return false;
		int x = atoi(item.substr(0, c1).c_str()), z = atoi(item.substr(c1 + 1, c2 - c1 - 1).c_str());
		r.cols[ck(x, z)] = item.substr(c2 + 1);
	}
	return true;
}

// Carga la sala en el motor (el mundo se vacía): piso fijo (la arena y la llegada), el pilar de salida (h - 1 bloques pesados y arriba el bloque meta fijo) y las columnas. El jugador empieza en la llegada.
static void resetWorld() {
	blocksIn.clear();
	fixedCells.clear();
	goalStatic.clear();
	staticZob = 0;
	anyIce = anyBomb = false;
	gainG = 1;
	S.assign(CELLS, 0);
	if ((int)heldStamp.size() != CELLS) heldStamp.assign(CELLS, 0);
	cfgReset();
	trailV.clear();
}

static Sim loadRoom(const Room &r) {
	resetWorld();
	const Shape &sh = SHAPES[r.shape];
	sizeX = sizeZ = 8;
	floorY = 0;
	goalY = r.h + 1;
	for (int k : sh.cells) blocksIn.push_back({{ckx(k), 0, ckz(k)}, NORMAL, true, false, false, 0});
	blocksIn.push_back({{sh.nx, 0, sh.nz}, NORMAL, true, false, false, 0});
	for (int y = 1; y < r.h; y++) blocksIn.push_back({{sh.ex, y, sh.ez}, HEAVY, false, false, false, 0});
	blocksIn.push_back({{sh.ex, r.h, sh.ez}, NORMAL, true, true, false, 0});
	for (auto &kv : r.cols) {
		const string &ks = kv.second;
		for (size_t i = 0; i < ks.size(); i++) {
			if (ks[i] == '.') continue;
			int kd = kindOfChar(ks[i]);
			if (kd < 0) kd = NORMAL;
			blocksIn.push_back({{ckx(kv.first), (int)i + 1, ckz(kv.first)}, kd, false, false, false, kd == BOMB ? (r.fuse > 0 ? r.fuse : 6) : 0});
		}
	}
	startP = {sh.nx, 1, sh.nz};
	startH = {0, 0, 0};
	standingReady = false;
	startDirty = true;
	goalAny = false;
	return buildRoot();
}

// "" si la sala es coherente (igual que RoomLib.validate_structure, sin la estabilidad); si no, el motivo.
static string validateStructure(const Room &r) {
	const Shape &sh = SHAPES[r.shape];
	if (r.h < 2 || r.h > 40) return "altura";
	for (auto &kv : r.cols) {
		int x = ckx(kv.first), z = ckz(kv.first);
		if (!sh.cellSet.count(kv.first)) return "fuera";
		if (x == sh.ex && z == sh.ez) return "sobre_la_salida";
		int dx = x - sh.nx, dz = z - sh.nz;
		if (dx * dx + dz * dz <= 2) return "pegada_a_la_llegada";
		const string &ks = kv.second;
		if ((int)ks.size() > r.h - 1) return "mas_alta_que_el_pilar";
		if (!ks.empty() && ks.back() == '.') return "termina_en_hueco";
		for (char c : ks)
			if (c != '.' && kindOfChar(c) < 0) return "tipo";
	}
	return "";
}

// ¿Ningún bloque cae al empezar? (los que no están sobre una columna tienen que sostenerse de sus vecinos) Igual que RoomLib.is_stable: sin marcar apoyados.
static bool isStable(const Room &r) {
	Sim s = loadRoom(r);
	for (int ci : W.list) W.g[ci] &= ~STAND;
	s.dirty = true;
	s.p = {-100, -100, -100};
	return !settleBlocks(s);
}

static string fullValidate(const Room &r) {
	string why = validateStructure(r);
	if (why != "") return why;
	if (hasGapsRoom(r) && !isStable(r)) return "sin_apoyo";
	return "";
}

// --- resolver -----------------------------------------------------------------------------------------------------------------
static SolveRes solveRoom(const Room &r, bool exact, bool noG, long long cap) {
	Sim root = loadRoom(r);
	heurMode = 1;
	weightH = 1.0;
	unitCost = exact ? 16 : 1;
	noGrab = noG;
	SolveRes R = runAstar(root, cap, 0);
	noGrab = false;
	unitCost = 1;
	return R;
}

struct PathInfo {
	bool ok = false;
	int moves = 0, grabs = 0, ticks = 0, slides = 0;   // slides: resbalones del jugador + empujes que mueven un bloque de hielo
	double reach = 0.0;
};

// Repite el camino sobre la sala: cuántos agarres tiene, hasta qué altura se agarra (el alcance de los empujes) y cuánta cuenta de bomba gasta.
static vector<pair<int, int>> *underOut = nullptr;   // si no es nulo: (celda, piso del bloque, desde 0) sobre el que se para el jugador en cada paso

static PathInfo replayPath(const Room &r, const string &path, int fuse) {
	PathInfo P;
	Sim s = loadRoom(r);
	int maxY = 0;
	auto iceCells = [&]() {
		vector<int> v;
		for (int ci : W.list)
			if ((W.g[ci] & 7) == ICE) v.push_back(ci);
		sort(v.begin(), v.end());
		return v;
	};
	for (size_t i = 0; i + 1 < path.size(); i += 2) {
		int m = path[i] == 'm' ? 0 : (path[i] == 'g' ? 1 : 2);
		int di = path[i + 1] == 'E' ? 0 : (path[i + 1] == 'W' ? 1 : (path[i + 1] == 'S' ? 2 : 3));
		if (m == 1) {
			P.grabs++;
			maxY = max(maxY, s.p.y);
		}
		V before = s.p;
		vector<int> iceBefore = iceCells();
		if (!tryAction(s, DIRS[di], m)) return P;
		if (s.lost) return P;
		if (m == 0 && s.hang.x == 0 && s.hang.y == 0 && s.hang.z == 0 && s.p.y == before.y && abs(s.p.x - before.x) + abs(s.p.z - before.z) >= 2) P.slides++;   // resbaló
		if (m == 1 && !iceBefore.empty() && iceCells() != iceBefore) P.slides++;   // empujó o tiró de un bloque de hielo
		if (underOut != nullptr && s.hang == ZERO && s.p.y >= 2) underOut->push_back({ck(s.p.x, s.p.z), s.p.y - 2});
		if (anyBomb && fuse > 0)
			for (int ci : W.list)
				if ((W.g[ci] & 7) == BOMB && W.tm[ci]) P.ticks = max(P.ticks, fuse - (int)W.tm[ci]);
		P.moves++;
		if (s.won) break;
	}
	P.ok = s.won;
	P.reach = (double)maxY / (double)max(r.h, 1);
	return P;
}

struct Final {
	Room room;
	string path;
	int moves = 0, grabs = 0, slides = 0;
	double reach = 0.0;
	string specials;
};

static const long long EXACT_CAP = 600000;

// Resuelve con el solucionador exacto (camino más corto y, entre los más cortos, el de menos agarres), comprueba que no se resuelva caminando y que pida mover bloques; con bombas afina la cuenta primero.
static bool exactRoom(Room r, Final &out, string &why, long long cap = EXACT_CAP) {
	if (hasBombRoom(r)) {
		// La cuenta de las bombas: la mínima con la que la sala todavía se puede resolver (por cualquier camino) más un movimiento de más. Así la bomba aprieta de verdad: si el camino más corto
		// sin límite gasta más cuenta que esa, la sala pide otro camino (más largo) o más prisa. Es monótona (más cuenta, más caminos), así que se busca por bisección.
		Room probe = r;
		probe.fuse = 60;
		SolveRes p = solveRoom(probe, true, false, cap);
		if (p.status != "solved") {
			why = "bomba_" + p.status;
			return false;
		}
		PathInfo pi = replayPath(probe, p.path, 60);
		int hi = pi.ticks + 1, lo = 1;
		while (lo < hi) {
			int mid = (lo + hi) / 2;
			probe.fuse = mid;
			SolveRes q = solveRoom(probe, true, false, cap);
			if (q.status == "solved") hi = mid;
			else if (q.status == "unsolvable") lo = mid + 1;
			else {
				why = "bomba_" + q.status;
				return false;
			}
		}
		r.fuse = hi + 1;   // (BOMB_SPARE)
	}
	SolveRes plain = solveRoom(r, false, true, 60000);   // (primero lo barato: si se resuelve caminando no hace falta la búsqueda exacta)
	if (plain.status != "unsolvable") {
		why = plain.status == "solved" ? "atajo" : "sin_prueba_de_atajo";
		return false;
	}
	SolveRes res = solveRoom(r, true, false, cap);
	if (res.status != "solved") {
		why = res.status;
		return false;
	}
	PathInfo pi = replayPath(r, res.path, r.fuse);
	if (!pi.ok || pi.grabs < 1) {
		why = "sin_bloques";
		return false;
	}
	out.room = r;
	out.path = res.path;
	out.moves = res.moves;
	out.grabs = pi.grabs;
	out.slides = pi.slides;
	out.reach = pi.reach;
	return true;
}

static string SPECIAL_CHARS = "icbkts";   // los especiales que se auditan (con --types que incluye h, también el pesado)

static Room replaceKind(const Room &r, char ch, int onlyCell = -1, int onlyY = 0) {
	Room o = r;
	for (auto &kv : o.cols) {
		string &ks = kv.second;
		for (size_t i = 0; i < ks.size(); i++)
			if (ks[i] == ch && (onlyCell < 0 || (kv.first == onlyCell && (int)i + 1 == onlyY))) ks[i] = 'n';
	}
	return o;
}
static int countKind(const Room &r, char ch) {
	int n = 0;
	for (auto &kv : r.cols)
		for (char c : kv.second)
			if (c == ch) n++;
	return n;
}

// Los especiales que NO hacen falta (cambiarlos por comunes no cambia ni los pasos ni los agarres del camino más corto) pasan a comunes. Igual que RoomLib.audit_specials.
static bool auditSpecials(const Room &room, Final &cur, string &why) {
	if (!exactRoom(room, cur, why)) return false;
	for (char ch : SPECIAL_CHARS) {
		int count = countKind(cur.room, ch);
		if (count == 0) continue;
		Final alln;
		string w2;
		if (exactRoom(replaceKind(cur.room, ch), alln, w2) && alln.moves == cur.moves && alln.grabs == cur.grabs) {
			cur = alln;
			continue;
		}
		if (count < 2) continue;
		vector<int> cells;
		for (auto &kv : cur.room.cols) cells.push_back(kv.first);
		for (int c : cells) {
			string ks = cur.room.cols.count(c) ? cur.room.cols[c] : "";
			for (size_t i = 0; i < ks.size(); i++) {
				if (ks[i] != ch) continue;
				Final one;
				string w3;
				if (exactRoom(replaceKind(cur.room, ch, c, (int)i + 1), one, w3) && one.moves == cur.moves && one.grabs == cur.grabs) cur = one;
			}
		}
	}
	string sp;
	for (char ch : SPECIAL_CHARS)
		if (countKind(cur.room, ch) > 0) sp += ch;
	cur.specials = sp;
	return true;
}

// --- construir salas ----------------------------------------------------------------------------------------------------------
static mt19937_64 RNG(1);
static int rnd(int lo, int hi) { return lo + (int)(RNG() % (unsigned long long)(hi - lo + 1)); }
static double rnd01() { return (double)(RNG() >> 11) / 9007199254740992.0; }

static Room makeRoom(const string &shape, int h) {
	Room r;
	r.shape = shape;
	r.h = h;
	return r;
}

// La escalera a pie: columnas pegadas de h - 1, h - 2... de alto; la primera toca el pilar. Igual que RoomMiner.staircase (búsqueda en profundidad al azar).
static bool ladderWalk(vector<int> &path, set<int> &used, const set<int> &freeSet, int need, int &budget, const Shape &sh) {
	if ((int)path.size() >= need) {
		// ¿Se llega a pie al escalón más bajo? Por el suelo vacío desde las celdas pegadas a la llegada.
		vector<int> seeds;
		for (int c : sh.cells) {
			int x = ckx(c), z = ckz(c);
			int dx = x - sh.nx, dz = z - sh.nz;
			if (!(x == sh.ex && z == sh.ez) && !used.count(c) && dx * dx + dz * dz <= 2) seeds.push_back(c);
		}
		set<int> seen(seeds.begin(), seeds.end());
		vector<int> q = seeds;
		size_t qi = 0;
		int last = path.back();
		while (qi < q.size()) {
			int c = q[qi++];
			for (int d = 0; d < 4; d++) {
				int n = ck(ckx(c) + DIRS[d].x, ckz(c) + DIRS[d].z);
				if (n == last) return true;
				if (sh.cellSet.count(n) && !(ckx(n) == sh.ex && ckz(n) == sh.ez) && !used.count(n) && !seen.count(n)) {
					seen.insert(n);
					q.push_back(n);
				}
			}
		}
		return false;
	}
	if (--budget < 0) return false;
	int dirs[4] = {0, 1, 2, 3};
	for (int i = 3; i > 0; i--) swap(dirs[i], dirs[rnd(0, i)]);
	for (int di : dirs) {
		int n = ck(ckx(path.back()) + DIRS[di].x, ckz(path.back()) + DIRS[di].z);
		if (freeSet.count(n) && !used.count(n)) {
			used.insert(n);
			path.push_back(n);
			if (ladderWalk(path, used, freeSet, need, budget, sh)) return true;
			path.pop_back();
			used.erase(n);
		}
	}
	return false;
}

static bool makeLadder(const string &shape, int h, Room &out) {
	const Shape &sh = SHAPES[shape];
	set<int> freeSet(sh.freeCells.begin(), sh.freeCells.end());
	vector<int> starts;
	for (int d = 0; d < 4; d++) {
		int n = ck(sh.ex + DIRS[d].x, sh.ez + DIRS[d].z);
		if (freeSet.count(n)) starts.push_back(n);
	}
	if (starts.empty()) return false;
	int budget = 6000;
	for (int t = 0; t < 8; t++) {
		int start = starts[rnd(0, (int)starts.size() - 1)];
		vector<int> path = {start};
		set<int> used = {start};
		if (ladderWalk(path, used, freeSet, h - 1, budget, sh)) {
			out = makeRoom(shape, h);
			for (size_t i = 0; i < path.size(); i++) out.cols[path[i]] = string((size_t)(h - 1 - (int)i), 'n');
			cleanCols(out);
			return true;
		}
	}
	return false;
}

static char kindChar(int k) { return k >= 0 && k < 8 ? KIND_CH[k] : 'n'; }

// La sala que resulta de poner los bloques [x, y, z, tipo] en la arena de `base` (los huecos entre bloques quedan como '.').
static Room roomFromLayout(const Room &base, const vector<array<int, 4>> &blocks) {
	Room r = makeRoom(base.shape, base.h);
	r.fuse = base.fuse;
	map<int, map<int, char>> byCol;
	for (auto &b : blocks) byCol[ck(b[0], b[2])][b[1]] = kindChar(b[3]);
	for (auto &kv : byCol) {
		int top = 0;
		for (auto &yy : kv.second) top = max(top, yy.first);
		string s;
		for (int y = 1; y <= top; y++) s += kv.second.count(y) ? kv.second[y] : '.';
		r.cols[kv.first] = s;
	}
	return r;
}

// --- salida -------------------------------------------------------------------------------------------------------------------
static string line(const Final &f) {
	char buf[64];
	snprintf(buf, sizeof buf, "%.3f", f.reach);
	return "R|" + f.room.shape + "|" + to_string(f.room.h) + "|" + to_string(f.room.fuse) + "|" + to_string(f.moves) + "|" + to_string(f.grabs) + "|" + buf + "|" + f.specials + "|" + (f.path.empty() ? "-" : f.path) + "|" + colsText(f.room);
}

static bool parseLine(const string &ln, Room &r, string &path) {
	vector<string> p;
	size_t i = 0;
	while (true) {
		size_t j = ln.find('|', i);
		if (j == string::npos) {
			p.push_back(ln.substr(i));
			break;
		}
		p.push_back(ln.substr(i, j - i));
		i = j + 1;
	}
	if (p.size() < 10 || p[0] != "R") return false;
	r = makeRoom(p[1], atoi(p[2].c_str()));
	if (!SHAPES.count(r.shape)) return false;
	r.fuse = atoi(p[3].c_str());
	path = p[8] == "-" ? "" : p[8];
	return parseCols(p[9], r);
}

// --- la mina ------------------------------------------------------------------------------------------------------------------
struct Elite {
	Final f;
	double diff = 0.0;
};
struct Cell {
	string shape;
	int h;
	vector<Elite> elites;
	long long outputs = 0;
};

struct Cfg {
	string out = "generador.txt";
	long long steps = 200;
	string shapes = "3x3,3x5,3x8,L,U";
	int hlo = MINH, hhi = MAXH_ALL;
	int part = 0, parts = 1;
	double minDiff = 0.2, minReach = 0.5;
	int nodes = 300000, evalN = 14, topK = 24, keep = 8;
	double pType = 0.3, pMutate = 0.12, pSeed = 0.1;
	int minIce = 0, minSlides = 0;   // sólo se escriben salas con al menos tantos bloques de hielo y tantos resbalones/empujes de hielo en el camino (el escenario Glaciar)
	unsigned long long seed = 1;
};

static double diffOf(const Final &f) { return f.moves > 0 ? (double)f.grabs / (double)f.moves : 0.0; }

static set<string> SEEN;
static long long statEval = 0, statOk = 0, statOut = 0;
static map<string, long long> FAIL;
static ofstream OUTF;

static void emit(const Cfg &cfg, Cell &cell, const Final &f, const char *source) {
	if (diffOf(f) < cfg.minDiff && f.specials.empty()) return;
	if (f.reach < cfg.minReach) return;
	if (cfg.minIce > 0 && countKind(f.room, 'i') < cfg.minIce) return;
	if (f.slides < cfg.minSlides) return;
	OUTF << line(f) << "|" << source << "|" << f.slides << "\n";
	OUTF.flush();
	cell.outputs++;
	statOut++;
}

// Mete la sala en los elites de la celda (se queda con los más difíciles, distintos entre sí).
static bool insertElite(const Cfg &cfg, Cell &cell, const Final &f) {
	Elite e;
	e.f = f;
	e.diff = (diffOf(f) + 0.01 * min(f.grabs, 30) / 30.0) * (f.reach >= cfg.minReach ? 1.0 : 0.7);   // (a igual dificultad, más agarres; las de poco alcance valen menos: sirven de escalón pero no salen)
	for (auto &x : cell.elites)
		if (roomKey(x.f.room) == roomKey(f.room)) return false;
	cell.elites.push_back(e);
	sort(cell.elites.begin(), cell.elites.end(), [](const Elite &a, const Elite &b) { return a.diff > b.diff; });
	if ((int)cell.elites.size() > cfg.keep) cell.elites.pop_back();
	return true;
}

// Evalúa una sala candidata de punta a punta (estructura, resolverla exacta, auditar los especiales). true si pasa y sale la sala final.
static string lastWhy;
static bool evaluate(Room room, Final &out) {
	string why = fullValidate(room);
	if (why != "") {
		FAIL["estructura_" + why]++;
		lastWhy = "estructura_" + why;
		return false;
	}
	string key = roomKey(room);
	if (SEEN.count(key)) {
		FAIL["repetida"]++;
		lastWhy = "repetida";
		return false;
	}
	SEEN.insert(key);
	statEval++;
	Final f;
	if (!auditSpecials(room, f, why)) {
		FAIL["resolver_" + why]++;
		lastWhy = "resolver_" + why;
		return false;
	}
	string key2 = roomKey(f.room);
	if (key2 != key) {
		if (SEEN.count(key2)) {
			FAIL["repetida"]++;
			return false;
		}
		SEEN.insert(key2);
	}
	out = f;
	statOk++;
	return true;
}

static void excavateStep(const Cfg &cfg, Cell &cell, const Elite &par) {
	Room base = par.f.room;
	Sim root = loadRoom(base);
	const Shape &sh = SHAPES[base.shape];
	exMaxNodes = cfg.nodes;
	exTopK = cfg.topK;
	exEntryX = sh.nx;
	exEntryZ = sh.nz;
	exExitX = sh.ex;
	exExitZ = sh.ez;
	exMinD = 0;
	exColumns = 0;   // los bloques pueden quedar sostenidos por sus vecinos (sin columna hasta el piso)
	exMaxY = base.h - 1;
	exNoFloor = false;
	exKeepSpecials = false;
	exArenaOk.assign(64 * 64, 0);   // sólo las celdas donde puede haber columnas (no la salida ni las pegadas a la llegada)
	for (int k : sh.freeCells) exArenaOk[ckx(k) * 64 + ckz(k)] = 1;
	exCheckStable = true;
	exPath = par.f.path;
	heurMode = 0;
	ExcRes ex = excavateRun(root);
	// los primeros del ranking y, para variar, otros al azar (el ranking del grafo explorado sobrestima)
	vector<int> order;
	for (int i = 0; i < (int)ex.top.size(); i++) order.push_back(i);
	int headN = min(cfg.evalN / 3, (int)order.size());
	vector<int> tail(order.begin() + headN, order.end());
	for (int i = (int)tail.size() - 1; i > 0; i--) swap(tail[i], tail[rnd(0, i)]);
	order.resize(headN);
	order.insert(order.end(), tail.begin(), tail.end());
	int tried = 0;
	for (int oi : order) {
		if (tried >= cfg.evalN) break;
		const ExcCand &ec = ex.top[oi];
		if (ec.d > 0 && (double)ec.g / (double)ec.d < 0.75 * diffOf(par.f)) continue;   // (el grafo sobrestima: si ni así supera a la sala de la que sale, no se gasta la búsqueda exacta)
		Room cand = roomFromLayout(base, ec.blocks);
		Final f;
		string key = roomKey(cand);
		if (SEEN.count(key)) continue;
		tried++;
		if (evaluate(cand, f)) {
			emit(cfg, cell, f, "excavada");
			insertElite(cfg, cell, f);
		}
	}
}

static string TYPE_POOL = "icbkts";   // los especiales que puede insertar el paso de tipos (--types)
static double P_ICE = 0.0;   // si es mayor que 0, esa fracción de las veces el paso de tipos inserta hielo (--p-ice)

// Cambia unos bloques por un especial; la sala sólo se queda si ese especial HACE FALTA (sale de la auditoría con ese tipo).
static void typeStep(const Cfg &cfg, Cell &cell, const Elite &par, map<char, long long> &kindCount) {
	int np = (int)TYPE_POOL.size();
	char want = TYPE_POOL[(size_t)rnd(0, np - 1)];
	// se prefiere el tipo del que menos salas salieron
	long long best = 1LL << 60;
	for (int t = 0; t < 3; t++) {
		char c = TYPE_POOL[(size_t)rnd(0, np - 1)];
		if (kindCount[c] < best) {
			best = kindCount[c];
			want = c;
		}
	}
	if (P_ICE > 0.0 && TYPE_POOL.find('i') != string::npos && rnd01() < P_ICE) want = 'i';
	Room r = par.f.room;
	vector<pair<int, int>> blocks;   // (celda, piso) de los comunes
	for (auto &kv : r.cols)
		for (size_t i = 0; i < kv.second.size(); i++)
			if (kv.second[i] == 'n') blocks.push_back({kv.first, (int)i});
	if (blocks.empty()) return;
	vector<pair<int, int>> under;   // los bloques sobre los que se para el jugador en su camino: ahí un especial tiene más chance de hacer falta
	underOut = &under;
	replayPath(r, par.f.path, r.fuse);
	underOut = nullptr;
	vector<pair<int, int>> guided;
	for (auto &u : under) {
		auto it = r.cols.find(u.first);
		if (it != r.cols.end() && u.second >= 0 && u.second < (int)it->second.size() && it->second[(size_t)u.second] == 'n') guided.push_back(u);
	}
	int n = rnd(1, P_ICE > 0.0 && want == 'i' ? 5 : 3);
	for (int i = 0; i < n; i++) {
		pair<int, int> b = (!guided.empty() && rnd01() < 0.8) ? guided[rnd(0, (int)guided.size() - 1)] : blocks[rnd(0, (int)blocks.size() - 1)];
		r.cols[b.first][(size_t)b.second] = want;
	}
	if (want == 'b' && r.fuse == 0) r.fuse = 6;
	Final f;
	if (!evaluate(r, f)) {
		FAIL[string("t_") + want + "_" + lastWhy]++;
		return;
	}
	if (f.specials.find(want) == string::npos) {   // el especial no hace falta: no sirve para lo que se busca
		FAIL["tipo_no_hace_falta"]++;
		FAIL[string("t_") + want + "_no_hace_falta"]++;
		return;
	}
	if (diffOf(f) < 0.6 * diffOf(par.f)) {
		FAIL["tipo_baja_dificultad"]++;
		return;
	}
	kindCount[want]++;
	FAIL[string("t_") + want + "_BIEN"]++;
	emit(cfg, cell, f, "tipos");
	insertElite(cfg, cell, f);
}

// Un cambio chico al azar sobre una sala (poner, sacar, mover, cambiar el tipo de un bloque).
static void mutateStep(const Cfg &cfg, Cell &cell, const Elite &par) {
	Room r = par.f.room;
	const Shape &sh = SHAPES[r.shape];
	int ops = 1;
	while (rnd01() < 0.35 && ops < 4) ops++;
	for (int o = 0; o < ops; o++) {
		double p = rnd01();
		int a = sh.freeCells[rnd(0, (int)sh.freeCells.size() - 1)];
		int b = sh.freeCells[rnd(0, (int)sh.freeCells.size() - 1)];
		if (p < 0.25) {
			string &cur = r.cols[a];
			if ((int)cur.size() < r.h - 1) cur += (rnd01() < 0.05 ? 'h' : 'n');
		} else if (p < 0.5) {
			string &cur = r.cols[a];
			if (!cur.empty()) cur.pop_back();
		} else if (p < 0.85) {
			string &from = r.cols[a];
			string &to = r.cols[b];
			if (a != b && !from.empty() && (int)to.size() < r.h - 1) {
				to += from.back();
				from.pop_back();
			}
		} else {
			string &cur = r.cols[a];
			if (cur.size() > 1) cur.erase((size_t)rnd(0, (int)cur.size() - 2), 1);
		}
	}
	cleanCols(r);
	Final f;
	if (evaluate(r, f)) {
		emit(cfg, cell, f, "mutada");
		insertElite(cfg, cell, f);
	}
}

static vector<string> splitStr(const string &s, char sep) {
	vector<string> out;
	size_t i = 0;
	while (i <= s.size()) {
		size_t j = s.find(sep, i);
		if (j == string::npos) j = s.size();
		out.push_back(s.substr(i, j - i));
		i = j + 1;
	}
	return out;
}

// Las celdas chicas (pocos pisos) rinden las salas más difíciles (pocos pasos de trepar, muchos de empujar): reciben más pasos.
static Cell *pickCell(vector<Cell *> &mine) {
	double tot = 0, w[512];
	int n = min((int)mine.size(), 512);
	for (int i = 0; i < n; i++) {
		int h = mine[i]->h;
		w[i] = h <= 5 ? 3.0 : (h == 6 ? 2.0 : (h <= 8 ? 1.0 : 0.5));
		tot += w[i];
	}
	double r = rnd01() * tot;
	for (int i = 0; i < n; i++) {
		r -= w[i];
		if (r <= 0) return mine[i];
	}
	return mine[n - 1];
}

static int mina(const Cfg &cfg) {
	OUTF.open(cfg.out, ios::app);
	if (!OUTF) {
		fprintf(stderr, "no se pudo abrir %s\n", cfg.out.c_str());
		return 2;
	}
	vector<Cell> cells;
	for (const string &sn : splitStr(cfg.shapes, ','))
		if (SHAPES.count(sn))
			for (int h = max(cfg.hlo, MINH); h <= min(cfg.hhi, maxHeight(sn)); h++) cells.push_back({sn, h, {}, 0});
	// cada copia (--part=I --parts=N) trabaja con las celdas I, I + N...
	vector<Cell *> mine;
	for (size_t i = 0; i < cells.size(); i++)
		if ((int)(i % (size_t)cfg.parts) == cfg.part) mine.push_back(&cells[i]);
	if (mine.empty()) return 0;
	map<char, long long> kindCount;
	auto t0 = chrono::steady_clock::now();
	for (long long step = 0; step < cfg.steps; step++) {
		Cell &cell = *pickCell(mine);
		bool seeded = cell.elites.empty() || rnd01() < cfg.pSeed;
		if (seeded) {   // una semilla nueva: una escalera, que se excava
			Room lad;
			if (!makeLadder(cell.shape, cell.h, lad)) {
				FAIL["sin_escalera"]++;
				continue;
			}
			SolveRes res = solveRoom(lad, true, false, EXACT_CAP);
			if (res.status != "solved") {
				FAIL["escalera_" + res.status]++;
				continue;
			}
			Elite e;
			e.f.room = lad;
			e.f.path = res.path;
			e.f.moves = res.moves;
			e.f.grabs = 0;
			excavateStep(cfg, cell, e);
			continue;
		}
		// un padre: los más difíciles tienen más chance
		double tot = 0, w[32];
		int n = min((int)cell.elites.size(), 32);
		for (int i = 0; i < n; i++) {
			w[i] = 0.05 + cell.elites[i].diff * cell.elites[i].diff;
			tot += w[i];
		}
		double rr = rnd01() * tot;
		int pick = n - 1;
		for (int i = 0; i < n; i++) {
			rr -= w[i];
			if (rr <= 0) {
				pick = i;
				break;
			}
		}
		Elite par = cell.elites[pick];
		double r = rnd01();
		if (r < cfg.pType) typeStep(cfg, cell, par, kindCount);
		else if (r < cfg.pType + cfg.pMutate) mutateStep(cfg, cell, par);
		else excavateStep(cfg, cell, par);
		if (step % 20 == 19) {
			long long ms = chrono::duration_cast<chrono::milliseconds>(chrono::steady_clock::now() - t0).count();
			fprintf(stderr, "[generador %d] paso %lld/%lld · %lld evaluadas · %lld buenas · %lld salidas · %.1f s\n", cfg.part, step + 1, cfg.steps, statEval, statOk, statOut, ms / 1000.0);
		}
	}
	long long ms = chrono::duration_cast<chrono::milliseconds>(chrono::steady_clock::now() - t0).count();
	fprintf(stderr, "[generador %d] listo: %lld evaluadas, %lld buenas, %lld salidas, %.1f s\n", cfg.part, statEval, statOk, statOut, ms / 1000.0);
	for (auto &kv : FAIL) fprintf(stderr, "   fallo %s: %lld\n", kv.first.c_str(), kv.second);
	for (auto &c : cells) {
		double best = 0;
		for (auto &e : c.elites) best = max(best, diffOf(e.f));
		if (!c.elites.empty()) fprintf(stderr, "   %s h%d: %lld salidas, mejor dificultad %.2f\n", c.shape.c_str(), c.h, c.outputs, best);
	}
	return 0;
}

// Vuelve a resolver, auditar y medir salas ya hechas (una por línea con el formato de salida; el camino se ignora).
static int auditar(const string &in, const string &outp, double minReach) {
	ifstream fi(in);
	if (!fi) {
		fprintf(stderr, "no se pudo abrir %s\n", in.c_str());
		return 2;
	}
	ofstream fo(outp);
	string ln;
	long long total = 0, good = 0, bad = 0, low = 0;
	while (getline(fi, ln)) {
		if (ln.empty()) continue;
		Room r;
		string path;
		if (!parseLine(ln, r, path)) {
			bad++;
			continue;
		}
		total++;
		if (fullValidate(r) != "") {
			bad++;
			continue;
		}
		Final f;
		string why;
		if (!auditSpecials(r, f, why)) {
			bad++;
			continue;
		}
		if (f.reach < minReach) {
			low++;
			continue;
		}
		fo << line(f) << "|auditada\n";
		good++;
		if (total % 200 == 0) fprintf(stderr, "[auditar] %lld salas, %lld buenas\n", total, good);
	}
	fprintf(stderr, "[auditar] listo: %lld leídas, %lld buenas, %lld con poco alcance, %lld descartadas\n", total, good, low, bad);
	return 0;
}

int main(int argc, char **argv) {
	initShapes();
	if (argc < 2) {
		fprintf(stderr, "uso: generador mina|auditar ...\n");
		return 2;
	}
	string mode = argv[1];
	Cfg cfg;
	string in;
	for (int i = 2; i < argc; i++) {
		string a = argv[i];
		size_t eq = a.find('=');
		if (a.rfind("--", 0) != 0 || eq == string::npos) continue;
		string k = a.substr(2, eq - 2), v = a.substr(eq + 1);
		if (k == "out") cfg.out = v;
		else if (k == "in") in = v;
		else if (k == "seed") cfg.seed = strtoull(v.c_str(), nullptr, 10);
		else if (k == "steps") cfg.steps = atoll(v.c_str());
		else if (k == "shapes") cfg.shapes = v;
		else if (k == "hlo") cfg.hlo = atoi(v.c_str());
		else if (k == "hhi") cfg.hhi = atoi(v.c_str());
		else if (k == "part") cfg.part = atoi(v.c_str());
		else if (k == "parts") cfg.parts = max(1, atoi(v.c_str()));
		else if (k == "min-diff") cfg.minDiff = atof(v.c_str());
		else if (k == "min-reach") cfg.minReach = atof(v.c_str());
		else if (k == "nodes") cfg.nodes = atoi(v.c_str());
		else if (k == "eval") cfg.evalN = atoi(v.c_str());
		else if (k == "top") cfg.topK = atoi(v.c_str());
		else if (k == "keep") cfg.keep = atoi(v.c_str());
		else if (k == "p-type") cfg.pType = atof(v.c_str());
		else if (k == "p-mutate") cfg.pMutate = atof(v.c_str());
		else if (k == "p-seed") cfg.pSeed = atof(v.c_str());
		else if (k == "min-ice") cfg.minIce = atoi(v.c_str());
		else if (k == "min-slides") cfg.minSlides = atoi(v.c_str());
		else if (k == "p-ice") P_ICE = atof(v.c_str());
		else if (k == "types") {   // --types=i,h,c,s : qué especiales puede insertar (y auditar) el paso de tipos
			string pool;
			for (char c : v)
				if (string("icbkths").find(c) != string::npos && pool.find(c) == string::npos) pool += c;
			if (!pool.empty()) {
				TYPE_POOL = pool;
				SPECIAL_CHARS = pool;
				for (char c : string("icbkts"))
					if (SPECIAL_CHARS.find(c) == string::npos) SPECIAL_CHARS += c;   // (lo que ya se audita siempre se sigue auditando)
			}
		}
	}
	RNG.seed(cfg.seed * 7919ULL + (unsigned long long)cfg.part * 104729ULL + 1ULL);
	if (mode == "mina") return mina(cfg);
	if (mode == "auditar") return auditar(in, cfg.out, cfg.minReach);
	fprintf(stderr, "modo desconocido: %s\n", mode.c_str());
	return 2;
}
