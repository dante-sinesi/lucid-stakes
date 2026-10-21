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
# nivel 1 (tutorial) a 5 (pesadilla): menos material, haz más corto y menos mejora local para las fáciles
function Config($tipo, $h, $nivel) {
  $grande = $tipo -ne '3x3'
  $extras_base = if ($grande) { 2.3 * $h } else { 1.3 * $h + 1 }
  $f = @{ 1 = 0.15; 2 = 0.4; 3 = 0.7; 4 = 0.9; 5 = 1.0 }[$nivel]
  $extras = [int][math]::Max(1, [math]::Ceiling($extras_base * $f))
  $prof = @{ 1 = 8; 2 = 20; 3 = 40; 4 = 60; 5 = 80 }[$nivel]
  $climb = @{ 1 = 0; 2 = 20; 3 = 100; 4 = 250; 5 = 500 }[$nivel]
  $exacto = if ($h -le 9) { 1 } else { 0 }
  $tope = if ($h -le 9) { 200000 } else { 60000 }
  $ef = if ($nivel -le 2 -or $grande) { 1 } else { 2 }
  $dist = if ($nivel -le 2) { 1 } else { [int][math]::Floor(0.6 * ($h - 1)) }
  $refinar = if ($h -le 9) { 0 } else { 3000000 }
  $riesgo = 1
  return "tipo=$tipo h=$h extras=$extras ef=$ef dist=1 dist_exactos=$dist climb=$climb tope_climb=$tope tope_eval=$tope tope_nivel=$tope prof=$prof cand=300 ancho=12 pre=30 exacto=$exacto refinar=$refinar riesgo=$riesgo"
}
$fin = [datetime]::Parse($Fin)
$archivo = "bibliotecas\sn_corridas\$($Prefijo)_$Indice.jsonl"
$k = $Indice * 3
$s = 1000 + $Indice * 100000
while ((Get-Date) -lt $fin) {
  $par = $lista[$k % $lista.Count]
  $nivel = @(1, 2, 1, 3, 2, 4, 3, 5)[$k % 8]   # (se reparte entre los cinco niveles de dificultad: más fáciles que difíciles)
  $cfg = (Config $par[0] $par[1] $nivel) -split ' '
  $salida = & tools\salas_nuevas.exe --gen @cfg wd=12 evaluar=16 temp=3 salto=3 n=1 seed=$s 2>$null
  if ($salida) { $salida | Add-Content -Encoding ascii $archivo }
  $k++
  $s++
}
