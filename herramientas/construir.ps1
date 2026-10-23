# Exporta el juego a build\: el juego completo (BalatroXCatherine.exe) y la demo (demo\BalatroXCatherineDemo.exe), con el motor de lanzamiento de Godot.
# Hace falta tener las plantillas de exportación instaladas (Godot > Administrar plantillas de exportación) y tools\Godot_v4.7.2-stable_win64_console.exe.
# Uso:  powershell -ExecutionPolicy Bypass -File herramientas\construir.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$godot = Join-Path $root "tools\Godot_v4.7.2-stable_win64_console.exe"
$tpl = Join-Path $env:APPDATA "Godot\export_templates\4.7.2.stable"
$out = Join-Path $root "build"

if (-not (Test-Path $godot)) { throw "No está $godot" }
if (-not (Test-Path (Join-Path $tpl "windows_release_x86_64.exe"))) { throw "Faltan las plantillas de exportación en $tpl" }
New-Item -ItemType Directory -Force -Path $out, (Join-Path $out "demo") | Out-Null

Write-Host "== importando"
& $godot --headless --path $root --import 2>&1 | Out-Null

Write-Host "== juego completo"
& $godot --headless --path $root --export-release "Windows Desktop" (Join-Path $out "BalatroXCatherine.exe") 2>&1 | Out-Null
if (-not (Test-Path (Join-Path $out "BalatroXCatherine.exe"))) { throw "No se pudo exportar el juego" }

Write-Host "== demo"
& $godot --headless --path $root --export-release "Windows Demo" (Join-Path $out "demo\BalatroXCatherineDemo.exe") 2>&1 | Out-Null
if (-not (Test-Path (Join-Path $out "demo\BalatroXCatherineDemo.exe"))) { throw "No se pudo exportar la demo" }

Write-Host "Listo. Exportado en $out"
