@echo off
rem Estudio de pasos: disenar piezas chicas de sala (una fila de pinchos, un camino de hielo...), marcar el tramo que se repite y probar todos los largos.
rem Uso:  pasos.bat [archivo.jsonl]      (por defecto bibliotecas\pasos\pasos.jsonl; si no existe se muestran dos ejemplos)
setlocal
set LIB=%~f1
if "%LIB%"=="" set LIB=%~dp0..\bibliotecas\pasos\pasos.jsonl
cd /d "%~dp0.."
if not exist "%~dp0..\bibliotecas\pasos" mkdir "%~dp0..\bibliotecas\pasos"
set EXE=build\herramientas\Estudio.exe
if exist "tools\Godot_v4.7.2-stable_win64_console.exe" set EXE=
if defined EXE if not exist "%EXE%" set EXE=
rem (en esta PC, con Godot en tools, se usa el proyecto: siempre es el codigo mas nuevo; en la otra PC, los .exe de construir.ps1)
if defined EXE (
	start "" "%EXE%" -- --lib="%LIB%" --pasos
) else (
	start "" "tools\Godot_v4.7.2-stable_win64.exe" --path . res://scenes/step_studio.tscn -- --lib="%LIB%"
)
endlocal
