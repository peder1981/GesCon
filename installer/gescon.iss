; installer/gescon.iss -- instalador Windows do GesCon (Inno Setup 6).
;
; Compilar:  ISCC.exe /DAppVersion=1.0.4 installer\gescon.iss
; Espera, ao lado deste .iss:  GesConApp-windows-amd64.exe  e  mesa\*.dll
;
; Tres coisas que o zip solto nao resolvia:
;
;  1. Pasta de dados gravavel. O executavel cria advpp.db no diretorio de
;     trabalho. Extraido em Program Files, o banco nao teria onde nascer. Os
;     atalhos apontam o WorkingDir para {commonappdata}\GesCon, com permissao
;     de escrita para todos os usuarios -- de proposito compartilhado: sindico
;     e gestor tem que ver o mesmo banco, nao um banco por conta do Windows.
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
UninstallDisplayIcon={app}\GesConApp-windows-amd64.exe

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na Area de Trabalho"; GroupDescription: "Atalhos:"
; Sem "checkedonce": em reinstalacao o estado default e recalculado por
; InitializeWizard, que e o que queremos -- a maquina pode ter ganhado driver.
Name: "mesa"; Description: "Renderizacao por software (maquina virtual ou sem driver de video)"; GroupDescription: "Compatibilidade:"; Flags: unchecked

[Files]
Source: "GesConApp-windows-amd64.exe"; DestDir: "{app}"; Flags: ignoreversion
; Os DLLs vao para a pasta do executavel porque e la que o Windows procura
; DLL antes do System32 -- o diretorio de trabalho nao entra nessa busca.
Source: "mesa\opengl32.dll"; DestDir: "{app}"; Tasks: mesa; Flags: ignoreversion
Source: "mesa\libgallium_wgl.dll"; DestDir: "{app}"; Tasks: mesa; Flags: ignoreversion

[Dirs]
Name: "{commonappdata}\GesCon"; Permissions: users-modify

[Icons]
Name: "{group}\GesCon"; Filename: "{app}\GesConApp-windows-amd64.exe"; WorkingDir: "{commonappdata}\GesCon"
Name: "{group}\Desinstalar o GesCon"; Filename: "{uninstallexe}"
Name: "{autodesktop}\GesCon"; Filename: "{app}\GesConApp-windows-amd64.exe"; WorkingDir: "{commonappdata}\GesCon"; Tasks: desktopicon

[Run]
Filename: "{app}\GesConApp-windows-amd64.exe"; WorkingDir: "{commonappdata}\GesCon"; Description: "Abrir o GesCon agora"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; So o que o instalador colocou. {commonappdata}\GesCon guarda o banco do
; condominio e fica -- apagar dado de cliente na desinstalacao seria perda
; irreversivel por um clique.
Type: filesandordirs; Name: "{app}\mesa"

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
