[Setup]
AppName=Lore Ex
AppVersion=8.4.3
DefaultDirName={autopf}\Lore Ex
DefaultGroupName=Lore Ex
OutputDir=installer-output
OutputBaseFilename=LoreEx-Setup
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=lowest
DisableProgramGroupPage=yes
UninstallDisplayName=Lore Ex
SetupIconFile=windows\runner\resources\app_icon.ico

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Lore Ex"; Filename: "{app}\lore_ex.exe"
Name: "{commondesktop}\Lore Ex"; Filename: "{app}\lore_ex.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\lore_ex.exe"; Description: "Launch Lore Ex"; Flags: nowait postinstall skipifsilent
