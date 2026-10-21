# Genera salas nuevas (torre sin núcleo) con varias copias de tools\salas_nuevas.exe a la vez y las junta en bibliotecas\salas_nuevas.jsonl (sin repetir).
# Uso: powershell -ExecutionPolicy Bypass -File herramientas\generar_salas_nuevas.ps1 [-Minutos 30] [-Copias 6] [-Desde 0] [-Prefijo copia]
# (-Desde: desde qué configuración de la lista arranca; de la 5 en adelante son las salas de 5x3 y 8x3)
# Cada copia toma una configuración de la lista (tipo, altura, material extra, exigencia de bloques distintos) y sigue con la semilla siguiente hasta que se acaba el tiempo.
param([int]$Minutos = 30, [int]$Copias = 6, [int]$Desde = 0, [string]$Prefijo = 'copia')
Set-Location (Join-Path $PSScriptRoot "..")
New-Item -ItemType Directory -Force bibliotecas | Out-Null
New-Item -ItemType Directory -Force bibliotecas\sn_corridas | Out-Null
$cfgs = @(
  "tipo=3x3 h=5 extras=7 ef=2 dist=1 dist_exactos=4 climb=500 tope_climb=100000",
  "tipo=3x3 h=6 extras=8 ef=2 dist=1 dist_exactos=5 climb=500 tope_climb=100000",
  "tipo=3x3 h=7 extras=10 ef=2 dist=1 dist_exactos=6 climb=500 tope_climb=150000",
  "tipo=3x3 h=8 extras=11 ef=2 dist=1 dist_exactos=7 climb=400 tope_climb=250000",
  "tipo=3x3 h=9 extras=12 ef=2 dist=1 dist_exactos=8 climb=300 tope_climb=300000",
  "tipo=5x3 h=9 extras=22 ef=1 dist=1 h_exacto=0 dist_exactos=8 climb=300 tope_climb=200000",
  "tipo=5x3 h=12 extras=28 ef=1 dist=1 h_exacto=0 dist_exactos=10 climb=300 tope_climb=200000",
  "tipo=5x3 h=15 extras=34 ef=1 dist=1 h_exacto=0 dist_exactos=13 climb=250 tope_climb=250000",
  "tipo=8x3 h=12 extras=28 ef=1 dist=1 h_exacto=0 dist_exactos=10 climb=300 tope_climb=200000",
  "tipo=8x3 h=18 extras=40 ef=1 dist=1 h_exacto=0 dist_exactos=15 climb=250 tope_climb=300000",
  "tipo=8x3 h=24 extras=52 ef=1 dist=1 h_exacto=0 dist_exactos=20 climb=200 tope_climb=300000"
)
$comun = "wd=12 prof=80 cand=500 evaluar=30 ancho=12 pre=30 temp=3 salto=3 tope_eval=1000000 n=1"
$fin = (Get-Date).AddMinutes($Minutos)
$trabajos = @()
for ($i = 0; $i -lt $Copias; $i++) {
  $cfg = $cfgs[($Desde + $i) % $cfgs.Count]
  $semilla = 1000 + $i * 100000 + [int]((Get-Date).Ticks % 1000)
  $archivo = "bibliotecas\sn_corridas\$($Prefijo)_$i.jsonl"
  $cmd = "`$fin = Get-Date '$($fin.ToString("o"))'; `$s = $semilla; while ((Get-Date) -lt `$fin) { & tools\salas_nuevas.exe --gen $cfg $comun seed=`$s 2>`$null | Add-Content -Encoding ascii '$archivo'; `$s++ }"
  $p = Start-Process powershell -ArgumentList "-NoProfile", "-Command", $cmd -PassThru -WindowStyle Hidden
  $trabajos += $p
}
"Corriendo $Copias copias hasta $($fin.ToString('HH:mm')). Las salas van a bibliotecas\sn_corridas\copia_N.jsonl; para juntarlas: herramientas\juntar_salas_nuevas.ps1"
