@echo off
rem La galería de bloques: el arte de 10x10x10 de cada tipo, corrupto y purificado, en las cinco etapas, con el fondo y la luz del juego. Uso: galeria_bloques.bat
cd /d "%~dp0.."
start "" "tools\Godot_v4.7.2-stable_win64.exe" --path . res://scenes/galeria_bloques.tscn
