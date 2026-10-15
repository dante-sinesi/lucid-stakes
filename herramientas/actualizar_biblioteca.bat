@echo off
rem Actualiza una biblioteca de salas ya generada con las reglas y métricas nuevas: saca las vueltas de los caminos, poda el relleno, mejora el final de cada camino con el verificador exacto
rem y recalcula empujes y tirones, pasos y dificultad. Muestra los promedios antes y después. Es lento (unas 100 salas por minuto).
rem Uso:  actualizar_biblioteca.bat [carpeta_de_los_mineros] [archivo_de_salida]
setlocal
set IN=%~f1
if "%IN%"=="" set IN=%~dp0..\bibliotecas\minero
set OUT=%~f2
if "%OUT%"=="" set OUT=%~dp0..\bibliotecas\biblioteca.jsonl
cd /d "%~dp0.."
set EXE=build\herramientas\Empaquetador.console.exe
if exist "tools\Godot_v4.7.2-stable_win64_console.exe" set EXE=
if defined EXE if not exist "%EXE%" set EXE=
rem (en esta PC, con Godot en tools, se usa el proyecto: siempre es el codigo mas nuevo; en la otra PC, los .exe de construir.ps1)
if defined EXE (
	"%EXE%" --headless -- --in="%IN%" --out="%OUT%" --prune --polish --audit --min-reach=0.5 --verbose
) else (
	"tools\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://scenes/pack.tscn -- --in="%IN%" --out="%OUT%" --prune --polish --audit --min-reach=0.5 --verbose
)
endlocal
