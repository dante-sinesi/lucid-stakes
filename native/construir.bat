@echo off
rem Compila el solucionador y generador nativo de las salas (hace falta g++, por ejemplo el de MSYS2 en C:\msys64\mingw64\bin). Deja tools\salas_nuevas.exe.
setlocal
cd /d "%~dp0.."
set PATH=C:\msys64\mingw64\bin;%PATH%
if not exist tools mkdir tools
g++ -O3 -std=c++17 -static -o tools\salas_nuevas.exe native\salas_nuevas.cpp
if errorlevel 1 exit /b 1
echo Listo: tools\salas_nuevas.exe
endlocal
