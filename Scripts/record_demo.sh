#!/usr/bin/env bash
# 录制演示 GIF：在正常桌面会话中运行
#
# 步骤：
#   1) 启动千手 App + 模拟器，完成镜像连接
#   2) 运行本脚本（默认录 25 秒全屏）
#   3) 录屏期间操作 App：添加点位 → 开始连点 → 切录制模式录一段 → 回放
#   4) 完成后 docs/demo.gif 生成
#
# 用法: ./Scripts/record_demo.sh [时长秒=25] [屏幕index=1] [输出路径=docs/demo.gif]
set -euo pipefail

DURATION="${1:-25}"
SCREEN_INDEX="${2:-1}"
OUT="${3:-docs/demo.gif}"
TMPDIR="$(mktemp -d)"
TMP_MP4="${TMPDIR}/demo.mp4"

mkdir -p "$(dirname "${OUT}")"

echo "[record_demo] 录制 ${DURATION}s 屏幕 ${SCREEN_INDEX} ...（操作你的 App！）"
ffmpeg -y -f avfoundation -framerate 30 -i "${SCREEN_INDEX}:none" \
  -t "${DURATION}" -pix_fmt yuv420p "${TMP_MP4}" -loglevel error

echo "[record_demo] 转换 GIF ..."
ffmpeg -y -i "${TMP_MP4}" -vf \
  "fps=15,scale=720:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
  "${OUT}" -loglevel error

rm -rf "${TMPDIR}"
echo "[record_demo] 完成 ✓ ${OUT} ($(du -h "${OUT}" | cut -f1))"
