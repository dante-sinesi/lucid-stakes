extends SceneTree
## Pruebas de la escritura a prueba de cortes (archivo_seguro.gd) y de cómo la usan el guardado y el perfil.
## Ejecutar: GAME_SANDBOX=1 tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/unitarios/test_archivo_seguro.gd

const Seguro := preload("res://scripts/datos/archivo_seguro.gd")
const SaveGame := preload("res://scripts/datos/save_game.gd")
const Profile := preload("res://scripts/datos/profile.gd")

const RUTA := "user://test_seguro.json"
var fails := 0


func check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", label)


func _escribir_crudo(ruta: String, texto: String) -> void:
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	f.store_string(texto)
	f.close()


func _init() -> void:
	Seguro.borrar(RUTA)
	check(Seguro.leer(RUTA).is_empty() and not Seguro.existe(RUTA), "sin archivo: nada que leer")
	check(Seguro.escribir(RUTA, JSON.stringify({"a": 1})), "se escribe")
	check(int(Seguro.leer(RUTA).get("a", 0)) == 1 and not FileAccess.file_exists(RUTA + ".tmp"), "se lee y no queda el temporal")
	Seguro.escribir(RUTA, JSON.stringify({"a": 2}))
	check(int(Seguro.leer(RUTA).a) == 2 and FileAccess.file_exists(RUTA + ".bak"), "la segunda escritura deja la anterior de copia")
	# el archivo principal queda truncado (un corte a mitad de escritura): se lee la copia
	_escribir_crudo(RUTA, '{"a": 3, "b"')
	check(int(Seguro.leer(RUTA).get("a", 0)) == 1, "con el principal dañado se usa la copia (la versión anterior)")
	# y una escritura nueva no pisa la copia buena con el archivo dañado
	Seguro.escribir(RUTA, JSON.stringify({"a": 4}))
	check(int(Seguro.leer(RUTA).a) == 4, "después se vuelve a escribir bien")
	Seguro.borrar(RUTA)
	check(not Seguro.existe(RUTA) and not FileAccess.file_exists(RUTA + ".tmp"), "borrar saca el archivo, la copia y el temporal")
	# el guardado de la partida
	SaveGame.path = "user://test_seguro_save.json"
	SaveGame.delete()
	var datos := {"run": {"claridad": 5}, "phase": "casino", "stage": 2}
	SaveGame.write(datos)
	datos["stage"] = 3
	SaveGame.write(datos)
	_escribir_crudo(SaveGame.path, "{ truncado")
	check(SaveGame.exists() and int(SaveGame.read().get("stage", 0)) == 2, "guardado dañado: continúa con la copia anterior")
	SaveGame.delete()
	check(not SaveGame.exists(), "borrar el guardado borra también la copia")
	# el perfil: un valor de otro tipo se descarta y un archivo dañado cae a la copia
	Profile.path = "user://test_seguro_profile.json"
	Seguro.borrar(Profile.path)
	Profile.data = {}
	Profile._loaded_from = ""
	Profile.load_profile()
	Profile.data.luz = 40
	Profile.save()
	Profile.data.luz = 41
	Profile.save()
	var bueno := FileAccess.get_file_as_string(Profile.path)
	_escribir_crudo(Profile.path, JSON.stringify({"version": Profile.VERSION, "luz": "mucha", "abilities": [1, 2], "best_stage": 7.0, "runs": 3}))
	Profile.data = {}
	Profile._loaded_from = ""
	var p := Profile.load_profile()
	check(int(p.luz) == 0 and p.abilities is Dictionary and int(p.best_stage) == 7 and typeof(p.best_stage) == TYPE_INT and int(p.runs) == 3, "perfil: lo que no es del tipo esperado se descarta, los números se leen bien")
	_escribir_crudo(Profile.path + ".bak", bueno)   # (la copia que dejó la última escritura)
	_escribir_crudo(Profile.path, '{"version": 2, "luz"')
	Profile.data = {}
	Profile._loaded_from = ""
	p = Profile.load_profile()
	check(int(p.luz) == 41, "perfil dañado: se recupera de la copia")
	Seguro.borrar(Profile.path)
	print("tests de la escritura segura terminados, fallos: ", fails)
	quit(1 if fails > 0 else 0)
