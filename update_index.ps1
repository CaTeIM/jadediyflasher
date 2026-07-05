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

# Le o arquivo inteiro preservando as quebras de linha originais
$text = Get-Content -LiteralPath $IndexJs -Raw

# Captura o array da board: grupo 1 = "  board: [", grupo 2 = conteudo, grupo 3 = "]"
# (?sm): '.' inclui quebras de linha e '^' casa inicio de linha -> suporta array multi-linha
$pattern = '(?sm)^([ \t]*' + [regex]::Escape($Board) + '\s*:\s*\[)(.*?)(\])'
$match = [regex]::Match($text, $pattern)

if (-not $match.Success) {
    Write-Host "  [AVISO] Board '$Board' nao encontrada no boardFirmwares do index.js"
    exit 1
}

$inner = $match.Groups[2].Value
$versions = @([regex]::Matches($inner, '"([^"]*)"') | ForEach-Object { $_.Groups[1].Value })

if ($versions -contains $Version) {
    Write-Host "  [INFO] Versao $Version ja existe em $Board, nenhuma alteracao necessaria"
    exit 0
}

# Nova versao entra no inicio (mais recente primeiro)
$newList = @($Version) + $versions
$newInner = ($newList | ForEach-Object { '"' + $_ + '"' }) -join ', '
$newSegment = $match.Groups[1].Value + $newInner + $match.Groups[3].Value
$newText = $text.Substring(0, $match.Index) + $newSegment + $text.Substring($match.Index + $match.Length)

# Grava UTF-8 SEM BOM, preservando as quebras de linha originais
[System.IO.File]::WriteAllText($IndexJs, $newText, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "  [OK] index.js atualizado: $Board agora inclui versao $Version"
