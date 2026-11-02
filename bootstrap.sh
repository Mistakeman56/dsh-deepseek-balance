#!/usr/bin/env bash
#
# dsh-deepseek-balance 云端安装引导脚本
#
# 用法（推荐）：
#   curl -fsSL https://raw.githubusercontent.com/Mistakeman56/dsh-deepseek-balance/main/bootstrap.sh \
#     | bash -s -- --profile web
#
# 它会下载本仓库，然后调用其中的 install.sh。
# 额外选项：
#   --ref <branch-or-tag>   指定分支/标签（默认 main，需放在最前）
#   其余参数原样传给 install.sh（--profile / --home）
#
set -euo pipefail

REPO="${DSH_BALANCE_REPO:-Mistakeman56/dsh-deepseek-balance}"
REF="${DSH_BALANCE_REF:-main}"

while [ $# -gt 0 ]; do
  case "$1" in
    --ref)     [ $# -ge 2 ] || { echo "错误: --ref 缺少参数" >&2; exit 1; }
               REF="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,14p' "$0" 2>/dev/null || cat <<'EOF'
用法: curl -fsSL <bootstrap.sh 地址> | bash -s -- --profile web
  可选: --ref <branch-or-tag>，其余参数传给 install.sh
EOF
      exit 0 ;;
    *)         break ;;
  esac
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

url="https://github.com/${REPO}/archive/${REF}.tar.gz"
echo "→ 下载 ${REPO} @ ${REF}"
if ! curl -fsSL --retry 2 --connect-timeout 15 "$url" -o "$tmp/src.tar.gz"; then
  echo "错误: 下载失败 ($url)" >&2
  echo "      大陆网络可先设置代理，或改用仓库 Release 里的离线包手动安装。" >&2
  exit 1
fi

tar -xzf "$tmp/src.tar.gz" -C "$tmp"

dir="$(find "$tmp" -maxdepth 1 -type d -name '*dsh-deepseek-balance*' | head -1)"
if [ -z "$dir" ] || [ ! -x "$dir/install.sh" ]; then
  echo "错误: 解压后没有找到 install.sh，仓库结构可能变了。" >&2
  exit 1
fi

echo "→ 执行安装"
"$dir/install.sh" "$@"
