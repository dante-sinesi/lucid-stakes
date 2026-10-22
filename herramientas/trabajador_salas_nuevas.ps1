# Un trabajador del generador de salas nuevas: recorre una lista de (tipo, altura) y para cada una arma la configuración con fórmulas y corre tools\salas_nuevas.exe
# hasta la hora de fin. Lo lanza herramientas\generar_salas_nuevas.ps1 (no hace falta correrlo a mano).
param([string]$Prefijo, [int]$Indice, [string]$Fin, [string]$Tipos, [int]$NivelFijo = 0, [int]$HMax = 99, [switch]$PorDemanda, [string]$Exe = 'tools\salas_nuevas.exe', [int]$Giro = 0)
Set-Location (Join-Path $PSScriptRoot "..")
$alturas = @{
  '3x3' = @(5, 6, 7, 8, 9);
  '5x3' = @(6, 8, 9, 10, 12, 13, 15);
  '8x3' = @(8, 10, 12, 14, 16, 18, 20, 22, 24)
}
$lista = @()
foreach ($t in $Tipos.Split(',')) { foreach ($h in $alturas[$t]) { if ($h -le $HMax) { $lista += ,@($t, $h) } } }
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
  return "tipo=$tipo h=$h extras=$extras ef=$ef dist=1 dist_exactos=$dist climb=$climb tope_climb=$tope tope_eval=$tope tope_nivel=$tope prof=$prof cand=300 ancho=12 pre=30 exacto=$exacto refinar=$refinar riesgo=$riesgo giro=$Giro"
}
# Alturas que se prueban para cada (nivel, tipo) en el modo por demanda (bibliotecas\sn_demanda.json lo escribe herramientas\clasificar_salas_nuevas.py)
$alt_demanda = @{
  'facil'     = @{ '3x3' = @(5, 6, 7);  '5x3' = @(6, 8, 9);      '8x3' = @(8, 9, 10, 11) };
  'media'     = @{ '3x3' = @(5, 6, 7);  '5x3' = @(8, 9, 10, 12); '8x3' = @(9, 10, 12, 14) };
  'dificil'   = @{ '3x3' = @(6, 7, 8);  '5x3' = @(10, 12, 13);   '8x3' = @(12, 14, 16, 18) };
  'pesadilla' = @{ '3x3' = @(7, 8, 9);  '5x3' = @(12, 13, 15);   '8x3' = @(16, 18, 20, 22, 24) }
}
function Elegir-Demanda() {
  $ruta = "bibliotecas\sn_demanda.json"
  if (-not (Test-Path $ruta)) { return $null }
  try { $dem = Get-Content $ruta -Raw | ConvertFrom-Json } catch { return $null }
  if (-not $dem) { return $null }
  $dem = @($dem)
  $total = ($dem | Measure-Object -Property falta -Sum).Sum
  if (-not $total -or $total -le 0) { return $null }
  $r = Get-Random -Minimum 0 -Maximum $total
  foreach ($c in $dem) { $r -= $c.falta; if ($r -lt 0) { return $c } }
  return $dem[0]
}
$fin = [datetime]::Parse($Fin)
$archivo = "bibliotecas\sn_corridas\$($Prefijo)_$Indice.jsonl"
$k = $Indice * 3
$s = 1000 + $Indice * 100000
while ((Get-Date) -lt $fin) {
  $par = $lista[$k % $lista.Count]
  $nivel = @(1, 2, 1, 3, 2, 4, 3, 5)[$k % 8]   # (se reparte entre los cinco niveles de dificultad: más fáciles que difíciles)
  if ($NivelFijo -gt 0) { $nivel = $NivelFijo }
  if ($PorDemanda) {
    $c = Elegir-Demanda
    if (-not $c) { Start-Sleep -Seconds 30; continue }   # (la composición está completa: espera por si cambia)
    $hs = $alt_demanda[$c.nivel][$c.tipo]
    $par = @($c.tipo, ($hs | Get-Random))
    $nivel = switch ($c.nivel) { 'facil' { Get-Random -InputObject @(1, 2) } 'media' { 3 } 'dificil' { 4 } default { 5 } }
  }
  $cfg = (Config $par[0] $par[1] $nivel) -split ' '
  $salida = & $Exe --gen @cfg wd=12 evaluar=16 temp=3 salto=3 n=1 seed=$s 2>$null
  if ($salida) { $salida | Add-Content -Encoding ascii $archivo }
  $k++
  $s++
}
