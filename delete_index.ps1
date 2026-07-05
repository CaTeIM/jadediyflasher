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

# Le o arquivo inteiro preservando as quebras de linha originais
$text = Get-Content -LiteralPath $IndexJs -Raw

# Captura o array da board: grupo 1 = "  board: [", grupo 2 = conteudo, grupo 3 = "]"
# (?sm): '.' inclui quebras de linha e '^' casa inicio de linha -> suporta array multi-linha
$pattern = '(?sm)^([ \t]*' + [regex]::Escape($Board) + '\s*:\s*\[)(.*?)(\])'
$match = [regex]::Match($text, $pattern)

if (-not $match.Success) {
    Write-Host "  [INFO] Board '$Board' nao encontrada em $IndexJs - nenhuma alteracao"
    exit 0
}

$inner = $match.Groups[2].Value
$versions = @([regex]::Matches($inner, '"([^"]*)"') | ForEach-Object { $_.Groups[1].Value })

if ($versions -notcontains $Version) {
    Write-Host "  [INFO] Versao $Version nao encontrada em $Board no index.js - nenhuma alteracao"
    exit 0
}

# Remove a versao (funciona ate quando ela e o unico elemento do array -> fica [])
$newList = @($versions | Where-Object { $_ -ne $Version })
$newInner = ($newList | ForEach-Object { '"' + $_ + '"' }) -join ', '
$newSegment = $match.Groups[1].Value + $newInner + $match.Groups[3].Value
$newText = $text.Substring(0, $match.Index) + $newSegment + $text.Substring($match.Index + $match.Length)

# Grava UTF-8 SEM BOM, preservando as quebras de linha originais
[System.IO.File]::WriteAllText($IndexJs, $newText, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "  [OK] index.js atualizado: versao $Version removida de $Board"
