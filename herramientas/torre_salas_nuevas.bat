@echo off
rem Prototipo jugable de la torre de salas nuevas. Uso: torre_salas_nuevas.bat [semilla] [salas]
rem Teclas: WASD mueve, Shift + direccion agarra (empuja o tira), Espacio + direccion se cuelga. Camara: arrastrar con el mouse gira e inclina, rueda y + - zoom, flechas giran e inclinan, Q y E giran 90 grados, Tab vista de toda la torre. R otra torre, Esc sale.
setlocal
cd /d "%~dp0.."
if not "%~1"=="" set SN_SEMILLA=%~1
if not "%~2"=="" set SN_SALAS=%~2
if "%SN_PAQUETE%"=="" set SN_PAQUETE=%CD%\bibliotecas\paquete_salas.jsonl
set GAME_SANDBOX=1
tools\Godot_v4.7.2-stable_win64.exe --path . res://salas_nuevas/torre.tscn
