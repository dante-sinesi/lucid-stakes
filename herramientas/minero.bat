@echo off
rem Minero de salas: se deja corriendo. Si se corta (luz, error), vuelve a arrancar y retoma desde su archivo.
rem Uso:  minero.bat [numero] [carpeta_de_salida]      (cada copia en marcha necesita un numero distinto; por defecto 1 y la carpeta bibliotecas\minero dentro del proyecto)
rem Para detenerlo: crear un archivo llamado STOP en la carpeta de salida.
rem Usa build\herramientas\Minero.console.exe si existe (se arma con herramientas\construir.ps1); si no, el Godot de tools\ con este proyecto.
setlocal
set ID=%1
if "%ID%"=="" set ID=1
set OUT=%~f2
if "%OUT%"=="" set OUT=%~dp0..\bibliotecas\minero
cd /d "%~dp0.."
if not exist "%OUT%" mkdir "%OUT%"
:otra_vez
set EXE=build\herramientas\Minero.console.exe
if exist "tools\Godot_v4.7.2-stable_win64_console.exe" set EXE=
if defined EXE if not exist "%EXE%" set EXE=
rem (en esta PC, con Godot en tools, se usa el proyecto: siempre es el codigo mas nuevo; en la otra PC, los .exe de construir.ps1)
if defined EXE (
	"%EXE%" --headless -- --id=%ID% --out="%OUT%" >> "%OUT%\minero_%ID%.log" 2>&1
) else (
	"tools\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://scenes/miner.tscn -- --id=%ID% --out="%OUT%" >> "%OUT%\minero_%ID%.log" 2>&1
)
if exist "%OUT%\STOP" goto fin
echo [%date% %time%] el minero %ID% se corto: reinicia en 10 segundos >> "%OUT%\minero_%ID%.log"
timeout /t 10 /nobreak >nul
goto otra_vez
:fin
echo Minero %ID% detenido.
endlocal
