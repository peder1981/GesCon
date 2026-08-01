@echo off
rem Sem acentos: o console do Windows abre em codepage 850/437.
rem
rem Use SO se o GesCon fechar com a mensagem:
rem   "Fyne error: window creation error"
rem   "Cause: APIUnavailable: WGL: The driver does not appear to support OpenGL"
rem
rem Isso quer dizer que o Windows nao oferece OpenGL 2.0+ -- maquina sem driver
rem de video, ou VM sem aceleracao. Este script copia o Mesa3D para junto do
rem programa, e ele passa a desenhar por software na CPU.
rem
rem POR QUE ISTO NAO E AUTOMATICO: opengl32.dll e import estatico do
rem executavel, entao o Windows o carrega na criacao do processo, antes de
rem qualquer codigo do programa. Se o Mesa nao inicializar nesta maquina --
rem acontece em algumas VMs, por instrucoes de CPU que o libgallium_wgl.dll
rem usa e a vCPU nao tem -- o processo morre no carregador, sem janela e sem
rem mensagem nenhuma. Trocar um erro legivel por silencio total e pior, entao
rem o Mesa so entra quando alguem decide que precisa dele.
rem
rem Para desfazer, use Desativar-renderizacao-por-software.bat.

setlocal
set "ORIGEM=%~dp0mesa"
set "DESTINO=%~dp0app"

if not exist "%ORIGEM%\opengl32.dll" goto :semmesa
if not exist "%DESTINO%\" goto :semapp

echo Copiando o Mesa3D para %DESTINO% ...
copy /y "%ORIGEM%\opengl32.dll" "%DESTINO%\" >nul || goto :erro
copy /y "%ORIGEM%\libgallium_wgl.dll" "%DESTINO%\" >nul || goto :erro

echo.
echo Pronto. Abra o GesCon pelo atalho do menu Iniciar.
echo Se ele passar a nao abrir mais NADA, o Mesa nao funciona nesta maquina:
echo rode Desativar-renderizacao-por-software.bat para voltar atras.
echo.
pause
exit /b 0

:semmesa
echo Nao encontrei os arquivos do Mesa em %ORIGEM%.
pause
exit /b 1

:semapp
echo Nao encontrei a pasta do programa em %DESTINO%.
pause
exit /b 1

:erro
echo.
echo Falha ao copiar. Execute este arquivo como administrador
echo (clique direito, "Executar como administrador").
echo.
pause
exit /b 1
