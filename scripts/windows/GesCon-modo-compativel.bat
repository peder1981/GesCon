@echo off
rem Sem acentos de proposito: o console do Windows abre em codepage 850/437 e
rem qualquer acento aqui sairia corrompido na tela.
rem
rem Use este atalho SO se o GesCon fechar com a mensagem:
rem   "Fyne error: window creation error"
rem   "Cause: APIUnavailable: WGL: The driver does not appear to support OpenGL"
rem
rem Isso quer dizer que o Windows esta sem driver de video real -- maquina
rem recem-instalada, ou maquina virtual sem aceleracao. Nesse estado o sistema
rem so oferece OpenGL 1.1 pelo Microsoft Basic Display Adapter, e o Fyne exige
rem 2.0 ou superior. Os DLLs da pasta mesa\ sao o Mesa3D, que desenha por
rem software na CPU. O Windows procura DLL na pasta do executavel antes do
rem System32, entao basta copia-los para ca.
rem
rem Se o driver de video estiver instalado, execute o .exe direto: usa a placa
rem de video e e bem mais rapido. O Mesa fica na pasta mesa\ justamente para
rem nao roubar a aceleracao de quem nao precisa dele -- o opengl32.dll do Mesa
rem nao repassa nada para o driver real, ele substitui.

copy /y "%~dp0mesa\opengl32.dll" "%~dp0" >nul || goto :erro
copy /y "%~dp0mesa\libgallium_wgl.dll" "%~dp0" >nul || goto :erro

start "" "%~dp0GesConApp-windows-amd64.exe"
exit /b 0

:erro
echo.
echo Nao foi possivel copiar os DLLs da pasta mesa\.
echo Extraia o zip inteiro para uma pasta com permissao de escrita
echo (a Area de Trabalho serve) e execute este arquivo de la.
echo.
pause
exit /b 1
