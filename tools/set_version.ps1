# SimpleClock 一键版本号更新
#
# 用法：powershell -ExecutionPolicy Bypass -File tools\set_version.ps1 0.0.10
#
# 只更新"应用版本号"5 处：
#   pubspec.yaml / lib/services/update_config.dart /
#   packaging/windows/simple_clock.iss /
#   packaging/macos/build_dmg.sh / packaging/linux/build_appimage.sh
#
# 不碰 latest.json：它由 release 工作流的 update-latest-json job 在
# 三平台产物就绪后自动更新，手动改会造成"用户先收到提示、安装包未就绪"。
param(
  [Parameter(Mandatory = $true)]
  [string]$NewVersion
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# 校验版本号格式 X.Y.Z
if ($NewVersion -notmatch '^\d+\.\d+\.\d+$') {
  Write-Error "版本号格式应为 X.Y.Z，例如 0.0.10"
  exit 1
}

function Update-File {
  param(
    [string]$Path,
    [string]$Pattern,
    [string]$Replacement
  )
  $bytes = [IO.File]::ReadAllBytes($Path)
  $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and
    $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
  $payload = if ($hasBom) { $bytes[3..($bytes.Length - 1)] } else { $bytes }
  $text = [Text.Encoding]::UTF8.GetString($payload)
  $options = [Text.RegularExpressions.RegexOptions]::Multiline
  if (-not [regex]::IsMatch($text, $Pattern, $options)) {
    Write-Host "  [!] 未匹配到模式: $Path" -ForegroundColor Yellow
    return
  }
  $new = [regex]::Replace($text, $Pattern, $Replacement, $options)
  $enc = New-Object Text.UTF8Encoding ($hasBom)
  [IO.File]::WriteAllText($Path, $new, $enc)
  Write-Host "  [OK] $Path" -ForegroundColor Green
}

Write-Host "设置应用版本号为 $NewVersion ..."

Update-File (Join-Path $root 'pubspec.yaml') `
  '^version: .+$' "version: $NewVersion+1"
Update-File (Join-Path $root 'lib\services\update_config.dart') `
  "currentVersion = '[^']*'" "currentVersion = '$NewVersion'"
Update-File (Join-Path $root 'packaging\windows\simple_clock.iss') `
  '#define MyAppVersion "[^"]*"' "#define MyAppVersion `"$NewVersion`""
Update-File (Join-Path $root 'packaging\macos\build_dmg.sh') `
  '^VERSION="[^"]*"' "VERSION=`"$NewVersion`""
Update-File (Join-Path $root 'packaging\linux\build_appimage.sh') `
  '^VERSION="[^"]*"' "VERSION=`"$NewVersion`""

Write-Host "完成。latest.json 保持不动（由 release 工作流自动更新）。"
