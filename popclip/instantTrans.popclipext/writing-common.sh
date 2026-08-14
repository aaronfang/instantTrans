#!/bin/zsh
set -euo pipefail

load_instanttrans_config() {
  local config="${HOME}/.config/instanttrans/config"

  if [[ ! -f "$config" ]]; then
    echo "请先在本机运行 install-mac.sh 完成安装" >&2
    exit 2
  fi

  # shellcheck disable=SC1090
  source "$config"

  : "${INSTANTTRANS_DIR:?配置缺少 INSTANTTRANS_DIR}"
  : "${PYTHON:?配置缺少 PYTHON}"

  if [[ ! -f "${INSTANTTRANS_DIR}/assistant_engine.py" ]]; then
    echo "找不到 assistant_engine.py: ${INSTANTTRANS_DIR}/assistant_engine.py" >&2
    exit 2
  fi

  if [[ -n "${DEEPSEEK_API_KEY:-}" ]]; then
    export DEEPSEEK_API_KEY
  fi
  if [[ -n "${SILICONFLOW_API_KEY:-}" ]]; then
    export SILICONFLOW_API_KEY
  fi

  export INSTANTTRANS_DIR
  export PYTHON
}

run_writing_action() {
  local operation="$1"
  local script_dir
  script_dir="$(cd "$(dirname "$0")" && pwd)"

  load_instanttrans_config
  exec "$PYTHON" "${script_dir}/popclip_runner.py" "$operation"
}
