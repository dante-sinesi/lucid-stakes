# Mantiene al día bibliotecas\sn_demanda.json (lo que falta para la composición objetivo) mientras los trabajadores generan por demanda.
# Uso: powershell -ExecutionPolicy Bypass -File herramientas\controlar_biblioteca.ps1 -Fin "<fecha>" [-Total 600] [-CadaSegundos 300]
param([string]$Fin, [int]$Total = 600, [int]$CadaSegundos = 300)
Set-Location (Join-Path $PSScriptRoot "..")
$fin = [datetime]::Parse($Fin)
while ((Get-Date) -lt $fin) {
  python herramientas\clasificar_salas_nuevas.py estado TOTAL=$Total *> bibliotecas\sn_estado.txt
  Start-Sleep -Seconds $CadaSegundos
}
