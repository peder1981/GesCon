@echo off
rem Sem acentos: o console do Windows abre em codepage 850/437.
rem
rem Lancador do GesCon instalado. Existe por um motivo so: apontar ADVPP_DB
rem para um banco COMPARTILHADO entre as contas do Windows.
rem
rem Sem isto, o AdvPP guarda o banco de um app distribuido em
rem %AppData%\advpp\<app>\, que e por usuario -- sindico e gestor logados em
rem contas diferentes veriam cada um o seu condominio. O banco e do
rem condominio, nao da conta do Windows.
rem
rem Por que um .cmd e nao uma variavel de ambiente da maquina: ADVPP_DB vale
rem para TODA ferramenta AdvPP. Definida no sistema, ela sequestraria tambem
rem o advplc, o adveditor e o advpp-ide, que devem continuar usando o banco
rem do diretorio de projeto onde sao chamados. Aqui a variavel so existe
rem dentro deste processo e do que ele inicia.
rem
rem O atalho do menu Iniciar roda este arquivo minimizado, entao o console
rem nao chega a aparecer: o "start" devolve na hora e o cmd encerra.

set "ADVPP_DB=%ProgramData%\GesCon\GesCon.db"
start "" "%~dp0GesConApp-windows-amd64.exe"
