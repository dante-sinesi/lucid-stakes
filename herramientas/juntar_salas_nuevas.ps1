# Junta las corridas de bibliotecas\sn_corridas en bibliotecas\salas_nuevas.jsonl sin repetir salas (mismo tipo, altura y bloques).
Set-Location (Join-Path $PSScriptRoot "..")
$vistos = @{}
$salida = @()
foreach ($f in Get-ChildItem bibliotecas\sn_corridas\*.jsonl) {
  foreach ($l in Get-Content $f.FullName -Encoding UTF8) {
    if ($l.Trim() -eq "") { continue }
    try { $d = $l | ConvertFrom-Json } catch { continue }
    $clave = $d.tipo + "|" + $d.meta + "|" + ((($d.bloques | ForEach-Object { "$($_[0]),$($_[1]),$($_[2]),$($_[3])" }) | Sort-Object) -join ";")
    if (-not $vistos.ContainsKey($clave)) { $vistos[$clave] = $true; $salida += $l }
  }
}
$salida | Set-Content bibliotecas\salas_nuevas.jsonl -Encoding utf8
"$($salida.Count) salas en bibliotecas\salas_nuevas.jsonl"
