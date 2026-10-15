@echo off
rem Estudio de salas: ver, jugar, corregir y anotar las salas de una biblioteca.
rem Uso:  estudio.bat [archivo.jsonl o archivo.rooms]      (por defecto biblioteca\biblioteca.jsonl)
setlocal
set LIB=%~f1
if "%LIB%"=="" set LIB=%~dp0..\biblioteca\biblioteca.jsonl
cd /d "%~dp0.."
set EXE=build\herramientas\Estudio.exe
if exist "tools\Godot_v4.7.2-stable_win64_console.exe" set EXE=
if defined EXE if not exist "%EXE%" set EXE=
rem (en esta PC, con Godot en tools, se usa el proyecto: siempre es el codigo mas nuevo; en la otra PC, los .exe de construir.ps1)
if defined EXE (
	start "" "%EXE%" -- --lib="%LIB%"
) else (
	start "" "tools\Godot_v4.7.2-stable_win64.exe" --path . res://scenes/studio.tscn -- --lib="%LIB%"
)
endlocal
