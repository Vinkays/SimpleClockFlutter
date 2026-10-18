# SimpleClock Flutter run 启动脚本
# 直接双击 run_windows.bat 运行（.ps1 无法双击直接执行，属 Windows 安全默认）；
# 若插件符号链接构建失败，请右键 run_windows.bat → "以管理员身份运行"。
# 项目路径为相对路径（脚本自身位置），任意目录克隆后均可直接运行；
# Flutter SDK 依次从 FLUTTER_ROOT 环境变量、PATH、常见安装位置定位。

# 国内网络镜像配置
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'

# 项目根目录 = 本脚本所在目录
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ProjectRoot

# 定位 flutter.bat
$FlutterBat = $null
if ($env:FLUTTER_ROOT) {
  $candidate = Join-Path $env:FLUTTER_ROOT 'bin\flutter.bat'
  if (Test-Path $candidate) { $FlutterBat = $candidate }
}
if (-not $FlutterBat) {
  $cmd = Get-Command flutter.bat -ErrorAction SilentlyContinue
  if ($cmd) { $FlutterBat = $cmd.Source }
}
if (-not $FlutterBat) {
  foreach ($root in @('d:\tools\flutter', 'C:\src\flutter', 'C:\flutter')) {
    $candidate = Join-Path $root 'bin\flutter.bat'
    if (Test-Path $candidate) { $FlutterBat = $candidate; break }
  }
}
if (-not $FlutterBat) {
  Write-Host '未找到 flutter.bat：请设置 FLUTTER_ROOT 环境变量，或把 Flutter 加入 PATH。' -ForegroundColor Red
  Read-Host '按回车关闭'
  exit 1
}

Write-Host "使用 Flutter: $FlutterBat"
& $FlutterBat run -d windows
if ($LASTEXITCODE -ne 0) {
  Write-Host "flutter 异常退出（退出码 $LASTEXITCODE），按回车关闭窗口查看上述错误。" -ForegroundColor Yellow
  Read-Host
}
