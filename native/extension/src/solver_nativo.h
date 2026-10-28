#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/string.hpp>

// SolverNativo: el solucionador A* exacto de las salas dentro del juego (en vez de lanzar tools/salas.exe). `resolver_texto` recibe la sala en el formato de texto de nativo.gd y devuelve las líneas
// RESULT y PATH del ejecutable; nativo.gd las interpreta igual que antes. Se puede llamar desde varios hilos (cada llamada arma sus propias tablas).
class SolverNativo : public godot::RefCounted {
	GDCLASS(SolverNativo, godot::RefCounted)

protected:
	static void _bind_methods();

public:
	godot::String resolver_texto(const godot::String &p_sala) const;
};
