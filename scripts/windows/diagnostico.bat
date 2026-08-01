@echo off
rem Sem acentos: o console do Windows abre em codepage 850/437.
rem
rem Coleta o que falta para diagnosticar "o aplicativo nao abre". Aplicativos
rem no subsistema GUI nao tem console: qualquer mensagem de erro vai para um
rem stderr que ninguem ve. Redirecionar para arquivo funciona mesmo assim,
rem porque o handle passa a ser valido.
rem
rem Gera diagnostico-gescon.txt na Area de Trabalho.

setlocal enabledelayedexpansion
set LOG=%USERPROFILE%\Desktop\diagnostico-gescon.txt
set APP=%~1
if "%APP%"=="" set APP=C:\Program Files\GesCon\GesConApp-windows-amd64.exe

echo Coletando... isso leva alguns segundos.

> "%LOG%" echo === DIAGNOSTICO GESCON / ADVPP ===
>>"%LOG%" echo Data: %DATE% %TIME%
>>"%LOG%" echo Executavel testado: %APP%
>>"%LOG%" echo.

>>"%LOG%" echo === SISTEMA ===
>>"%LOG%" ver
for /f "tokens=*" %%i in ('wmic os get Caption^,OSArchitecture /value 2^>nul ^| find "="') do >>"%LOG%" echo %%i
>>"%LOG%" echo.

>>"%LOG%" echo === PLACA DE VIDEO E DRIVER ===
for /f "tokens=*" %%i in ('wmic path win32_VideoController get Name^,DriverVersion^,Status /value 2^>nul ^| find "="') do >>"%LOG%" echo %%i
>>"%LOG%" echo.

>>"%LOG%" echo === ARQUIVOS INSTALADOS ===
if exist "%APP%" (>>"%LOG%" echo APP ENCONTRADO) else (>>"%LOG%" echo APP NAO ENCONTRADO NO CAMINHO ACIMA)
for %%d in ("%APP%") do (
    >>"%LOG%" dir /b "%%~dpd" 2>&1
)
>>"%LOG%" echo.

>>"%LOG%" echo === EXECUCAO COM SAIDA CAPTURADA ===
rem O timeout mata o processo se ele abrir de verdade e ficar esperando o
rem usuario -- nesse caso o problema nao e este.
"%APP%" > "%TEMP%\gescon-stdout.txt" 2>&1
>>"%LOG%" echo ERRORLEVEL=%ERRORLEVEL%
>>"%LOG%" echo --- saida do programa ---
>>"%LOG%" type "%TEMP%\gescon-stdout.txt" 2>&1
>>"%LOG%" echo --- fim da saida ---
>>"%LOG%" echo.

>>"%LOG%" echo === EXECUCAO FORCANDO O MODO CONSOLE ===
rem ADVPP_HEADLESS_STANDALONE pula a janela Fyne inteira. Se AQUI funcionar,
rem o defeito esta na criacao da janela (OpenGL); se falhar igual, esta antes.
set ADVPP_HEADLESS_STANDALONE=1
"%APP%" > "%TEMP%\gescon-console.txt" 2>&1
>>"%LOG%" echo ERRORLEVEL=%ERRORLEVEL%
>>"%LOG%" type "%TEMP%\gescon-console.txt" 2>&1
set ADVPP_HEADLESS_STANDALONE=
>>"%LOG%" echo.

>>"%LOG%" echo === EXECUCAO FORCANDO O MESA POR SOFTWARE ===
rem Se o Mesa estiver instalado, isto tira o driver d3d12 da jogada e vai
rem direto ao llvmpipe, que nao depende de nada do sistema.
set GALLIUM_DRIVER=llvmpipe
set LIBGL_ALWAYS_SOFTWARE=1
set MESA_DEBUG=1
"%APP%" > "%TEMP%\gescon-mesa.txt" 2>&1
>>"%LOG%" echo ERRORLEVEL=%ERRORLEVEL%
>>"%LOG%" type "%TEMP%\gescon-mesa.txt" 2>&1
set GALLIUM_DRIVER=
set LIBGL_ALWAYS_SOFTWARE=
set MESA_DEBUG=
>>"%LOG%" echo.

>>"%LOG%" echo === ULTIMOS ERROS DE APLICATIVO NO LOG DO WINDOWS ===
rem E aqui que aparece o modulo que falhou quando o processo morre sem dialogo.
powershell -NoProfile -Command ^
  "Get-WinEvent -FilterHashtable @{LogName='Application';Level=1,2} -MaxEvents 12 -ErrorAction SilentlyContinue | Where-Object { $_.Message -match 'GesCon|advpp|advplc|opengl|gallium|mesa' } | Format-List TimeCreated,ProviderName,Id,Message" >> "%LOG%" 2>&1
>>"%LOG%" echo.
>>"%LOG%" echo === FIM ===

echo.
echo Pronto: %LOG%
echo Abra o arquivo e envie o conteudo.
echo.
pause
endlocal
