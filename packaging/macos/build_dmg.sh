#!/bin/bash
# SimpleClock - macOS DMG 打包脚本
#
# ⚠️ 必须在 macOS 上执行（需 Xcode + Command Line Tools），Windows 上无法运行。
# ⚠️ 未经真实 macOS 环境验证，首次使用前请核对路径与产物名称。
#
# 用法：
#   1. 在项目根目录执行：bash packaging/macos/build_dmg.sh
#   2. 产物：dist/SimpleClock-<版本>.dmg
#
# 正式分发前必须完成（否则用户无法打开，自动更新会被 Gatekeeper 拦截）：
#   - 开发者证书签名：codesign --deep --force --options runtime \
#       --sign "Developer ID Application: 你的名字" build/macos/Build/Products/Release/SimpleClock.app
#   - 公证：xcrun notarytool submit dist/SimpleClock-<版本>.dmg --keychain-profile "你的profile" --wait
#   - 公证后打回（staple）：xcrun stapler staple dist/SimpleClock-<版本>.dmg
#
# 版本号与 pubspec.yaml / update_config.dart / simple_clock.iss 保持一致。
set -e

VERSION="0.0.12"
APP_NAME="SimpleClock"
APP_PATH="build/macos/Build/Products/Release/${APP_NAME}.app"
DIST_DIR="dist"
DMG_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.dmg"

echo "==> flutter build macos --release"
flutter build macos --release

if [ ! -d "$APP_PATH" ]; then
  echo "错误：未找到 ${APP_PATH}，请检查构建输出路径" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"

echo "==> 创建 DMG: ${DMG_PATH}"
# 先制作一个含 /Applications 软链接的暂存目录，实现"拖入 Applications"引导
STAGING="${DIST_DIR}/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING" \
  -ov -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGING"
echo "✅ 完成：${DMG_PATH}"
echo ""
echo "下一步（正式分发前必须做）："
echo "  1. codesign 签名（Developer ID Application 证书）"
echo "  2. notarytool 公证 + stapler 打回"
echo "  3. 上传 ${DMG_PATH} 到 GitHub Releases"
