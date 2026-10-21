@echo off
rem Abre el Estudio de salas nuevas (torre sin nucleo). Uso: estudio_salas_nuevas.bat [archivo.jsonl]   (por defecto bibliotecas\salas_nuevas.jsonl)
setlocal
cd /d "%~dp0.."
if not "%~1"=="" set SN_LIB=%~f1
tools\Godot_v4.7.2-stable_win64.exe --path . res://salas_nuevas/estudio.tscn
