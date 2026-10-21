# Un trabajador del generador de salas nuevas: recorre una lista de (tipo, altura) y para cada una arma la configuración con fórmulas y corre tools\salas_nuevas.exe
# hasta la hora de fin. Lo lanza herramientas\generar_salas_nuevas.ps1 (no hace falta correrlo a mano).
param([string]$Prefijo, [int]$Indice, [string]$Fin, [string]$Tipos)
Set-Location (Join-Path $PSScriptRoot "..")
$alturas = @{
  '3x3' = @(5, 6, 7, 8, 9);
  '5x3' = @(6, 8, 9, 10, 12, 13, 15);
  '8x3' = @(8, 10, 12, 14, 16, 18, 20, 22, 24)
}
$lista = @()
foreach ($t in $Tipos.Split(',')) { foreach ($h in $alturas[$t]) { $lista += ,@($t, $h) } }
function Config($tipo, $h) {
  if ($tipo -eq '3x3') {
    $extras = [int][math]::Ceiling(1.3 * $h + 1)
    return "tipo=3x3 h=$h extras=$extras ef=2 dist=1 dist_exactos=$($h - 2) climb=500 tope_climb=150000 tope_eval=300000 tope_nivel=20000 prof=80 cand=500 ancho=12 pre=30 exacto=1"
  }
  $extras = [int][math]::Ceiling(2.3 * $h)
  $exacto = if ($h -le 9) { 1 } else { 0 }
  $tope = if ($h -le 9) { 200000 } else { 60000 }
  $dist = [int][math]::Floor(0.7 * ($h - 1))
  return "tipo=$tipo h=$h extras=$extras ef=1 dist=1 dist_exactos=$dist climb=250 tope_climb=$tope tope_eval=$tope tope_nivel=$tope prof=60 cand=300 ancho=12 pre=30 exacto=$exacto refinar=0 riesgo=0"
}
$fin = [datetime]::Parse($Fin)
$archivo = "bibliotecas\sn_corridas\$($Prefijo)_$Indice.jsonl"
$k = $Indice * 3
$s = 1000 + $Indice * 100000
while ((Get-Date) -lt $fin) {
  $par = $lista[$k % $lista.Count]
  $cfg = (Config $par[0] $par[1]) -split ' '
  $salida = & tools\salas_nuevas.exe --gen @cfg wd=12 evaluar=16 temp=3 salto=3 n=1 seed=$s 2>$null
  if ($salida) { $salida | Add-Content -Encoding ascii $archivo }
  $k++
  $s++
}
