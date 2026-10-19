@echo off
rem Busca salas del escenario Glaciar sin parar (hielo con pesado, agrietado y pinchos como companeros; ver docs\plan_glaciar.md).
rem Corre en rondas hasta que se cierre la ventana y va sumando en build\generador_prueba\glaciar.rooms (la biblioteca del Glaciar, aparte de la comun).
rem Uso:  generador_glaciar.bat [--pasos=1500] [--procesos=N] [--altura=11]
rem Para verlas: herramientas\estudio.bat build\generador_prueba\glaciar.rooms   (orden "Resbalones (hielo)" y filtro "Resbalones >=").
setlocal
cd /d "%~dp0.."
if not exist tools\generador.exe (
	echo Falta tools\generador.exe: se arma con native\construir.bat
	exit /b 1
)
set GAME_SANDBOX=1
"tools\Godot_v4.7.2-stable_win64.exe" --path . res://scenes/generador_todo.tscn -- --glaciar %*
endlocal
