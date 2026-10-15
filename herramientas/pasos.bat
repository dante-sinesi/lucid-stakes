@echo off
rem Estudio de pasos: disenar piezas chicas de sala (una fila de pinchos, un camino de hielo...), marcar el tramo que se repite y probar todos los largos.
rem Uso:  pasos.bat [archivo.jsonl]      (por defecto pasos\pasos.jsonl junto a la carpeta del proyecto; si no existe se muestran dos ejemplos)
setlocal
set LIB=%~f1
if "%LIB%"=="" set LIB=%~dp0..\pasos\pasos.jsonl
cd /d "%~dp0.."
if not exist "%~dp0..\pasos" mkdir "%~dp0..\pasos"
if exist "build\herramientas\Estudio.exe" (
	start "" "build\herramientas\Estudio.exe" -- --lib="%LIB%" --pasos
) else (
	start "" "tools\Godot_v4.7.2-stable_win64.exe" --path . res://scenes/step_studio.tscn -- --lib="%LIB%"
)
endlocal
