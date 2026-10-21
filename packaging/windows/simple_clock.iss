; SimpleClock - Windows 安装脚本（Inno Setup 6）
; 使用前：
;   1. 安装 Inno Setup 6（https://jrsoftware.org/isinfo.php）
;   2. 在项目根目录执行 flutter build windows --release
;   3. 用 Inno Setup 编译本脚本（或命令行 iscc simple_clock.iss）
; 输出：dist\SimpleClock-setup-<版本>.exe（静默参数 /VERYSILENT 供自动更新使用）
; 注：中文语言文件 ChineseSimplified.isl 随仓库附带（Languages/ 子目录），
;     Inno Setup 默认安装不包含该文件。

#define MyAppName "简易时钟"
; 发布新版本时同步更新此版本号（与 pubspec.yaml、update_config.dart 三处一致）
#define MyAppVersion "0.0.10"
#define MyAppPublisher "Vinkay"
#define MyAppExeName "simple_clock.exe"

[Setup]
; 固定 AppId：升级安装时用于识别同一应用，勿改
AppId={{38B34C4C-CFF9-4CA6-AEC6-7B4EA06660A7}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\SimpleClock
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
; 桌面图标默认不勾选（与旧版一致，尊重用户上次的选择）；
; 升级时若检测到旧版英文快捷方式仍在（说明用户上次勾选过），
; 由 [Icons] 的 Check: DesktopIconWanted 自动创建中文快捷方式
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Flutter release 输出目录：exe + DLL + data 全部打进安装包
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; Check: DesktopIconWanted

[Run]
; 自动更新走静默安装（/VERYSILENT），安装完成后自动启动新版（不带 skipifsilent，
; 否则静默模式下会跳过启动；runascurrentuser 避免新版继承安装器的管理员权限）
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall runascurrentuser

[InstallDelete]
; 升级时清理 0.0.6 及更早版本（MyAppName=SimpleClock）创建的英文快捷方式与
; 开始菜单组，新版统一为「简易时钟」（桌面/公共开始菜单/用户开始菜单全覆盖，
; 目录在快捷方式删除后若为空则一并移除）
Type: files; Name: "{autodesktop}\SimpleClock.lnk"
Type: files; Name: "{commonprograms}\SimpleClock.lnk"
Type: files; Name: "{userprograms}\SimpleClock.lnk"
Type: files; Name: "{commonprograms}\SimpleClock\Uninstall SimpleClock.lnk"
Type: files; Name: "{userprograms}\SimpleClock\Uninstall SimpleClock.lnk"
Type: dirifempty; Name: "{commonprograms}\SimpleClock"
Type: dirifempty; Name: "{userprograms}\SimpleClock"

[UninstallDelete]
Type: filesandordirs; Name: "{app}\data"

[UninstallRun]
; 应用关闭窗口时隐藏到系统托盘（进程不退出），Inno 的 CloseApplications
; 发 WM_CLOSE 无法结束它 → 卸载前必须强制结束进程，否则核心文件被占用
; 删除失败，残留 simple_clock.exe / DLL 且桌面窗口不消失
Filename: "{sys}\taskkill.exe"; Parameters: "/IM {#MyAppExeName} /F"; Flags: runhidden; RunOnceId: "KillAppBeforeUninstall"

[Code]
// 桌面快捷方式创建条件：
//  - 升级场景：桌面已存在旧版快捷方式（英文 SimpleClock 或中文 简易时钟），
//    说明用户上次勾选过桌面图标 → 创建/刷新中文快捷方式（旧英文由
//    [InstallDelete] 清理；中文同名刷新指向当前版本，路径不变无感）
//  - 其他场景：跟随 desktopicon 任务的勾选状态
//    （全新安装默认不勾选，与旧版行为一致，不强行给用户加图标）
function DesktopIconWanted: Boolean;
begin
  Result := FileExists(ExpandConstant('{autodesktop}\SimpleClock.lnk'))
         or FileExists(ExpandConstant('{autodesktop}\{#MyAppName}.lnk'));
  if not Result then
    Result := WizardIsTaskSelected('desktopicon');
end;
