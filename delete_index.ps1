<#
.SYNOPSIS
    Remove uma versao de firmware do boardFirmwares no index.js.
    Chamado automaticamente pelo deploy_firmware.bat ao apagar um firmware.

.PARAMETER Board
    Nome da board (ex: tdisplay, tdisplays3, waveshares3)

.PARAMETER Version
    Versao do firmware a remover (ex: 1.0.38)

.PARAMETER IndexJs
    Caminho absoluto para o index.js

.EXAMPLE
    powershell -File delete_index.ps1 -Board tdisplay -Version 1.0.38 -IndexJs "D:\...\index.js"
#>
param(
    [string]$Board,
    [string]$Version,
    [string]$IndexJs
)

if (-not $Board -or -not $Version -or -not $IndexJs) {
    Write-Host "  [ERRO] Uso: delete_index.ps1 -Board <board> -Version <versao> -IndexJs <caminho>"
    exit 1
}

if (-not (Test-Path $IndexJs)) {
    Write-Host "  [ERRO] Arquivo nao encontrado: $IndexJs"
    exit 1
}

$lines = Get-Content $IndexJs
$out = New-Object System.Collections.Generic.List[string]
$updated = $false

# Pattern: linha com a board no objeto boardFirmwares
$pat = '^\s*' + [regex]::Escape($Board) + ':\s*\['

foreach ($line in $lines) {
    if ($line -match $pat) {
        # Remove "version", com virgula+espaco tanto antes quanto depois
        $escaped = [regex]::Escape('"' + $Version + '"')
        $newLine = $line -replace ($escaped + ',\s*'), ''  # versao no inicio ou meio
        $newLine = $newLine -replace (',\s*' + $escaped), ''  # versao no final
        if ($newLine -ne $line) {
            $updated = $true
            $line = $newLine
        }
    }
    [void]$out.Add($line)
}

if ($updated) {
    $out | Set-Content $IndexJs -Encoding UTF8
    Write-Host "  [OK] index.js atualizado: versao $Version removida de $Board"
}
else {
    Write-Host "  [INFO] Versao $Version nao encontrada em $Board no index.js — nenhuma alteracao"
}
