@echo off
rem Compila el solucionador nativo y el generador de salas (hace falta g++, por ejemplo el de MSYS2 en C:\msys64\mingw64\bin). Deja tools\solver_nativo.exe y tools\generador.exe (y las copias en build\herramientas).
setlocal
cd /d "%~dp0.."
set PATH=C:\msys64\mingw64\bin;%PATH%
if not exist tools mkdir tools
g++ -O2 -std=c++17 -static -o tools\solver_nativo.exe native\solver_nativo.cpp
if errorlevel 1 exit /b 1
g++ -O2 -std=c++17 -static -o tools\generador.exe native\generador.cpp
if errorlevel 1 exit /b 1
if not exist build\herramientas mkdir build\herramientas
copy /y tools\solver_nativo.exe build\herramientas\solver_nativo.exe >nul
copy /y tools\generador.exe build\herramientas\generador.exe >nul
echo Listo: tools\solver_nativo.exe y tools\generador.exe
endlocal
