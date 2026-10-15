@echo off
rem Excavador de salas: es el minero con la excavación prendida (usa el solucionador nativo: sube mucho la cantidad de empujes y tirones) y salas con bloques sin columna hasta el piso.
rem Se deja corriendo. Si se corta (luz, error), vuelve a arrancar y retoma desde su archivo. Puede seguir una biblioteca de minero.bat: copiar sus miner_N.jsonl a la carpeta de salida con los mismos numeros.
rem Uso:  excavador.bat [numero] [carpeta_de_salida]      (cada copia en marcha necesita un numero distinto; por defecto 1 y la carpeta "biblioteca" junto a la carpeta del proyecto)
rem Para detenerlo: crear un archivo llamado STOP en la carpeta de salida.
rem Usa build\herramientas\Minero.console.exe si existe (se arma con herramientas\construir.ps1); si no, el Godot de tools\ con este proyecto.
setlocal
set ID=%1
if "%ID%"=="" set ID=1
set OUT=%~f2
if "%OUT%"=="" set OUT=%~dp0..\biblioteca
cd /d "%~dp0.."
if not exist "%OUT%" mkdir "%OUT%"
:otra_vez
if exist "build\herramientas\Minero.console.exe" (
	"build\herramientas\Minero.console.exe" --headless -- --id=%ID% --out="%OUT%" --excavate=0.85 --excavate-free=1 >> "%OUT%\excavador_%ID%.log" 2>&1
) else (
	"tools\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://scenes/miner.tscn -- --id=%ID% --out="%OUT%" --excavate=0.85 --excavate-free=1 >> "%OUT%\excavador_%ID%.log" 2>&1
)
if exist "%OUT%\STOP" goto fin
echo [%date% %time%] el excavador %ID% se corto: reinicia en 10 segundos >> "%OUT%\excavador_%ID%.log"
timeout /t 10 /nobreak >nul
goto otra_vez
:fin
echo Excavador %ID% detenido.
endlocal
