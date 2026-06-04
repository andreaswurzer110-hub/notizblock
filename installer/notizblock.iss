; Inno Setup Skript für Notizblock (Windows)
; Baut eine Setup.exe, die den Release-Build + Visual-C++-Runtime installiert.
; Per-User-Installation ohne Adminrechte (-> %LocalAppData%\Programs\Notizblock).

#define MyAppName "Notizblock AW"
; Version per ISCC /DMyAppVersion=x.y.z überschreibbar (siehe build_installer.ps1).
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#define MyAppPublisher "AW"
#define MyAppExeName "notizblock.exe"
; App-ID: einmal erzeugte GUID, NICHT ändern (sonst erkennt ein Update die
; bestehende Installation nicht und es entstehen Doppel-Einträge).
#define MyAppId "{{A7F3E2C1-9B4D-4E6A-8F12-3C5D7E9A1B20}"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
; Install-Ordner bewusst literal "Notizblock" (nicht der Anzeigename mit
; Leerzeichen) -> stabiler Pfad, passt zur bestehenden Installation.
DefaultDirName={autopf}\Notizblock
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Ohne Adminrechte installieren (per User). {autopf} wird dann zu
; %LocalAppData%\Programs. Der Nutzer kann im Dialog auf "für alle" wechseln.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=output
OutputBaseFilename=Notizblock-Setup-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "german"; MessagesFile: "compiler:Languages\German.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "autostart"; Description: "Notizblock automatisch beim Windows-Start starten (angeheftete Widgets)"; GroupDescription: "Autostart:"; Flags: unchecked

[Files]
; Kompletter Release-Build inkl. data\ und mitgelieferter VC++-Runtime-DLLs.
Source: "stage\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Parameters: "--show-main"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Parameters: "--show-main"; Tasks: desktopicon
; Autostart-Verknüpfung: gleicher Name/Parameter wie die In-App-Einstellung
; (AutostartService legt "Notizblock.lnk" mit --widgets an) -> kein Konflikt.
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Parameters: "--widgets"; Tasks: autostart

[Run]
Filename: "{app}\{#MyAppExeName}"; Parameters: "--show-main"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
