#!/usr/bin/env bash
#
# dsh-deepseek-balance 卸载脚本
#
# 删除 profile node_modules 里的包，并从 cordis.patch.yml 移除登记条目。
# 会先备份补丁文件。
#
# 用法：
#   ./uninstall.sh                    # 默认 --profile web
#   ./uninstall.sh --profile tui
#   ./uninstall.sh --home /path/.dsh
#
set -euo pipefail

PLUGIN_NAME="dsh-deepseek-balance"
ENTRY_ID="deepseek-balance"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
PROFILE="web"

while [ $# -gt 0 ]; do
  case "$1" in
    --profile) [ $# -ge 2 ] || { echo "错误: --profile 缺少参数" >&2; exit 1; }
               PROFILE="$2"; shift 2 ;;
    --home)    [ $# -ge 2 ] || { echo "错误: --home 缺少参数" >&2; exit 1; }
               DSH_HOME="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *)         echo "错误: 未知参数 '$1'" >&2; exit 1 ;;
  esac
done

PROFILE_DIR="$DSH_HOME/profiles/$PROFILE"
if [ ! -d "$PROFILE_DIR" ]; then
  echo "错误: profile '$PROFILE' 不存在: $PROFILE_DIR" >&2
  exit 1
fi

DEST="$PROFILE_DIR/node_modules/$PLUGIN_NAME"
if [ -d "$DEST" ]; then
  rm -rf "$DEST"
  echo "✓ 已删除插件目录: $DEST"
else
  echo "  插件目录不存在，跳过: $DEST"
fi

PATCH="$PROFILE_DIR/cordis.patch.yml"
if [ -f "$PATCH" ] && grep -q "$PLUGIN_NAME" "$PATCH"; then
  backup="$PATCH.bak.$(date +%Y%m%d-%H%M%S)"
  cp "$PATCH" "$backup"
  echo "  已备份原补丁: $backup"

  # 1) 删掉 id/name 这一对条目行
  # 2) 删掉因此变空的 "- insert:" 块头
  awk -v id="$ENTRY_ID" -v name="$PLUGIN_NAME" '
    {
      if ($0 ~ "^[[:space:]]*- id: " id "[[:space:]]*$") { skip_next_name = 1; next }
      if (skip_next_name && $0 ~ "^[[:space:]]*name: [\"'"'"']?" name "[\"'"'"']?[[:space:]]*$") {
        skip_next_name = 0; next
      }
      skip_next_name = 0
      lines[++n] = $0
    }
    END {
      for (i = 1; i <= n; i++) {
        if (lines[i] ~ /^- insert:[[:space:]]*$/) {
          # 看下一行是否已是顶层新条目或文件结束 => 空块，丢弃
          nxt = (i < n) ? lines[i + 1] : ""
          if (nxt ~ /^- / || nxt ~ /^[^[:space:]]/ || i == n) continue
        }
        print lines[i]
      }
    }
  ' "$backup" > "$PATCH"

  echo "✓ 已从补丁层移除条目: $PATCH"
else
  echo "  补丁层未登记该插件，跳过"
fi

cat <<EOF

卸载完成。重启 dsh web 或刷新页面即可。
EOF
