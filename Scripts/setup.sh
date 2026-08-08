#!/usr/bin/env bash
# 千手 — 一键安装：检测环境 → 构建 App → 启动 WDA → 使用说明
# 目标：从零到「模拟器自己动」< 5 分钟
set -euo pipefail

cd "$(dirname "$0")/.."
echo "──────────────────────────────────────────"
echo "  千手 Qianshou — 一键安装"
echo "  AI driving for the iOS Simulator"
echo "──────────────────────────────────────────"

# 1) 环境检测
echo ""
echo "▸ 检测环境"
command -v xcodebuild >/dev/null 2>&1 || { echo "✗ 未安装 Xcode（需 Xcode 15+）" >&2; exit 1; }
echo "  ✓ Xcode: $(xcodebuild -version 2>/dev/null | head -1)"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "  · 安装 xcodegen ..."
  brew install xcodegen
fi
echo "  ✓ xcodegen: $(xcodegen --version)"

# 2) 构建
echo ""
echo "▸ 生成工程并构建"
xcodegen generate
xcodebuild -project Qianshou.xcodeproj -scheme Qianshou -configuration Debug -destination 'platform=macOS' build -quiet
APP_PATH="$(xcodebuild -project Qianshou.xcodeproj -scheme Qianshou -configuration Debug -destination 'platform=macOS' -showBuildSettings 2>/dev/null \
  | grep -m1 ' TARGET_BUILD_DIR' | awk '{print $3}')/Qianshou.app"
echo "  ✓ 构建完成: ${APP_PATH}"

# 3) 模拟器
BOOTED=$(xcrun simctl list devices | grep Booted | head -1 || true)
if [[ -z "${BOOTED}" ]]; then
  echo ""
  echo "▸ 启动模拟器（首次请打开 Simulator 选择设备）"
  UDID=$(xcrun simctl list devices available | grep -oE '[0-9A-F-]{36}' | head -1)
  [[ -n "${UDID}" ]] && xcrun simctl boot "${UDID}" 2>/dev/null || true
  open -a Simulator
  echo "  · 等待模拟器就绪 ..."
  for i in $(seq 1 30); do
    xcrun simctl list devices | grep -q Booted && break
    sleep 2
  done
fi
echo "  ✓ 模拟器: $(xcrun simctl list devices | grep Booted | head -1 | sed 's/([^)]*)//g' | xargs)"

# 4) WDA 触摸注入
echo ""
echo "▸ 启动触摸注入服务（首次构建约 2-3 分钟，之后秒级）"
./Scripts/start_wda.sh

# 5) 启动 App
echo ""
echo "▸ 启动千手"
open "${APP_PATH}"

echo ""
echo "──────────────────────────────────────────"
echo "  ✅ 安装完成"
echo "  下一步：首次使用需授权「屏幕录制」（镜像画面）"
echo "  然后：工具栏选设备 → 镜像出画面 → 点画布加点位 → 开始连点"
echo "  AI 驾驶：⚙ 面板填入 Anthropic API Key 即可用一句话驱动模拟器"
echo "──────────────────────────────────────────"
