; installer/gescon.iss -- instalador Windows do GesCon (Inno Setup 6).
;
; Compilar:  ISCC.exe /DAppVersion=1.0.4 installer\gescon.iss
; Espera, ao lado deste .iss:  GesConApp-windows-amd64.exe,  mesa\*.dll  e
; GesCon.exe (o lancador, compilado de installer\launcher)
;
; Tres coisas que o zip solto nao resolvia:
;
;  1. Banco compartilhado entre as contas do Windows. Desde o AdvPP 2.0.11 o
;     banco de um app distribuido mora em %AppData%\advpp\<app>\, que e POR
;     USUARIO -- estavel, mas errado para este caso: o banco e do condominio,
;     nao da conta do Windows. Os atalhos rodam GesCon.cmd, que define
;     ADVPP_DB apontando para {commonappdata}\GesCon, pasta com permissao de
;     escrita para todos. A variavel fica no processo do lancador; definida no
;     ambiente da maquina ela sequestraria tambem advplc/adveditor/advpp-ide,
;     que devem seguir usando o banco do diretorio de projeto.
;
;  2. Mesa3D como opcao de instalacao, nao como copia manual de DLL. O
;     opengl32.dll do Mesa substitui o driver em vez de encadear, entao so
;     entra em quem precisa.
;
;  3. Desinstalacao de verdade, com o banco preservado.

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
UninstallDisplayIcon={app}\GesCon.exe

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na Area de Trabalho"; GroupDescription: "Atalhos:"
; Sem "checkedonce": em reinstalacao o estado default e recalculado por
; InitializeWizard, que e o que queremos -- a maquina pode ter ganhado driver.
Name: "mesa"; Description: "Renderizacao por software (maquina virtual ou sem driver de video)"; GroupDescription: "Compatibilidade:"; Flags: unchecked

[Files]
Source: "GesCon.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "GesConApp-windows-amd64.exe"; DestDir: "{app}\app"; Flags: ignoreversion
; Os DLLs vao para a pasta do EXECUTAVEL, nao a do lancador: e la que o
; Windows procura DLL antes do System32, e o diretorio de trabalho nao entra
; nessa busca.
Source: "mesa\opengl32.dll"; DestDir: "{app}\app"; Tasks: mesa; Flags: ignoreversion
Source: "mesa\libgallium_wgl.dll"; DestDir: "{app}\app"; Tasks: mesa; Flags: ignoreversion

[Dirs]
Name: "{commonappdata}\GesCon"; Permissions: users-modify

[Icons]
; Apontam para o lancador, que e quem define ADVPP_DB. Ele e um binario do
; subsistema GUI: nenhum console pisca.
Name: "{group}\GesCon"; Filename: "{app}\GesCon.exe"
Name: "{group}\Desinstalar o GesCon"; Filename: "{uninstallexe}"
Name: "{autodesktop}\GesCon"; Filename: "{app}\GesCon.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\GesCon.exe"; Description: "Abrir o GesCon agora"; \
    Flags: nowait postinstall skipifsilent

[UninstallDelete]
; So o que o instalador colocou. {commonappdata}\GesCon guarda o banco do
; condominio e fica -- apagar dado de cliente na desinstalacao seria perda
; irreversivel por um clique.
Type: filesandordirs; Name: "{app}\app"

[Code]
// Heuristica para o estado inicial da caixa "Renderizacao por software".
// Um driver de video WDDM real registra OpenGLDriverName na chave da classe
// Display; o Microsoft Basic Display Adapter, nao. So define o default -- o
// usuario marca ou desmarca por cima, entao um palpite errado nao custa nada.
function TemDriverOpenGL(): Boolean;
var
  I: Integer;
  Chave, Valor: String;
begin
  Result := False;
  for I := 0 to 7 do
  begin
    Chave := Format('SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\%.4d', [I]);
    if RegQueryStringValue(HKEY_LOCAL_MACHINE, Chave, 'OpenGLDriverName', Valor) and (Valor <> '') then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure InitializeWizard();
begin
  if not TemDriverOpenGL() then
    WizardSelectTasks('mesa');
end;
