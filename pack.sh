#!/usr/bin/env bash
#
# 打包：生成可分发的 npm 包。
#
# 产物：
#   ./dist/dsh-deepseek-balance/              解压即用的完整目录
#   ./dist/dsh-deepseek-balance-<ver>.tgz     发布用压缩包
#
set -euo pipefail

cd "$(dirname "$0")"
DIST="$(pwd)/dist"

VERSION="$(node -p "require('./package.json').version")"

rm -rf "$DIST"
mkdir -p "$DIST/lib"

cp package.json README.md LICENSE install.sh uninstall.sh bootstrap.sh "$DIST/"
cp lib/index.js lib/client.js "$DIST/lib/"
chmod +x "$DIST/install.sh" "$DIST/uninstall.sh" "$DIST/bootstrap.sh"

cd "$DIST"
npm pack --silent >/dev/null
TGZ="$(ls -t ./*.tgz | head -1)"
mv "$TGZ" "dsh-deepseek-balance-${VERSION}.tgz"

echo "✓ 目录: $DIST"
echo "✓ 压缩包: $DIST/dsh-deepseek-balance-${VERSION}.tgz"
echo ""
echo "包内容:"
tmp="$(mktemp -d)"
tar -xzf "$DIST/dsh-deepseek-balance-${VERSION}.tgz" -C "$tmp"
(cd "$tmp/package" && find . -type f | sort | sed 's/^/  /')
rm -rf "$tmp"
