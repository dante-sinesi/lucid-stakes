@echo off
cd /d "%~dp0.."
set GAME_DEMO=1
start "" "tools\Godot_v4.7.2-stable_win64.exe" --path .
