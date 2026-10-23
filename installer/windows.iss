#ifndef AppVersion
#define AppVersion "1.12.0"
#endif

[Setup]
AppId={{D2A1477F-02D1-48F9-A3E4-9E06A6F04D11}
AppName=Media Archive
AppVersion={#AppVersion}
AppPublisher=Luke133
DefaultDirName={localappdata}\Programs\Media Archive
DefaultGroupName=Media Archive
UninstallDisplayIcon={app}\media_archive.exe
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64
OutputDir=..\build\release
OutputBaseFilename=media-archive-windows-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=yes

[Tasks]
Name: "desktopicon"; Description: "Crea un collegamento sul desktop"; GroupDescription: "Collegamenti aggiuntivi:"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Media Archive"; Filename: "{app}\media_archive.exe"
Name: "{autodesktop}\Media Archive"; Filename: "{app}\media_archive.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\media_archive.exe"; Description: "Avvia Media Archive"; Flags: postinstall nowait skipifsilent
