@echo off
rem Arma bibliotecas\generador_portable\: generador_salas.exe (el generador de generador_salas.py hecho .exe, sin Python) + salas.exe + las salas base de partida (las de data\salas_torre.jsonl) + iniciar_generador.bat y parar_generador.bat.
rem Se copia la carpeta entera (sin salida\) a otra computadora con Windows y se corre iniciar_generador.bat (no hace falta instalar nada). Hace falta PyInstaller (pip install pyinstaller).
setlocal
cd /d "%~dp0.."
if not exist tools\salas.exe call native\construir.bat
python -m PyInstaller --onefile --noconfirm --name generador_salas --distpath bibliotecas\generador_portable --workpath bibliotecas\pyi_trabajo --specpath bibliotecas\pyi_trabajo herramientas\generador_salas.py
if errorlevel 1 exit /b 1
copy /y tools\salas.exe bibliotecas\generador_portable\salas.exe >nul
copy /y data\salas_torre.jsonl bibliotecas\generador_portable\paquete_salas.jsonl >nul
if exist bibliotecas\generador_portable\generador_salas.bat del bibliotecas\generador_portable\generador_salas.bat
(
echo @echo off
echo rem Genera salas sin limite horario con todos los nucleos menos uno. Lo generado queda en la carpeta salida\.
echo rem Se corta cerrando esta ventana o con parar_generador.bat. Con una hora ^(HH:MM^) como argumento corre solo hasta esa hora.
echo cd /d "%%~dp0"
echo set /a PROCESOS=%%NUMBER_OF_PROCESSORS%%-1
echo if "%%1"=="" ^(.\generador_salas.exe --procesos %%PROCESOS%%^) else ^(.\generador_salas.exe --hasta %%1 --procesos %%PROCESOS%%^)
) > bibliotecas\generador_portable\iniciar_generador.bat
(
echo @echo off
echo rem Frena el generador: los procesos terminan enseguida ^(se pierde solo la sala que estaban calculando^). Cerrar la ventana del generador tambien sirve.
echo cd /d "%%~dp0"
echo if not exist salida mkdir salida
echo type nul ^> salida\parar.txt
echo echo Listo: el generador se esta frenando.
) > bibliotecas\generador_portable\parar_generador.bat
echo Listo: bibliotecas\generador_portable\
endlocal
