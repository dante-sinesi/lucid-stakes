# Genera salas nuevas (torre sin núcleo) con varias copias de tools\salas_nuevas.exe a la vez y las deja en bibliotecas\sn_corridas\<prefijo>_N.jsonl
# (después: herramientas\juntar_salas_nuevas.ps1 las junta sin repetir en bibliotecas\salas_nuevas.jsonl).
# Uso: powershell -ExecutionPolicy Bypass -File herramientas\generar_salas_nuevas.ps1 [-Minutos 30] [-Copias 6] [-Prefijo lote] [-Tipos 3x3,5x3,8x3]
# Cada copia recorre una lista de (tipo, altura) arrancando en un punto distinto (herramientas\trabajador_salas_nuevas.ps1): 3x3 de 5 a 9 pisos, 5x3 de 6 a 15, 8x3 de 8 a 24.
# El material extra es ~1,3 bloques por piso en el 3x3 y ~2,3 en el 5x3 y el 8x3 (las salas grandes necesitan mucho más para poder desordenarse).
# Hasta 9 pisos el solucionador es exacto; más alto se arma y se mejora con lonjas y el mínimo real se calcula después (salas_nuevas\refinar_biblioteca.gd).
param([int]$Minutos = 30, [int]$Copias = 6, [string]$Prefijo = 'lote', [string]$Tipos = '3x3,5x3,8x3')
Set-Location (Join-Path $PSScriptRoot "..")
New-Item -ItemType Directory -Force bibliotecas\sn_corridas | Out-Null
$fin = (Get-Date).AddMinutes($Minutos).ToString('o')
for ($i = 0; $i -lt $Copias; $i++) {
  Start-Process powershell -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "herramientas\trabajador_salas_nuevas.ps1", "-Prefijo", $Prefijo, "-Indice", $i, "-Fin", $fin, "-Tipos", $Tipos -WindowStyle Hidden | Out-Null
}
"Corriendo $Copias copias hasta las $((Get-Date).AddMinutes($Minutos).ToString('HH:mm')). Las salas van a bibliotecas\sn_corridas\$($Prefijo)_N.jsonl; para juntarlas: herramientas\juntar_salas_nuevas.ps1"
