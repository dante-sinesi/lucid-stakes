@echo off
rem Pone en marcha varias copias del minero (una por nucleo, mas o menos). Cada una escribe su propio archivo en la misma carpeta.
rem Uso:  minero_varios.bat [cantidad] [carpeta_de_salida]      (por defecto la mitad de los procesadores y la carpeta bibliotecas\minero)
setlocal
set N=%1
if "%N%"=="" (
	set /a N=%NUMBER_OF_PROCESSORS% / 2
)
if %N% LSS 1 set N=1
set OUT=%2
if "%OUT%"=="" set OUT=%~dp0..\bibliotecas\minero
for /L %%i in (1,1,%N%) do (
	start "Minero %%i" /min cmd /c ""%~dp0minero.bat" %%i "%OUT%""
)
echo Se pusieron en marcha %N% mineros. Para detenerlos: crear un archivo STOP en %OUT%
endlocal
