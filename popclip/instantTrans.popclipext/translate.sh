#!/bin/zsh
set -euo pipefail

CONFIG="${HOME}/.config/instanttrans/config"

if [[ ! -f "$CONFIG" ]]; then
  echo "请先在本机运行 install-mac.sh 完成安装" >&2
  exit 2
fi

# shellcheck disable=SC1090
source "$CONFIG"

: "${INSTANTTRANS_DIR:?配置缺少 INSTANTTRANS_DIR}"
: "${PYTHON:?配置缺少 PYTHON}"

TRANSLATE="${INSTANTTRANS_DIR}/translate.py"
if [[ ! -f "$TRANSLATE" ]]; then
  echo "找不到 translate.py: ${TRANSLATE}" >&2
  exit 2
fi

if [[ -n "${DEEPSEEK_API_KEY:-}" ]]; then
  export DEEPSEEK_API_KEY
fi
if [[ -n "${SILICONFLOW_API_KEY:-}" ]]; then
  export SILICONFLOW_API_KEY
fi

SERVICE="${POPCLIP_OPTION_SERVICE:-auto}"
case "$SERVICE" in
  auto)        ARGS=() ;;
  deepseek)    ARGS=(--deepseek) ;;
  siliconflow) ARGS=(--siliconflow) ;;
  google)      ARGS=(--google) ;;
  local)       ARGS=(--local) ;;
  *)
    echo "未知翻译服务: ${SERVICE}" >&2
    exit 1
    ;;
esac

exec "$PYTHON" "$TRANSLATE" --text "$POPCLIP_TEXT" --stdout "${ARGS[@]}"
