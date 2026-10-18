# SimpleClock Flutter run 启动脚本（管理员运行，绕过符号链接权限限制）
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
Set-Location 'D:\work\projects\simpleClock-flutter'
& 'd:\tools\flutter\bin\flutter.bat' run -d windows *> "$env:TEMP\flutter_run_user.txt"
