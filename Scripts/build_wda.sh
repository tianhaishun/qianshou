#!/usr/bin/env bash
# 千手 — 构建并安装 WebDriverAgent 到设备
# 用法: ./Scripts/build_wda.sh <设备UDID> <DEVELOPMENT_TEAM> [--skip-bootstrap]
# 产物: ~/Library/Application Support/QianShou/WDA-Build/<udid>/Build/Products/Debug-iphoneos/
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "用法: $0 <设备UDID> <DEVELOPMENT_TEAM>" >&2
  exit 1
fi

UDID="$1"
TEAM="$2"
REPO="$(cd "$(dirname "$0")/../vendor/WebDriverAgent" && pwd)"
APP_SUPPORT="${HOME}/Library/Application Support/QianShou"
DERIVED="${APP_SUPPORT}/WDA-Build/${UDID}"
PMD="${APP_SUPPORT}/venv/bin/pymobiledevice3"
APP_PATH="${DERIVED}/Build/Products/Debug-iphoneos/WebDriverAgentRunner-Runner.app"

# 0) 前置检查
xcode-select -p >/dev/null || { echo "错误: 未找到 Xcode" >&2; exit 1; }
[[ -d "${REPO}/WebDriverAgent.xcodeproj" ]] || { echo "错误: ${REPO} 不是 WDA 仓库" >&2; exit 1; }
[[ -x "${PMD}" ]] || { echo "错误: 请先运行 ./Scripts/bootstrap.sh" >&2; exit 1; }

# 1) WDA 依赖（npm/carthage，仅首次需要）
if [[ "${3:-}" != "--skip-bootstrap" ]] && [[ ! -d "${REPO}/node_modules" ]]; then
  echo "[build_wda] 安装 WDA 依赖 (Scripts/bootstrap.sh)..."
  (cd "${REPO}" && ./Scripts/bootstrap.sh)
fi

# 2) build-for-testing（预装路线：不走 xcodebuild test，规避 Xcode 26 兼容坑）
echo "[build_wda] 构建 WebDriverAgentRunner (build-for-testing) ..."
mkdir -p "${DERIVED}"
xcodebuild build-for-testing \
  -project "${REPO}/WebDriverAgent.xcodeproj" \
  -scheme WebDriverAgentRunner \
  -configuration Debug \
  -destination "id=${UDID}" \
  -derivedDataPath "${DERIVED}" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="${TEAM}"

[[ -d "${APP_PATH}" ]] || { echo "错误: 构建产物不存在: ${APP_PATH}" >&2; exit 1; }

# 3) 安装到设备
echo "[build_wda] 安装到设备 ${UDID} ..."
"${PMD}" apps install "${APP_PATH}"

echo "[build_wda] 完成 ✓"
echo "  构建产物: ${APP_PATH}"
echo "  下一步: pymobiledevice3 developer wda launch com.apple.Preferences --xctrunner com.facebook.WebDriverAgentRunner.xctrunner"
