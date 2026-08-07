#!/usr/bin/env bash
# 启动 WDA（XCTest 触摸注入服务）到模拟器 —— 触摸注入不涉及 macOS 鼠标
#
# 用法: ./Scripts/start_wda.sh [模拟器UDID]
# 首次运行会构建（约 2-3 分钟），之后秒级启动
set -euo pipefail

UDID="${1:-$(xcrun simctl list devices | grep Booted | head -1 | grep -o '[0-9A-F-]\{36\}')}"
[[ -n "${UDID}" ]] || { echo "错误: 未找到已启动的模拟器，请先启动模拟器" >&2; exit 1; }

REPO="$(cd "$(dirname "$0")/../vendor/WebDriverAgent" && pwd)"
DERIVED="${HOME}/Library/Application Support/QianShou/WDA-Sim-Build"
APP_PATH="${DERIVED}/Build/Products/Debug-iphonesimulator/WebDriverAgentRunner-Runner.app"

# WDA 已在运行则直接退出
if curl -s --max-time 1 http://localhost:8100/status >/dev/null 2>&1; then
  echo "[wda] 已在运行 (localhost:8100)"
  exit 0
fi

# 首次构建
if [[ ! -d "${APP_PATH}" ]]; then
  echo "[wda] 首次构建（模拟器目标，无需签名）..."
  xcodebuild build-for-testing \
    -project "${REPO}/WebDriverAgent.xcodeproj" \
    -scheme WebDriverAgentRunner \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=${UDID}" \
    -derivedDataPath "${DERIVED}" \
    CODE_SIGNING_ALLOWED=NO
fi

# 安装到模拟器
echo "[wda] 安装 runner ..."
xcrun simctl install "${UDID}" "${APP_PATH}"

# 启动（test-without-building 常驻；WDA 监听 0.0.0.0:8100）
echo "[wda] 启动 runner ..."
nohup xcodebuild test-without-building \
  -project "${REPO}/WebDriverAgent.xcodeproj" \
  -scheme WebDriverAgentRunner \
  -destination "platform=iOS Simulator,id=${UDID}" \
  -derivedDataPath "${DERIVED}" \
  > /tmp/wda_runner.log 2>&1 &

# 等待就绪
for i in $(seq 1 30); do
  if curl -s --max-time 1 http://localhost:8100/status >/dev/null 2>&1; then
    echo "[wda] 就绪 ✓ http://localhost:8100（触摸注入可用，不涉及鼠标）"
    exit 0
  fi
  sleep 2
done
echo "[wda] 启动超时，日志: /tmp/wda_runner.log" >&2
exit 1
