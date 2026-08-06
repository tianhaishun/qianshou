#!/usr/bin/env bash
# 构建 Release 安装包（ad-hoc 签名 + zip）
#
# 注意：当前无 Developer ID 证书（免费账号），使用 ad-hoc 签名。
# 用户在首次打开时需要：右键 → 打开，或系统设置 → 隐私与安全性 → 仍要打开。
# 未来有付费证书后，把 CODE_SIGN_IDENTITY 换成证书名并加公证步骤即可。
#
# 用法: ./Scripts/build_release.sh [版本号，如 0.1.0]
set -euo pipefail

VERSION="${1:-0.1.0}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${PROJECT_DIR}"

echo "[release] 生成工程 ..."
xcodegen generate

echo "[release] Release 构建（ad-hoc 签名）..."
xcodebuild -project Qianshou.xcodeproj -scheme Qianshou \
  -configuration Release -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO \
  build

APP_PATH="$(xcodebuild -project Qianshou.xcodeproj -scheme Qianshou -configuration Release \
  -destination 'platform=macOS' -showBuildSettings 2>/dev/null \
  | grep -m1 ' TARGET_BUILD_DIR' | awk '{print $3}')/Qianshou.app"

[[ -d "${APP_PATH}" ]] || { echo "错误: App 产物不存在" >&2; exit 1; }

ZIP_PATH="dist/Qianshou-${VERSION}-macOS.zip"
mkdir -p dist
ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"
echo "[release] 完成 ✓ ${ZIP_PATH}"
echo "[release] 发布: gh release create v${VERSION} ${ZIP_PATH} --title 'Qianshou v${VERSION}' --notes '...'"
