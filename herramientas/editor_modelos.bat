@echo off
rem Editor de modelos: cubos (con variantes), cosmeticos y personajes hechos con minibloques. Herramienta de desarrollo (no es para el jugador).
rem Guarda en data\modelos\*.jsonl. Uso:  editor_modelos.bat
setlocal
cd /d "%~dp0.."
if exist "tools\Godot_v4.7.2-stable_win64.exe" (
	start "" "tools\Godot_v4.7.2-stable_win64.exe" --path . res://scenes/model_editor.tscn
) else (
	start "" "build\herramientas\EditorModelos.exe"
)
endlocal
