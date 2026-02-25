@echo off

chcp 65001 > NUL
setlocal enabledelayedexpansion

:: Elevar privilégios automaticamente
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Elevando privilégios para administrador...
    powershell -Command "Start-Process -FilePath '%COMSPEC%' -ArgumentList '/c %~f0' -Verb runAs"
    exit /b
)

@echo off
REM Script para automatizar o deploy e gestão de firmwares CaTeIM Jade DIY
REM
REM COMO USAR:
REM 1. Compile e assine seu firmware normalmente
REM 2. Execute o arquivo deploy_firmware.bat diretamente (duplo clique ou via cmd)
REM

REM --- CONFIGURAÇÕES ---
REM Altere estes caminhos para corresponderem ao seu ambiente
set "buildDirtdisplay=D:\GitHub\tdisplay\Jade"
set "buildDirtdisplays3=D:\GitHub\tdisplays3\Jade"
set "buildDirwaveshares3=D:\GitHub\waveshares3\Jade"
set "githubDir=D:\CaTeIM\Google Drive\GitHub\jadediyflasher"

REM --- INÍCIO DO SCRIPT ---
cls

:INICIO
REM Limpa variáveis para evitar cache
set "placa="
set "modo="
set "versao="
set "confirmar="
set "buildDir="
set "placaNome="
set "placaExibicao="
set "sobrescrever="

echo.
echo ==========================================
echo   CaTeIM Jade DIY -- Gestao de Firmware
echo ==========================================
echo.
echo O que deseja fazer?
echo.
echo [1] Deploy de novo firmware
echo [2] Apagar um firmware existente
echo.
echo [0] Sair
echo.

set "modo="
set /p modo="Digite o numero e pressione Enter: "
set "modo=!modo: =!"

if "%modo%"=="0" (
    echo.
    echo Saindo do script. Nenhuma acao sera realizada.
    pause
    exit /b
)

if "%modo%"=="1" goto SELECAO_PLACA
if "%modo%"=="2" goto SELECAO_PLACA_APAGAR

echo.
echo [ERRO] Opcao invalida. Escolha 1, 2 ou 0.
timeout /t 2 >nul
cls
goto INICIO

REM ============================================================
REM                    DEPLOY DE FIRMWARE
REM ============================================================

:SELECAO_PLACA
echo.
echo --- Selecione a placa para DEPLOY ---
echo.
echo [1] T-Display
echo [2] T-Display S3
echo [3] Waveshare S3
echo.
echo [0] Voltar ao menu principal
echo.

set "placa="
set /p placa="Digite o numero e pressione Enter: "

if "%placa%"=="0" (
    cls
    goto INICIO
)

if "%placa%"=="" (
    echo.
    echo [ERRO] Voce precisa selecionar uma opcao valida!
    echo.
    timeout /t 2 >nul
    goto SELECAO_PLACA
)

if "%placa%"=="1" (
    set "buildDir=%buildDirtdisplay%"
    set "placaNome=tdisplay"
    set "placaExibicao=T-Display"
)
if "%placa%"=="2" (
    set "buildDir=%buildDirtdisplays3%"
    set "placaNome=tdisplays3"
    set "placaExibicao=T-Display S3"
)
if "%placa%"=="3" (
    set "buildDir=%buildDirwaveshares3%"
    set "placaNome=waveshares3"
    set "placaExibicao=Waveshare S3"
)

if not defined buildDir (
    echo.
    echo [ERRO] Opcao invalida. Escolha apenas 1, 2 ou 3.
    echo.
    timeout /t 2 >nul
    goto SELECAO_PLACA
)

echo.
echo ========================================
echo Placa selecionada: %placaExibicao%
echo ========================================
echo.
set "confirmar="
set /p confirmar="Deseja prosseguir com esta placa? (S=Sim / N=Voltar): "

if "%confirmar%"=="" (
    echo [ERRO] Voce precisa digitar S ou N!
    timeout /t 2 >nul
    goto SELECAO_PLACA
)

if /i "%confirmar%"=="N" goto SELECAO_PLACA

if /i not "%confirmar%"=="S" (
    echo [ERRO] Opcao invalida. Digite apenas S ou N.
    timeout /t 2 >nul
    goto SELECAO_PLACA
)

:PERGUNTA_VERSAO
echo.
set "versao="
set /p versao="Digite a versao do novo firmware (ex: 1.0.xx-yy): "

if "%versao%"=="" (
    echo.
    echo [ERRO] A versao nao pode ser vazia! Digite um nome valido.
    echo.
    timeout /t 2 >nul
    goto PERGUNTA_VERSAO
)

REM Define os caminhos de origem e destino
set "destinoDir=%githubDir%\assets\%placaNome%\%versao%"
set "fonteBuildDir=%buildDir%\build"

REM Verificação prévia dos arquivos
echo.
echo Verificando arquivos de origem...
echo.

set "arquivosOk=1"

if not exist "%fonteBuildDir%\bootloader\bootloader.bin" (
    echo   [ERRO] Arquivo nao encontrado: bootloader.bin
    set "arquivosOk=0"
)
if not exist "%fonteBuildDir%\jade.bin" (
    echo   [ERRO] Arquivo nao encontrado: jade.bin
    set "arquivosOk=0"
)
if not exist "%fonteBuildDir%\ota_data_initial.bin" (
    echo   [ERRO] Arquivo nao encontrado: ota_data_initial.bin
    set "arquivosOk=0"
)
if not exist "%fonteBuildDir%\partition_table\partition-table.bin" (
    echo   [ERRO] Arquivo nao encontrado: partition-table.bin
    set "arquivosOk=0"
)

if "%arquivosOk%"=="0" (
    echo.
    echo ========================================
    echo [ERRO CRITICO] Arquivos faltando!
    echo ========================================
    echo.
    echo Caminho de origem: %fonteBuildDir%
    echo.
    echo [1] Tentar outra placa
    echo [0] Sair do script
    echo.

    set "escolhaErro="
    set /p escolhaErro="Digite sua escolha: "

    if "!escolhaErro!"=="1" (
        cls
        goto SELECAO_PLACA
    ) else (
        goto SAIR
    )
)

echo   [OK] Todos os arquivos foram encontrados!
echo.

REM Verifica se o diretório já existe
if exist "%destinoDir%" (
    echo ========================================
    echo [AVISO] Diretorio ja existe!
    echo ========================================
    echo Caminho: %destinoDir%
    echo.
    echo [1] Sobrescrever os arquivos existentes
    echo [2] Alterar o nome da versao
    echo [0] Cancelar e voltar ao inicio
    echo.

    :ESCOLHA_SOBRESCREVER
    set "sobrescrever="
    set /p sobrescrever="Digite sua escolha: "

    if "!sobrescrever!"=="" (
        echo [ERRO] Voce precisa escolher uma opcao!
        echo.
        goto ESCOLHA_SOBRESCREVER
    )
    if "!sobrescrever!"=="2" (
        echo.
        timeout /t 1 >nul
        goto PERGUNTA_VERSAO
    )
    if "!sobrescrever!"=="0" (
        cls
        goto INICIO
    )
    if "!sobrescrever!"=="1" (
        echo.
        echo [OK] Os arquivos serao sobrescritos.
        echo.
    ) else (
        echo [ERRO] Opcao invalida! Escolha 1, 2 ou 0.
        echo.
        goto ESCOLHA_SOBRESCREVER
    )
)

REM Mostra configuração final
echo.
echo ========================================
echo Configuracao do Deploy:
echo   Placa: %placaExibicao%
echo   Versao: %versao%
echo   Destino: %destinoDir%
echo ========================================
echo.

REM Cria a pasta de destino se não existir
if not exist "%destinoDir%" (
    echo Criando diretorio de destino...
    mkdir "%destinoDir%"
    echo.
)

REM Copia os arquivos
echo Iniciando copia dos arquivos .bin...
echo.

copy /Y "%fonteBuildDir%\bootloader\bootloader.bin" "%destinoDir%\bootloader.bin" >nul
echo   [OK] Copiado 'bootloader.bin'

copy /Y "%fonteBuildDir%\jade.bin" "%destinoDir%\jade.bin" >nul
echo   [OK] Copiado 'jade.bin'

copy /Y "%fonteBuildDir%\ota_data_initial.bin" "%destinoDir%\ota_data_initial.bin" >nul
echo   [OK] Copiado 'ota_data_initial.bin'

copy /Y "%fonteBuildDir%\partition_table\partition-table.bin" "%destinoDir%\partition-table.bin" >nul
echo   [OK] Copiado 'partition-table.bin'

REM Atualiza o boardFirmwares no index.js
echo.
echo Atualizando index.js com a nova versao...

set "indexJs=%githubDir%\index.js"
set "updateScript=%githubDir%\update_index.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%updateScript%" -Board "%placaNome%" -Version "%versao%" -IndexJs "%indexJs%"

echo.
echo ========================================
echo Deploy Concluido!
echo ========================================
echo Verifique a pasta:
echo %destinoDir%
echo.

set "continuar="
set /p continuar="Deseja fazer outro deploy? (S/N): "

if "%continuar%"=="" (
    echo Nenhuma opcao selecionada. Encerrando...
    timeout /t 2 >nul
    goto SAIR
)
if /i "%continuar%"=="S" (
    cls
    goto INICIO
)
if /i "%continuar%"=="N" goto SAIR

echo Opcao invalida. Encerrando...
timeout /t 2 >nul
goto SAIR

REM ============================================================
REM                  APAGAR FIRMWARE EXISTENTE
REM ============================================================

:SELECAO_PLACA_APAGAR
echo.
echo --- Selecione a placa para APAGAR firmware ---
echo.
echo [1] T-Display
echo [2] T-Display S3
echo [3] Waveshare S3
echo.
echo [0] Voltar ao menu principal
echo.

set "placa="
set /p placa="Digite o numero e pressione Enter: "

if "%placa%"=="0" (
    cls
    goto INICIO
)

if "%placa%"=="" (
    echo.
    echo [ERRO] Voce precisa selecionar uma opcao valida!
    echo.
    timeout /t 2 >nul
    goto SELECAO_PLACA_APAGAR
)

if "%placa%"=="1" (
    set "placaNome=tdisplay"
    set "placaExibicao=T-Display"
)
if "%placa%"=="2" (
    set "placaNome=tdisplays3"
    set "placaExibicao=T-Display S3"
)
if "%placa%"=="3" (
    set "placaNome=waveshares3"
    set "placaExibicao=Waveshare S3"
)

if not defined placaNome (
    echo.
    echo [ERRO] Opcao invalida. Escolha apenas 1, 2 ou 3.
    echo.
    timeout /t 2 >nul
    goto SELECAO_PLACA_APAGAR
)

REM Lista os firmwares disponíveis para a placa
set "boardAssetsDir=%githubDir%\assets\%placaNome%"

if not exist "%boardAssetsDir%" (
    echo.
    echo [AVISO] Nenhum firmware encontrado para %placaExibicao%.
    echo Pasta: %boardAssetsDir%
    echo.
    pause
    cls
    goto INICIO
)

echo.
echo ========================================
echo Firmwares disponiveis para %placaExibicao%:
echo ========================================
echo.

set "fwCount=0"
for /d %%D in ("%boardAssetsDir%\*") do (
    set /a fwCount+=1
    set "fw!fwCount!=%%~nxD"
    echo   [!fwCount!] %%~nxD
)

if "%fwCount%"=="0" (
    echo   [!] nenhum firmware encontrado
    echo.
    pause
    cls
    goto INICIO
)

echo.
echo [0] Cancelar e voltar ao menu principal
echo.

:SELECAO_VERSAO_APAGAR
set "escolhaFw="
set /p escolhaFw="Selecione o numero do firmware a apagar: "

REM remove espacos que causam bug de parse no cmd ("3 " virar "3")
set "escolhaFw=!escolhaFw: =!"

if "%escolhaFw%"=="0" (
    cls
    goto INICIO
)

if "%escolhaFw%"=="" (
    echo [ERRO] Selecione uma opcao valida.
    goto SELECAO_VERSAO_APAGAR
)

REM Valida se a escolha e um numero valido dentro do array listado
set "valido=0"
set "versaoApagar="
for /L %%i in (1,1,%fwCount%) do (
    if "%escolhaFw%"=="%%i" (
        set "valido=1"
        set "versaoApagar=!fw%%i!"
    )
)

if "!valido!"=="0" (
    echo [ERRO] Numero invalido. Escolha entre 1 e %fwCount%.
    goto SELECAO_VERSAO_APAGAR
)

set "apagarDir=%boardAssetsDir%\!versaoApagar!"

echo.
echo ========================================
echo [ATENCAO] Confirme a exclusao:
echo   Placa: %placaExibicao%
echo   Versao: %versaoApagar%
echo   Pasta: %apagarDir%
echo ========================================
echo.
echo Esta acao e IRREVERSIVEL. Apagara os binarios e removera a versao do index.js.
echo.

:CONFIRMA_APAGAMENTO
set "confirmaApagar="
set /p confirmaApagar="Tem certeza? (S=Confirmar / N=Cancelar): "
set "confirmaApagar=!confirmaApagar: =!"

if /i "%confirmaApagar%"=="N" (
    echo Operacao cancelada.
    timeout /t 2 >nul
    cls
    goto INICIO
)

if /i not "%confirmaApagar%"=="S" (
    echo [ERRO] Opcao invalida. Digite S ou N.
    timeout /t 2 >nul
    goto CONFIRMA_APAGAMENTO
)

REM Apaga a pasta do firmware
echo.
echo Apagando pasta de firmware...
rmdir /s /q "%apagarDir%"

if exist "%apagarDir%" (
    echo   [ERRO] Nao foi possivel apagar a pasta: %apagarDir%
    pause
    goto SAIR
)
echo   [OK] Pasta apagada: %apagarDir%

REM Remove a versao do index.js
echo.
echo Atualizando index.js...

set "indexJs=%githubDir%\index.js"
set "deleteScript=%githubDir%\delete_index.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%deleteScript%" -Board "%placaNome%" -Version "%versaoApagar%" -IndexJs "%indexJs%"

echo.
echo ========================================
echo Firmware Apagado com Sucesso!
echo ========================================
echo   Placa: %placaExibicao%
echo   Versao: %versaoApagar%
echo.

set "continuar="
set /p continuar="Deseja apagar outro firmware? (S/N): "

if /i "%continuar%"=="S" (
    cls
    goto INICIO
)
goto SAIR

:SAIR
echo.
echo Encerrando o script. Ate logo!
pause
exit /b