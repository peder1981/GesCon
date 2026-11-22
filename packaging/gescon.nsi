; GesCon — instalador Windows (NSIS). Instala por usuário, sem administrador,
; em %LOCALAPPDATA%\Programs\GesCon. Os DADOS ficam em outra pasta,
; %LOCALAPPDATA%\GesCon (criada pelo GesCon.exe): desinstalar não apaga o
; banco do condomínio.
;
; Compilar: makensis -DVERSAO=x.y.z gescon.nsi  (payload\ montado por build-package.sh)

!include "MUI2.nsh"

; Encerra o servidor e o iniciador DESTA instalação antes de copiar ou
; remover arquivos: sem isto, com o GesCon aberto, a atualização não
; substitui o advplc.exe em uso e a desinstalação o deixa para trás (visto no
; Windows 10). Pede ao próprio iniciador (64 bits, PIDs em gescon.pid): o
; NSIS é 32 bits e não enxerga o caminho dos processos de 64 bits, e
; taskkill por nome mataria o advplc de outro sistema (ex.: GEBAN).
!macro EncerraGesCon
    IfFileExists "$INSTDIR\GesCon.exe" 0 +3
        ExecWait '"$INSTDIR\GesCon.exe" --encerrar'
        Sleep 1500
!macroend

!ifndef VERSAO
  !define VERSAO "0.0.0-dev"
!endif

Name "GesCon ${VERSAO}"
OutFile "gescon-setup-${VERSAO}.exe"
InstallDir "$LOCALAPPDATA\Programs\GesCon"
InstallDirRegKey HKCU "Software\GesCon" "InstallDir"
RequestExecutionLevel user
Unicode true
SetCompressor /SOLID lzma

!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "PortugueseBR"

Section "GesCon" SecMain
    SetOutPath "$INSTDIR"
    !insertmacro EncerraGesCon
    ; Atualização: some com os fontes da versão anterior antes de copiar
    RMDir /r "$INSTDIR\app"
    File /r "payload\*.*"
    CreateShortcut "$DESKTOP\GesCon.lnk" "$INSTDIR\GesCon.exe"
    CreateDirectory "$SMPROGRAMS\GesCon"
    CreateShortcut "$SMPROGRAMS\GesCon\GesCon.lnk" "$INSTDIR\GesCon.exe"
    CreateShortcut "$SMPROGRAMS\GesCon\Desinstalar GesCon.lnk" "$INSTDIR\uninstall.exe"
    WriteRegStr HKCU "Software\GesCon" "InstallDir" "$INSTDIR"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\GesCon" "DisplayName" "GesCon"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\GesCon" "DisplayVersion" "${VERSAO}"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\GesCon" "UninstallString" '"$INSTDIR\uninstall.exe"'
    ; Precisa ser gravado aqui: dentro da seção "Uninstall" só rodaria na
    ; hora de desinstalar (lição do pacote GEBAN).
    WriteUninstaller "$INSTDIR\uninstall.exe"
    MessageBox MB_YESNO|MB_ICONQUESTION "GesCon instalado.$\n$\nAbrir agora?" IDNO Fim
        Exec '"$INSTDIR\GesCon.exe"'
    Fim:
SectionEnd

; O nome precisa ser exatamente "Uninstall" (o makensis só reconhece a seção
; de desinstalação por ele).
Section "Uninstall"
    !insertmacro EncerraGesCon
    RMDir /r "$INSTDIR"
    Delete "$DESKTOP\GesCon.lnk"
    RMDir /r "$SMPROGRAMS\GesCon"
    DeleteRegKey HKCU "Software\GesCon"
    DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\GesCon"
    MessageBox MB_OK "Programa removido. Os dados do condomínio continuam em $LOCALAPPDATA\GesCon."
SectionEnd
