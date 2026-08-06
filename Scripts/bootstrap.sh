#!/usr/bin/env bash
# 千手 — 环境引导：创建 Python venv 并安装 pymobiledevice3
# 用法: ./Scripts/bootstrap.sh
set -euo pipefail

APP_SUPPORT="${HOME}/Library/Application Support/QianShou"
VENV_DIR="${APP_SUPPORT}/venv"
PYTHON_BIN=""

# 1) 定位 python3：优先 Homebrew 3.12+，回退系统 python3 (>=3.9)
for cand in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.13 /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
  if command -v "${cand}" >/dev/null 2>&1; then
    ver=$("${cand}" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    if [[ "$ver" =~ ^3\.(9|1[0-9]) ]]; then
      PYTHON_BIN="${cand}"
      echo "[bootstrap] 使用 Python ${ver}: ${cand}"
      break
    fi
  fi
done

if [[ -z "${PYTHON_BIN}" ]]; then
  echo "[bootstrap] 错误: 未找到 Python 3.9+。请先执行: brew install python@3.12" >&2
  exit 1
fi

# 2) 创建 venv（已存在则跳过创建）
mkdir -p "${APP_SUPPORT}"
if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
  echo "[bootstrap] 创建 venv: ${VENV_DIR}"
  "${PYTHON_BIN}" -m venv "${VENV_DIR}"
fi

# 3) 安装/升级 pymobiledevice3
echo "[bootstrap] 安装/升级 pymobiledevice3 ..."
"${VENV_DIR}/bin/python" -m pip install --upgrade pip >/dev/null
"${VENV_DIR}/bin/python" -m pip install -U pymobiledevice3

# 4) 冒烟测试
echo "[bootstrap] 冒烟测试:"
"${VENV_DIR}/bin/python" -m pymobiledevice3 version || "${VENV_DIR}/bin/pymobiledevice3" version

echo "[bootstrap] 完成 ✓  venv: ${VENV_DIR}"
