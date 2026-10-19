@echo off
rem Generador de salas, todo en uno y todo nativo: varias copias de tools\generador.exe sacan salas ya resueltas con el solucionador exacto, auditadas (los especiales que no hacen falta pasan a comunes)
rem y medidas; despues una sola pasada de Godot las verifica con las reglas del juego y escribe la biblioteca que viaja con el juego (data\salas.rooms), mezclada con la que ya habia.
rem Uso:  generador.bat [pasos] [procesos] [semilla] [alturas_max]      (por defecto 1500 pasos por proceso, la mitad de los procesadores, semilla 1 y alturas hasta 12)
rem Los topes son de trabajo (pasos), no de tiempo: la misma semilla da las mismas salas. Un paso = una excavacion, una prueba de tipos o una mutacion con sus salas candidatas resueltas.
rem Para repetirlo y sumar mas salas: otra semilla. Sin tocar nada mas: ya queda en data\salas.rooms (la anterior en data\salas.rooms.bak).
setlocal enabledelayedexpansion
cd /d "%~dp0.."
set STEPS=%1
if "%STEPS%"=="" set STEPS=1500
set N=%2
if "%N%"=="" (
	set /a N=%NUMBER_OF_PROCESSORS% / 2
)
if %N% LSS 1 set N=1
set SEED=%3
if "%SEED%"=="" set SEED=1
set HHI=%4
if "%HHI%"=="" set HHI=12
if not exist tools\generador.exe (
	echo Falta tools\generador.exe: se arma con native\construir.bat
	exit /b 1
)
if not exist bibliotecas\generador mkdir bibliotecas\generador
for /L %%i in (0,1,%N%-1) do (
	start "Generador %%i" /min cmd /c "tools\generador.exe mina --out=bibliotecas\generador\gen_%SEED%_%%i.txt --steps=%STEPS% --hhi=%HHI% --seed=%SEED% --part=%%i --parts=%N% 2> bibliotecas\generador\gen_%SEED%_%%i.log"
)
echo Se pusieron en marcha %N% generadores (%STEPS% pasos cada uno, semilla %SEED%). Esperando a que terminen...
:esperar
timeout /t 20 /nobreak >nul
tasklist /fi "imagename eq generador.exe" 2>nul | find /i "generador.exe" >nul
if not errorlevel 1 goto esperar
set GAME_SANDBOX=1
"tools\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://scenes/generador.tscn -- --in=bibliotecas\generador --old=bibliotecas\minero --lib=data\salas.rooms --out=data\salas.rooms --min-reach=0.5
endlocal
