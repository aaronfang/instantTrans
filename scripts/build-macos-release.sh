#!/bin/bash
# 打包 macOS 发布包：源码 zip + PopClip 扩展 zip
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="${ROOT}/dist"
NAME="instantTrans"

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  if git -C "$ROOT" describe --tags --abbrev=0 >/dev/null 2>&1; then
    VERSION="$(git -C "$ROOT" describe --tags --abbrev=0)"
  else
    VERSION="v0.0.0"
  fi
fi

VERSION="${VERSION#v}"
STAMP="$(date +%Y%m%d)"
RELEASE_NAME="${NAME}-macos-${VERSION}"
SRC_ZIP="${DIST}/${RELEASE_NAME}.zip"
EXT_ZIP="${DIST}/${RELEASE_NAME}.popclipextz"
EXT_DIR="${ROOT}/popclip/instantTrans.popclipext"

mkdir -p "$DIST"
rm -f "$SRC_ZIP" "$EXT_ZIP"

echo "==> 打包源码: ${SRC_ZIP}"
(
  cd "$ROOT"
  git archive --format=zip --prefix="${RELEASE_NAME}/" -o "$SRC_ZIP" HEAD
)

echo "==> 打包 PopClip 扩展: ${EXT_ZIP}"
EXT_ZIP_TMP="${DIST}/${RELEASE_NAME}.popclipextz.zip"
(
  cd "$(dirname "$EXT_DIR")"
  /usr/bin/zip -r "$EXT_ZIP_TMP" "$(basename "$EXT_DIR")"
)
mv "$EXT_ZIP_TMP" "$EXT_ZIP"

cat <<EOF
macOS 发布包已生成:

  源码包:     ${SRC_ZIP}
  PopClip 扩展: ${EXT_ZIP}

在 macOS 上安装:
  1. 解压 ${RELEASE_NAME}.zip
  2. cd ${RELEASE_NAME}
  3. chmod +x install-mac.sh && ./install-mac.sh

或单独安装扩展（需已配置 ~/.config/instanttrans/config）:
  双击 ${RELEASE_NAME}.popclipextz
EOF
