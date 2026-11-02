#!/usr/bin/env bash
#
# dsh-deepseek-balance 云端安装引导脚本
#
# 用法（推荐）：
#   curl -fsSL https://raw.githubusercontent.com/Mistakeman56/dsh-deepseek-balance/main/bootstrap.sh \
#     | bash -s -- --profile web
#
# 额外选项：
#   --ref <branch-or-tag>   指定分支/标签（默认 main，需放在最前）
#   其余参数原样传给 install.sh（--profile / --home）
#
# 说明：逐文件拉取而非下载整包归档，因为 github.com 的 archive/release
# 下载在国内常见网络下不可用，而 raw / jsDelivr 通常可达。多个镜像依次回退。
#
set -euo pipefail

REPO="${DSH_BALANCE_REPO:-Mistakeman56/dsh-deepseek-balance}"
REF="${DSH_BALANCE_REF:-main}"

usage() {
  cat <<'EOF'
用法:
  curl -fsSL <bootstrap.sh> | bash -s -- [--profile web] [--home ~/.dsh] [--ref v0.1.0]

选项:
  --ref <branch-or-tag>   指定分支/标签，需放在所有参数最前面（默认 main）
  --profile <name>        传给 install.sh：装到哪个 profile（默认 web）
  --home <path>           传给 install.sh：DSH home 目录
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --ref)     [ $# -ge 2 ] || { echo "错误: --ref 缺少参数" >&2; exit 1; }
               REF="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)         break ;;
  esac
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# 只需要这些核心文件就能装起来
CORE_FILES="package.json lib/index.js lib/client.js install.sh"
EXTRA_FILES="uninstall.sh README.md"

MIRRORS="
https://raw.githubusercontent.com/${REPO}/${REF}
https://cdn.jsdelivr.net/gh/${REPO}@${REF}
https://github.com/${REPO}/raw/${REF}
"

fetch_from() {
  local base="$1" dir="$2" f
  mkdir -p "$dir/lib" || return 1
  for f in $CORE_FILES; do
    curl -fsSL --retry 1 --connect-timeout 10 --max-time 60 "$base/$f" -o "$dir/$f" 2>/dev/null || return 1
  done
  for f in $EXTRA_FILES; do
    curl -fsSL --connect-timeout 10 --max-time 60 "$base/$f" -o "$dir/$f" 2>/dev/null || true
  done
  # 防止把 HTML 错误页当成源码存下来
  grep -q "__ModuleLoader__" "$dir/lib/client.js" 2>/dev/null || return 1
  grep -q "export function apply" "$dir/lib/index.js" 2>/dev/null || return 1
  chmod +x "$dir/install.sh"
  return 0
}

ok=0
for base in $MIRRORS; do
  [ -n "$base" ] || continue
  host="${base#*://}"; host="${host%%/*}"
  echo "→ 尝试镜像 ${host}"
  if fetch_from "$base" "$tmp/pkg"; then
    ok=1
    echo "✓ 已从 ${host} 取到安装文件"
    break
  fi
  rm -rf "$tmp/pkg"
done

if [ "$ok" -ne 1 ]; then
  cat >&2 <<EOF
错误: 所有镜像都下载失败。

已尝试：
$(echo "$MIRRORS" | sed '/^$/d;s/^/  - /')

可处理方式：
  1. 给终端设置代理后重试，例如
       export https_proxy=http://127.0.0.1:7890
  2. 或从 Release 页面手动下载离线包，解压后执行 ./install.sh
     https://github.com/${REPO}/releases
EOF
  exit 1
fi

echo "→ 执行安装"
"$tmp/pkg/install.sh" "$@"
