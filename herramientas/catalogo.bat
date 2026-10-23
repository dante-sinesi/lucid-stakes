@echo off
rem Vuelve a generar el catálogo del juego: docs\catalogo.md y docs\catalogo.xlsx (hace falta Python con openpyxl).
setlocal
cd /d "%~dp0.."
set GAME_SANDBOX=1
set CATALOGO_JSON=%TEMP%\catalogo_juego.json
tools\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s herramientas/catalogo.gd
if errorlevel 1 exit /b 1
python herramientas\catalogo.py "%CATALOGO_JSON%"
endlocal
