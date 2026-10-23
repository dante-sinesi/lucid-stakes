@echo off
rem Abre el Estudio de salas (torre sin nucleo). Uso: estudio_salas.bat [archivo.jsonl]   (por defecto bibliotecas\salas.jsonl)
setlocal
cd /d "%~dp0.."
if not "%~1"=="" set SALAS_ARCHIVO=%~f1
tools\Godot_v4.7.2-stable_win64.exe --path . res://torre/estudio.tscn
