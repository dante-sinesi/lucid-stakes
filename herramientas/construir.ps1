# Construye los programas de la biblioteca de salas en build\herramientas:
#   Minero.exe (+ Minero.console.exe y Minero.pck)       el minero que se deja corriendo 24/7
#   Estudio.exe (+ Estudio.console.exe y Estudio.pck)    el editor de salas
#   Empaquetador.exe (+ ... .pck)                        junta los archivos de los mineros en una biblioteca
# Cada uno es el motor de Godot (plantilla de lanzamiento) con su propio paquete: ese paquete trae la escena que arranca sola.
# Hace falta tener las plantillas de exportación instaladas (Godot > Administrar plantillas de exportación) y tools\Godot_v4.7.2-stable_win64_console.exe.
# Para copiar a otra PC: la carpeta build\herramientas entera.
# Uso:  powershell -ExecutionPolicy Bypass -File herramientas\construir.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$godot = Join-Path $root "tools\Godot_v4.7.2-stable_win64_console.exe"
$tpl = Join-Path $env:APPDATA "Godot\export_templates\4.7.2.stable"
$out = Join-Path $root "build\herramientas"

if (-not (Test-Path $godot)) { throw "No está $godot" }
if (-not (Test-Path (Join-Path $tpl "windows_release_x86_64.exe"))) { throw "Faltan las plantillas de exportación en $tpl" }
New-Item -ItemType Directory -Force -Path $out | Out-Null

$tools = @(
	@{ name = "Minero"; scene = "res://scenes/miner.tscn" },
	@{ name = "Estudio"; scene = "res://scenes/studio.tscn" },
	@{ name = "Empaquetador"; scene = "res://scenes/pack.tscn" }
)

foreach ($t in $tools) {
	$tmp = Join-Path $env:TEMP ("herramienta_" + $t.name)
	if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
	New-Item -ItemType Directory -Force -Path $tmp | Out-Null
	# una copia del proyecto sin lo que no hace falta
	robocopy $root $tmp /E /NFL /NDL /NJH /NJS /NP /XD .git .godot build tests docs tools herramientas | Out-Null
	$proj = Join-Path $tmp "project.godot"
	(Get-Content $proj -Raw) -replace 'run/main_scene="[^"]*"', ('run/main_scene="' + $t.scene + '"') | Set-Content $proj -NoNewline
	Write-Host ("== " + $t.name)
	& $godot --headless --path $tmp --import 2>&1 | Out-Null
	$pck = Join-Path $out ($t.name + ".pck")
	if (Test-Path $pck) { Remove-Item $pck }
	& $godot --headless --path $tmp --export-pack "Windows Desktop" $pck 2>&1 | Out-Null
	if (-not (Test-Path $pck)) { throw "No se pudo exportar $($t.name)" }
	Copy-Item (Join-Path $tpl "windows_release_x86_64.exe") (Join-Path $out ($t.name + ".exe")) -Force
	Copy-Item (Join-Path $tpl "windows_release_x86_64_console.exe") (Join-Path $out ($t.name + ".console.exe")) -Force
	Remove-Item -Recurse -Force $tmp
	Write-Host ("   " + $pck + " (" + [math]::Round((Get-Item $pck).Length / 1KB) + " KB)")
}
Write-Host "Listo. Programas en $out"
