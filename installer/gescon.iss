; installer/gescon.iss -- instalador Windows do GesCon (Inno Setup 6).
;
; Compilar:  ISCC.exe /DAppVersion=1.0.9 installer\gescon.iss
; Espera, ao lado deste .iss:  GesConApp-windows-amd64.exe  e  mesa\*.dll
;
; Instalacao deliberadamente plana: o executavel, os DLLs do Mesa e os dois
; scripts, todos em {app}. O icone aponta direto para o executavel.
;
; A versao anterior tinha um executavel lancador que definia ADVPP_DB e
; chamava o programa numa subpasta app\. Ele existia para transportar uma
; string e, em troca, trouxe processo intermediario, heranca de handles e
; falhas que nao aconteciam sem ele -- inclusive relatar erro para um
; programa que tinha aberto normalmente. Foi removido. O caminho do banco
; agora vai num arquivo de texto que o proprio programa le (advpp-db.txt,
; lido por shared.ResolveStandaloneDatabasePath no AdvPP 2.0.15+).
;
; O Mesa3D vem instalado por padrao, ao lado do executavel. Sem OpenGL de
; verdade -- o caso de qualquer VM, e desta em particular, com QXL -- o Fyne
; nao cria janela nenhuma. Desativar-renderizacao-por-software.bat desfaz,
; para o caso raro de o Mesa nao inicializar na maquina.

#ifndef AppVersion
  #define AppVersion "0.0.0-dev"
#endif

[Setup]
; AppId fixo: e o que faz uma versao nova atualizar a instalada em vez de
; instalar do lado. Nao mude entre releases.
AppId={{6F3C1A84-2E5B-4C71-9D0A-8B7E4F2A16C3}
AppName=GesCon
AppVersion={#AppVersion}
AppVerName=GesCon {#AppVersion}
AppPublisher=GesCon
DefaultDirName={autopf}\GesCon
DefaultGroupName=GesCon
OutputDir=.
OutputBaseFilename=GesCon-Setup-{#AppVersion}
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
WizardStyle=modern
DisableProgramGroupPage=yes
UninstallDisplayName=GesCon {#AppVersion}
UninstallDisplayIcon={app}\GesConApp-windows-amd64.exe

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na Area de Trabalho"; GroupDescription: "Atalhos:"

[Files]
Source: "GesConApp-windows-amd64.exe"; DestDir: "{app}"; Flags: ignoreversion
; Ao lado do executavel porque opengl32.dll e import ESTATICO: o Windows
; resolve pelo diretorio do .exe antes do System32, e nao ha como
; redirecionar isso depois que o processo comeca.
Source: "mesa\opengl32.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "mesa\libgallium_wgl.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "installer\Desativar-renderizacao-por-software.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "installer\Ativar-renderizacao-por-software.bat"; DestDir: "{app}"; Flags: ignoreversion

[Dirs]
; Pasta do banco, compartilhada entre as contas do Windows: o banco e do
; condominio, nao de quem abriu o programa.
Name: "{commonappdata}\GesCon"; Permissions: users-modify

[Icons]
Name: "{group}\GesCon"; Filename: "{app}\GesConApp-windows-amd64.exe"
Name: "{group}\Desinstalar o GesCon"; Filename: "{uninstallexe}"
Name: "{autodesktop}\GesCon"; Filename: "{app}\GesConApp-windows-amd64.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\GesConApp-windows-amd64.exe"; Description: "Abrir o GesCon agora"; \
    Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Escritos em tempo de execucao, entao o desinstalador nao os conhece pelo
; [Files]. O banco em {commonappdata}\GesCon fica: apagar dado de cliente
; numa desinstalacao seria perda irreversivel por um clique.
Type: files; Name: "{app}\advpp-db.txt"
Type: files; Name: "{app}\opengl32.dll.off"
Type: files; Name: "{app}\libgallium_wgl.dll.off"

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    // Uma linha, texto puro: e o que o programa le para saber onde fica o
    // banco compartilhado. Substitui o lancador que definia ADVPP_DB.
    SaveStringToFile(
      ExpandConstant('{app}\advpp-db.txt'),
      ExpandConstant('{commonappdata}\GesCon\GesCon.db'),
      False);
end;
