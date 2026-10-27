@echo off
rem Arma bibliotecas\generador_portable\: generador_salas.exe (el generador de noche_salas.py hecho .exe, sin Python) + salas.exe + las salas base de partida.
rem Se copia la carpeta entera a otra computadora con Windows y se corre generador_salas.bat (no hace falta instalar nada). Hace falta PyInstaller (pip install pyinstaller).
setlocal
cd /d "%~dp0.."
if not exist tools\salas.exe call native\construir.bat
python -m PyInstaller --onefile --noconfirm --name generador_salas --distpath bibliotecas\generador_portable --workpath bibliotecas\pyi_trabajo --specpath bibliotecas\pyi_trabajo herramientas\noche_salas.py
if errorlevel 1 exit /b 1
copy /y tools\salas.exe bibliotecas\generador_portable\salas.exe >nul
if exist bibliotecas\paquete_salas.jsonl copy /y bibliotecas\paquete_salas.jsonl bibliotecas\generador_portable\paquete_salas.jsonl >nul
(
echo @echo off
echo rem Genera salas hasta la hora indicada ^(por omision 08:00 de manana^) con todos los nucleos menos uno. Lo generado queda en la carpeta salida\.
echo cd /d "%%~dp0"
echo generador_salas.exe --hasta %%1 --procesos %%NUMBER_OF_PROCESSORS%%
) > bibliotecas\generador_portable\generador_salas.bat
echo Listo: bibliotecas\generador_portable\
endlocal
