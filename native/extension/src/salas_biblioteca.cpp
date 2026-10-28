// El solucionador de native/salas.cpp como biblioteca (sin su `main`): la extensión de Godot lo llama con el texto de una sala y recibe las líneas RESULT y PATH, igual que el ejecutable.
#define SALAS_BIBLIOTECA
#include "../../salas.cpp"

#include <mutex>

std::string salas_resolver_texto(const std::string& entrada) {
	static std::once_flag una_vez;
	std::call_once(una_vez, [] { init_tablas(); });   // (las tablas de hashing y de vecinos se arman una sola vez)
	try {
		std::istringstream in(entrada);
		return resolver_texto(in);
	} catch (...) {   // (por ejemplo, sin memoria para tantos estados: el juego lo toma como "no se pudo")
		return "RESULT budget 0 0\n";
	}
}
