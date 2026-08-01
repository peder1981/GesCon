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
;  2. Mesa3D FORA do caminho de carregamento. opengl32.dll e import ESTATICO
;     do executavel: o Windows o carrega na criacao do processo, antes de
;     qualquer codigo nosso. Um Mesa que nao inicializa nessa maquina --
;     visto em VM QEMU/QXL, provavelmente instrucoes de CPU que o
;     libgallium_wgl.dll usa e a vCPU nao tem -- mata o processo no
;     carregador: sem janela, sem saida, sem log. Instalar o Mesa ao lado do
;     executavel trocava um erro visivel ("WGL: driver does not support
;     OpenGL") por silencio total.
;
;     Entao ele vai para {app}\mesa\, que nao esta no caminho de busca de
;     DLL, e so entra em jogo se alguem rodar o .bat de ativacao. O padrao e
;     sempre o OpenGL do sistema.
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

[Files]
Source: "GesCon.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "GesConApp-windows-amd64.exe"; DestDir: "{app}\app"; Flags: ignoreversion
; Fora do caminho de busca de DLL. So o .bat abaixo os coloca junto do
; executavel, e so quando o OpenGL do sistema nao serve.
Source: "mesa\opengl32.dll"; DestDir: "{app}\mesa"; Flags: ignoreversion
Source: "mesa\libgallium_wgl.dll"; DestDir: "{app}\mesa"; Flags: ignoreversion
Source: "installer\Ativar-renderizacao-por-software.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "installer\Desativar-renderizacao-por-software.bat"; DestDir: "{app}"; Flags: ignoreversion

[Dirs]
Name: "{commonappdata}\GesCon"; Permissions: users-modify

[Icons]
; Apontam para o lancador, que e quem define ADVPP_DB. Ele e um binario do
; subsistema GUI: nenhum console pisca.
Name: "{group}\GesCon"; Filename: "{app}\GesCon.exe"
Name: "{group}\Ativar renderizacao por software"; Filename: "{app}\Ativar-renderizacao-por-software.bat"; \
    IconFilename: "{app}\GesCon.exe"
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
// Sem heuristica de driver OpenGL aqui. A versao anterior tentava adivinhar,
// pelo registro, se a maquina tinha driver de verdade, e pre-marcava o Mesa
// quando achava que nao. Errou numa VM QXL -- e o preco do erro nao era
// "roda mais devagar", era "nao abre e nao diz nada". Agora o padrao e
// sempre o OpenGL do sistema, e o Mesa e uma acao explicita de quem viu o
// erro do Fyne na tela.
