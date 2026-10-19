@echo off
rem Arma (o completa) el banco de torres de la demo: data\torres_demo.torres. Uso:  banco_torres.bat [etapas] [cantidad] [semilla]   (por defecto: 1,2,3,4,5,6 12 5000)
setlocal
cd /d "%~dp0.."
set ST=%1
if "%ST%"=="" set ST=1,2,3,4,5,6
set N=%2
if "%N%"=="" set N=12
set SEED=%3
if "%SEED%"=="" set SEED=5000
set GAME_SANDBOX=1
"tools\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s tests/arma_banco.gd -- %ST% %N% %SEED%
endlocal
