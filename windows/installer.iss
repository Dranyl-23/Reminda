; Inno Setup Script for Reminda College Timetable Scanner & Scheduler
; Flutter Windows Release Installer

#define MyAppName "Reminda"
#define MyAppVersion "1.0.0+16"
#define MyAppPublisher "Reminda"
#define MyAppURL "https://getreminda.vercel.app"
#define MyAppExeName "Reminda.exe"

[Setup]
; App Metadata
AppId={{E5D9F8B2-16B4-4B10-807F-4357AB37667E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Installation Paths
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes

; Output Configuration
OutputDir=..\build\installer
OutputBaseFilename=Reminda-Setup
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

; Modern Wizard & Compression
WizardStyle=modern
Compression=lzma2/ultra64
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.exp,*.lib"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
