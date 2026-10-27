@echo off
rem Abre el Estudio de salas con las salas que tienen bombas (archivo bibliotecas\salas_bomba.jsonl). Con "arriba" abre solo las que tienen un bloque justo arriba de una bomba.
rem Uso: ver_salas_bomba.bat [arriba]      En el Estudio, el boton de jugar deja probar la sala con la cuenta de las bombas.
setlocal
cd /d "%~dp0.."
python herramientas\salas_con_bomba.py
if /i "%~1"=="arriba" (call herramientas\estudio_salas.bat bibliotecas\salas_bomba_arriba.jsonl) else (call herramientas\estudio_salas.bat bibliotecas\salas_bomba.jsonl)
