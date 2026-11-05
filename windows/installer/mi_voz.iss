; Instalador clásico de Mi Voz para Windows (Inno Setup 6).
;
; 1. flutter build windows --release
; 2. Abre este archivo con Inno Setup (https://jrsoftware.org/isinfo.php) y
;    pulsa "Compile". El instalador queda en build\installer\.
;
; Incluye las bibliotecas de Visual C++ que necesita la app (se copian del
; equipo donde se compila). Para distribuirlo sin la advertencia de
; SmartScreen hay que firmarlo con un certificado de firma de código propio
; (ver docs/DISTRIBUCION.md): este script no incluye ningún certificado.

#define AppName "Mi Voz"
#define AppVersion "1.0.0"
#define AppExe "mi_voz.exe"
#define BuildDir "..\..\build\windows\x64\runner\Release"

[Setup]
; Identificador propio de esta aplicación: no cambiarlo entre versiones.
AppId={{83D17EFF-D2B1-4043-A50C-53A686405381}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppName}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=..\..\build\installer
OutputBaseFilename=MiVoz-{#AppVersion}-instalador
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#BuildDir}\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
; Bibliotecas de Visual C++ (la app no arranca sin ellas en equipos limpios).
Source: "{sys}\msvcp140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{sys}\vcruntime140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{sys}\vcruntime140_1.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
