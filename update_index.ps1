<#
.SYNOPSIS
    Atualiza o boardFirmwares no index.js com uma nova versao de firmware.
    Chamado automaticamente pelo deploy_firmware.bat apos o deploy.

.PARAMETER Board
    Nome da board (ex: tdisplay, tdisplays3, waveshares3)

.PARAMETER Version
    Versao do firmware a adicionar (ex: 1.0.38-99)

.PARAMETER IndexJs
    Caminho absoluto para o index.js

.EXAMPLE
    powershell -File update_index.ps1 -Board tdisplay -Version 1.0.38-99 -IndexJs "D:\...\index.js"
#>
param(
    [string]$Board,
    [string]$Version,
    [string]$IndexJs
)

if (-not $Board -or -not $Version -or -not $IndexJs) {
    Write-Host "  [ERRO] Uso: update_index.ps1 -Board <board> -Version <versao> -IndexJs <caminho>"
    exit 1
}

if (-not (Test-Path $IndexJs)) {
    Write-Host "  [ERRO] Arquivo nao encontrado: $IndexJs"
    exit 1
}

$lines = Get-Content $IndexJs
$out = New-Object System.Collections.Generic.List[string]
$updated = $false
$dup = $false

# Pattern: linha com a board no objeto boardFirmwares
$pat = '^\s*' + [regex]::Escape($Board) + ':\s*\['
# Check duplicata
$dupPat = [regex]::Escape('"' + $Version + '"')
# Replace: insere nova versao no inicio do array
$replPat = '^(\s*' + [regex]::Escape($Board) + ':\s*\[)'
$newPrefix = '$1"' + $Version + '", '

foreach ($line in $lines) {
    if ($line -match $pat) {
        if ($line -match $dupPat) {
            $dup = $true
        }
        else {
            $line = $line -replace $replPat, $newPrefix
            $updated = $true
        }
    }
    [void]$out.Add($line)
}

if ($updated) {
    $out | Set-Content $IndexJs -Encoding UTF8
    Write-Host "  [OK] index.js atualizado: $Board agora inclui versao $Version"
}
elseif ($dup) {
    Write-Host "  [INFO] Versao $Version ja existe em $Board, nenhuma alteracao necessaria"
}
else {
    Write-Host "  [AVISO] Board '$Board' nao encontrada no boardFirmwares do index.js"
}
