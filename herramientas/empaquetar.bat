@echo off
rem Junta los archivos de todos los mineros de una carpeta en una sola biblioteca (sin repetidas, con las reglas actuales, sin lo que ya no funciona).
rem Uso:  empaquetar.bat [carpeta_de_los_mineros] [archivo_de_salida]
rem   salida .jsonl = texto (la abre el Estudio y se puede leer);  salida .rooms = comprimida (la que viajara con el juego)
setlocal
set IN=%~f1
if "%IN%"=="" set IN=%~dp0..\biblioteca
set OUT=%~f2
if "%OUT%"=="" set OUT=%IN%\biblioteca.jsonl
cd /d "%~dp0.."
if exist "build\herramientas\Empaquetador.console.exe" (
	"build\herramientas\Empaquetador.console.exe" --headless -- --in="%IN%" --out="%OUT%"
) else (
	"tools\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://scenes/pack.tscn -- --in="%IN%" --out="%OUT%"
)
endlocal
