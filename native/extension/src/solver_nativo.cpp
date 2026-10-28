#include "solver_nativo.h"

#include <godot_cpp/core/class_db.hpp>

#include <string>

std::string salas_resolver_texto(const std::string &entrada);

using namespace godot;

void SolverNativo::_bind_methods() {
	ClassDB::bind_method(D_METHOD("resolver_texto", "sala"), &SolverNativo::resolver_texto);
}

String SolverNativo::resolver_texto(const String &p_sala) const {
	std::string salida = salas_resolver_texto(std::string(p_sala.utf8().get_data()));
	return String::utf8(salida.c_str());
}
