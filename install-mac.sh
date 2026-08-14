#!/bin/bash
# instantTrans macOS 一键安装：Python 依赖 + PopClip 扩展
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${HOME}/.config/instanttrans"
CONFIG_FILE="${CONFIG_DIR}/config"
EXT_SRC="${SCRIPT_DIR}/popclip/instantTrans.popclipext"
EXT_DEST="${HOME}/Library/Application Support/PopClip/Extensions/instantTrans.popclipext"
WITH_LOCAL=0
API_KEY_SETUP=0

usage() {
  cat <<'EOF'
instantTrans macOS 安装脚本

用法:
  ./install-mac.sh [选项]

选项:
  --with-local       同时安装本地模型依赖（体积较大）
  --api-key-setup    交互式配置 API 密钥并写入 ~/.config/instanttrans/config
  -h, --help         显示帮助

前置条件:
  - macOS
  - Python 3.13+（在线翻译）；本地模型需 Python 3.13（3.14 暂不支持）
  - 已安装 PopClip (https://www.popclip.app/)
EOF
}

log() {
  printf '==> %s\n' "$*"
}

die() {
  printf '错误: %s\n' "$*" >&2
  exit 1
}

find_python313() {
  local candidate
  for candidate in \
    python3.13 \
    /opt/homebrew/opt/python@3.13/bin/python3.13 \
    /usr/local/opt/python@3.13/bin/python3.13; do
    if command -v "$candidate" >/dev/null 2>&1 \
      && "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info[:2] == (3, 13) else 1)'; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

resolve_python() {
  PYTHON="$(command -v python3)"
  local minor
  minor="$("$PYTHON" -c 'import sys; print(sys.version_info.minor)')"

  if [[ "$WITH_LOCAL" -eq 1 && "$minor" -ge 14 ]]; then
    local py313
    if py313="$(find_python313)"; then
      log "Python 3.14 暂不支持本地模型依赖（transformers 尚无兼容包），已切换至: ${py313}"
      PYTHON="$py313"
      return
    fi
    die "$(cat <<EOF
本地模型暂不支持 Python 3.14（transformers / torch 尚无 cp314 包）。

请安装 Python 3.13 后重试:
  brew install python@3.13
  PATH="/opt/homebrew/opt/python@3.13/bin:\$PATH" ./install-mac.sh --with-local

或省略 --with-local，仅安装在线翻译（PopClip 自动模式仍可用）。
EOF
)"
  fi

  if ! "$PYTHON" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 13) else 1)'; then
    die "需要 Python 3.13 或更高版本"
  fi
}

for arg in "$@"; do
  case "$arg" in
    --with-local) WITH_LOCAL=1 ;;
    --api-key-setup) API_KEY_SETUP=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "未知参数: $arg（使用 --help 查看用法）"
      ;;
  esac
done

[[ "$(uname -s)" == "Darwin" ]] || die "此脚本仅支持 macOS"

command -v python3 >/dev/null || die "未找到 python3，请先安装 Python 3.13+"

resolve_python
log "使用 Python: ${PYTHON}"

if [[ ! -d "/Applications/PopClip.app" ]]; then
  log "警告: 未在 /Applications 找到 PopClip.app，请确认已安装 PopClip"
fi

if [[ ! -d "$EXT_SRC" ]]; then
  die "缺少 PopClip 扩展目录: ${EXT_SRC}"
fi

log "安装在线翻译依赖..."
"$PYTHON" -m pip install --upgrade pip
"$PYTHON" -m pip install -r "${SCRIPT_DIR}/requirements.txt"

if [[ "$WITH_LOCAL" -eq 1 ]]; then
  log "安装本地模型依赖..."
  "$PYTHON" -m pip install -r "${SCRIPT_DIR}/requirements-local.txt"
fi

log "验证在线翻译环境..."
"$PYTHON" -c "import pyperclip, deep_translator, openai; print('在线环境 OK')"

mkdir -p "$CONFIG_DIR"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

write_config() {
  cat >"$CONFIG_FILE" <<EOF
# instantTrans 运行时配置（由 install-mac.sh 生成）
INSTANTTRANS_DIR="${SCRIPT_DIR}"
PYTHON="${PYTHON}"
EOF

  if [[ -n "${DEEPSEEK_API_KEY:-}" ]]; then
    printf 'DEEPSEEK_API_KEY="%s"\n' "${DEEPSEEK_API_KEY}" >>"$CONFIG_FILE"
  fi
  if [[ -n "${SILICONFLOW_API_KEY:-}" ]]; then
    printf 'SILICONFLOW_API_KEY="%s"\n' "${SILICONFLOW_API_KEY}" >>"$CONFIG_FILE"
  fi
}

if [[ "$API_KEY_SETUP" -eq 1 ]]; then
  read -r -p "DeepSeek API Key（留空跳过）: " DEEPSEEK_API_KEY || true
  read -r -p "硅基流动 API Key（留空跳过）: " SILICONFLOW_API_KEY || true
fi

write_config
chmod 600 "$CONFIG_FILE"
log "已写入配置: ${CONFIG_FILE}"

log "安装 PopClip 扩展..."
mkdir -p "$(dirname "$EXT_DEST")"
rm -rf "$EXT_DEST"
cp -R "$EXT_SRC" "$EXT_DEST"
chmod +x \
  "${EXT_DEST}/translate.sh" \
  "${EXT_DEST}/polish.sh" \
  "${EXT_DEST}/suggest-reply.sh" \
  "${EXT_DEST}/writing-common.sh"

defaults write com.pilotmoon.popclip LoadUnsignedExtensions -bool YES >/dev/null 2>&1 || true

if pgrep -xq PopClip; then
  log "重启 PopClip..."
  osascript -e 'tell application "PopClip" to quit' >/dev/null 2>&1 || true
  sleep 1
fi

open -a PopClip >/dev/null 2>&1 || true

cat <<EOF

安装完成。

使用方式:
  1. 在任意应用中选中文字
  2. 点击 PopClip 弹出的「翻译」「润色」或「建议回复」
  3. 翻译和润色会替换选中文字
  4. 建议回复会显示 3 条候选；选择后只复制到剪贴板，不会自动发送

配置:
  - 项目路径: ${SCRIPT_DIR}
  - 运行时配置: ${CONFIG_FILE}
  - PopClip 扩展: ${EXT_DEST}

在 PopClip 扩展设置中可切换翻译服务、润色风格、回复意图和写作服务。
如需配置 API 密钥，可重新运行:
  ./install-mac.sh --api-key-setup

命令行测试:
  ${PYTHON} ${SCRIPT_DIR}/translate.py --text "Hello" --stdout

EOF
