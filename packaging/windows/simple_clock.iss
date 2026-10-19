; SimpleClock - Windows 安装脚本（Inno Setup 6）
; 使用前：
;   1. 安装 Inno Setup 6（https://jrsoftware.org/isinfo.php）
;   2. 在项目根目录执行 flutter build windows --release
;   3. 用 Inno Setup 编译本脚本（或命令行 iscc simple_clock.iss）
; 输出：dist\SimpleClock-setup-<版本>.exe（静默参数 /VERYSILENT 供自动更新使用）
; 注：中文语言文件 ChineseSimplified.isl 随仓库附带（Languages/ 子目录），
;     Inno Setup 默认安装不包含该文件。

#define MyAppName "SimpleClock"
; 发布新版本时同步更新此版本号（与 pubspec.yaml、update_config.dart 三处一致）
#define MyAppVersion "0.0.6"
#define MyAppPublisher "Vinkay"
#define MyAppExeName "simple_clock.exe"

[Setup]
; 固定 AppId：升级安装时用于识别同一应用，勿改
AppId={{38B34C4C-CFF9-4CA6-AEC6-7B4EA06660A7}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
; 32/64 位通用安装目录（Program Files）
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
OutputDir=..\..\dist
OutputBaseFilename=SimpleClock-setup-{#MyAppVersion}
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; 静默安装/卸载支持（自动更新器使用）
PrivilegesRequiredOverridesAllowed=dialog
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "{#SourcePath}Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Flutter release 输出目录：exe + DLL + data 全部打进安装包
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; 自动更新走静默安装（/VERYSILENT），安装完成后自动启动新版（不带 skipifsilent，
; 否则静默模式下会跳过启动；runascurrentuser 避免新版继承安装器的管理员权限）
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall runascurrentuser

[UninstallDelete]
Type: filesandordirs; Name: "{app}\data"
