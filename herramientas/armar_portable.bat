@echo off
rem Arma bibliotecas\generador_portable\: generador_salas.exe (el generador de generador_salas.py hecho .exe, sin Python) + salas.exe + las salas base de partida (las de data\salas_torre.jsonl).
rem Se copia la carpeta entera a otra computadora con Windows y se corre generador_salas.bat (no hace falta instalar nada). Hace falta PyInstaller (pip install pyinstaller).
setlocal
cd /d "%~dp0.."
if not exist tools\salas.exe call native\construir.bat
python -m PyInstaller --onefile --noconfirm --name generador_salas --distpath bibliotecas\generador_portable --workpath bibliotecas\pyi_trabajo --specpath bibliotecas\pyi_trabajo herramientas\generador_salas.py
if errorlevel 1 exit /b 1
copy /y tools\salas.exe bibliotecas\generador_portable\salas.exe >nul
copy /y data\salas_torre.jsonl bibliotecas\generador_portable\paquete_salas.jsonl >nul
(
echo @echo off
echo rem Genera salas sin limite horario con todos los nucleos menos uno. Lo generado queda en la carpeta salida\.
echo rem Para cortar: crear un archivo parar.txt dentro de salida\ ^(termina lo que esta generando^) o cerrar la ventana. Con una hora ^(HH:MM^) corre solo hasta esa hora.
echo cd /d "%%~dp0"
echo set /a PROCESOS=%%NUMBER_OF_PROCESSORS%%-1
echo if "%%1"=="" ^(generador_salas.exe --procesos %%PROCESOS%%^) else ^(generador_salas.exe --hasta %%1 --procesos %%PROCESOS%%^)
) > bibliotecas\generador_portable\generador_salas.bat
echo Listo: bibliotecas\generador_portable\
endlocal
