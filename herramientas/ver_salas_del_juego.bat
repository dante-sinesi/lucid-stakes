@echo off
rem Abre el Estudio de salas con TODAS las salas que trae el juego (data\salas_torre.jsonl). Trabaja sobre una copia (bibliotecas\salas_del_juego.jsonl): lo que se corrija ahi no toca el juego.
setlocal
cd /d "%~dp0.."
if not exist bibliotecas mkdir bibliotecas
copy /Y data\salas_torre.jsonl bibliotecas\salas_del_juego.jsonl >nul
call herramientas\estudio_salas.bat bibliotecas\salas_del_juego.jsonl
