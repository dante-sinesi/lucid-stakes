@echo off
rem Estudio de salas: ver, jugar, corregir y anotar las salas de una biblioteca.
rem Uso:  estudio.bat [archivo.jsonl o archivo.rooms]      (por defecto biblioteca\biblioteca.jsonl)
setlocal
set LIB=%~f1
if "%LIB%"=="" set LIB=%~dp0..\biblioteca\biblioteca.jsonl
cd /d "%~dp0.."
if exist "build\herramientas\Estudio.exe" (
	start "" "build\herramientas\Estudio.exe" -- --lib="%LIB%"
) else (
	start "" "tools\Godot_v4.7.2-stable_win64.exe" --path . res://scenes/studio.tscn -- --lib="%LIB%"
)
endlocal
