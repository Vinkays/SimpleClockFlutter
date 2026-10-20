#!/bin/bash
# SimpleClock - Linux AppImage 打包脚本
#
# ⚠️ 必须在 Linux 上执行（需 Flutter Linux 工具链），Windows 上无法运行。
# ⚠️ 未经真实 Linux 环境验证，首次使用前请核对路径与产物名称。
#
# 用法：
#   1. 在项目根目录执行：bash packaging/linux/build_appimage.sh
#   2. 产物：dist/SimpleClock-<版本>.AppImage
#
# AppImage 格式配合自建更新器 / AppImageUpdate 可实现自动更新。
set -e

VERSION="0.0.7"
APP_NAME="SimpleClock"
EXE_NAME="simple_clock"
BUNDLE_DIR="build/linux/x64/release/bundle"
APPDIR="dist/SimpleClock.AppDir"
DIST_DIR="dist"
OUTPUT="${DIST_DIR}/${APP_NAME}-${VERSION}.AppImage"

echo "==> flutter build linux --release"
flutter build linux --release

if [ ! -d "$BUNDLE_DIR" ]; then
  echo "错误：未找到 ${BUNDLE_DIR}，请检查构建输出路径" >&2
  exit 1
fi

mkdir -p "$APPDIR/usr/bin"

echo "==> 复制程序文件到 AppDir"
cp -R "$BUNDLE_DIR/"* "$APPDIR/usr/bin/"

echo "==> 写入 AppRun 启动器"
cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
SELF="$(dirname "$(readlink -f "$0")")"
export APPDIR="$SELF"
export PATH="$SELF/usr/bin:$PATH"
export LD_LIBRARY_PATH="$SELF/usr/bin/lib:$LD_LIBRARY_PATH"
exec "$SELF/usr/bin/simple_clock" "$@"
EOF
chmod +x "$APPDIR/AppRun"

echo "==> 写入 .desktop 与图标"
mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"
# 图标：优先仓库通用图标 assets/app_icon.png（Windows/macOS 共用），
# 其次 Linux runner 模板图标；AppDir 根目录也放一份（appimagetool 双保险查找）
ICON_SRC="assets/app_icon.png"
if [ ! -f "$ICON_SRC" ]; then
  ICON_SRC="linux/runner/resources/app_icon.png"
fi
if [ -f "$ICON_SRC" ]; then
  cp "$ICON_SRC" "$APPDIR/usr/share/icons/hicolor/256x256/apps/simple_clock.png"
  cp "$ICON_SRC" "$APPDIR/simple_clock.png"
  echo "==> 图标已复制: $ICON_SRC"
else
  echo "警告：未找到图标，将使用不含图标的桌面项" >&2
fi

cat > "$APPDIR/${APP_NAME}.desktop" <<EOF
[Desktop Entry]
Name=简易时钟
Comment=Simple desktop clock
Exec=${EXE_NAME}
Icon=${EXE_NAME}
Terminal=false
Type=Application
Categories=Utility;
StartupNotify=false
EOF
mkdir -p "$APPDIR/usr/share/applications"
cp "$APPDIR/${APP_NAME}.desktop" "$APPDIR/usr/share/applications/"

echo "==> 下载 appimagetool"
APPIMAGE_TOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
TOOL="$DIST_DIR/appimagetool"
if [ ! -f "$TOOL" ]; then
  curl -L -o "$TOOL" "$APPIMAGE_TOOL_URL"
  chmod +x "$TOOL"
fi

echo "==> 打包 AppImage"
# APPIMAGE_EXTRACT_AND_RUN=1：解压运行，避免 CI 环境（无 FUSE）无法执行 AppImage
export APPIMAGE_EXTRACT_AND_RUN=1
ARCH=x86_64 "$TOOL" "$APPDIR" "$OUTPUT"
rm -rf "$APPDIR"

echo "✅ 完成：${OUTPUT}"
echo "下一步：上传 ${OUTPUT} 到 GitHub Releases（tag 形如 v${VERSION}）"
