#!/usr/bin/env bash
#
# dsh-deepseek-balance 安装脚本
#
# 把本包放进目标 profile 的 node_modules，并在该 profile 的补丁层
# (cordis.patch.yml) 里登记一行 loader 条目。
#
# 幂等：重复执行不会重复写入补丁；会先备份补丁文件。
#
# 用法：
#   ./install.sh                       # 默认 --profile web
#   ./install.sh --profile tui         # 指定 profile
#   ./install.sh --home /path/to/.dsh  # 指定 DSH home（默认 ~/.dsh）
#
set -euo pipefail

PLUGIN_NAME="dsh-deepseek-balance"
ENTRY_ID="deepseek-balance"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
PROFILE="web"

usage() {
  cat <<'EOF'
用法: ./install.sh [选项]

选项:
  --profile <name>   要安装到的 profile（默认: web）
  --home <path>      DSH home 目录（默认: $DSH_HOME 或 ~/.dsh）
  -h, --help         显示本帮助
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --profile)  [ $# -ge 2 ] || { echo "错误: --profile 缺少参数" >&2; exit 1; }
                PROFILE="$2"; shift 2 ;;
    --home)     [ $# -ge 2 ] || { echo "错误: --home 缺少参数" >&2; exit 1; }
                DSH_HOME="$2"; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *)          echo "错误: 未知参数 '$1'" >&2; usage >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- 前置检查 ----------------------------------------------------------------

if [ ! -d "$DSH_HOME/profiles" ]; then
  echo "错误: 找不到 $DSH_HOME/profiles" >&2
  echo "      请确认 DSH 已安装，或用 --home 指定正确的 home 目录。" >&2
  exit 1
fi

PROFILE_DIR="$DSH_HOME/profiles/$PROFILE"
if [ ! -d "$PROFILE_DIR" ]; then
  echo "错误: profile '$PROFILE' 不存在: $PROFILE_DIR" >&2
  echo "      可用的 profile:" >&2
  ls -1 "$DSH_HOME/profiles" 2>/dev/null | grep -v '^node_modules$' | sed 's/^/        - /' >&2
  echo "      用 --profile <name> 指定。" >&2
  exit 1
fi

for f in package.json lib/index.js lib/client.js; do
  if [ ! -f "$SCRIPT_DIR/$f" ]; then
    echo "错误: 包不完整，缺少 $f" >&2
    exit 1
  fi
done

# ---- 1. 安装包文件 ------------------------------------------------------------

DEST="$PROFILE_DIR/node_modules/$PLUGIN_NAME"
mkdir -p "$PROFILE_DIR/node_modules"
rm -rf "$DEST"
mkdir -p "$DEST/lib"
cp "$SCRIPT_DIR/package.json" "$DEST/package.json"
[ -f "$SCRIPT_DIR/README.md" ] && cp "$SCRIPT_DIR/README.md" "$DEST/README.md"
cp "$SCRIPT_DIR/lib/index.js" "$SCRIPT_DIR/lib/client.js" "$DEST/lib/"
echo "✓ 已安装插件文件: $DEST"

# ---- 2. 登记到补丁层 ----------------------------------------------------------

PATCH="$PROFILE_DIR/cordis.patch.yml"

is_registered() {
  # 同时容忍 name 用引号包裹的写法
  grep -qE "^[[:space:]]*name:[[:space:]]*[\"']?${PLUGIN_NAME}[\"']?[[:space:]]*$" "$1" 2>/dev/null
}

write_patch() {
  if [ -f "$PATCH" ] && [ -s "$PATCH" ] && is_registered "$PATCH"; then
    echo "✓ 补丁层已包含 $PLUGIN_NAME，跳过"
    return
  fi

  if [ ! -s "$PATCH" ]; then
    {
      echo "# Your patch layer for this dsh profile, applied after every bundle layer:"
      echo "# a top-level YAML array of loader patch entries."
      echo "- insert:"
      echo "    - id: $ENTRY_ID"
      echo "      name: $PLUGIN_NAME"
    } > "$PATCH"
    echo "✓ 已创建补丁层并登记条目: $PATCH"
    return
  fi

  local backup="$PATCH.bak.$(date +%Y%m%d-%H%M%S)"
  cp "$PATCH" "$backup"
  echo "  已备份原补丁: $backup"

  if grep -qE "^- insert:[[:space:]]*$" "$PATCH"; then
    # 合并进已有的首个 insert 块：在该块结束处（下一个顶层 "- " 之前）插入条目
    awk -v id="$ENTRY_ID" -v name="$PLUGIN_NAME" '
      BEGIN { done = 0; inblock = 0 }
      {
        if (!done && $0 ~ /^- insert:[[:space:]]*$/) { inblock = 1 }
        else if (inblock && $0 ~ /^- /) {
          printf "    - id: %s\n      name: %s\n", id, name
          done = 1; inblock = 0
        }
        print
      }
      END {
        if (!done) printf "    - id: %s\n      name: %s\n", id, name
      }
    ' "$backup" > "$PATCH"
    echo "✓ 已合并进现有 insert 块: $PATCH"
  else
    # 没有 insert 块（或写法不标准）：追加一个独立的 insert 块
    {
      echo ""
      echo "- insert:"
      echo "    - id: $ENTRY_ID"
      echo "      name: $PLUGIN_NAME"
    } >> "$PATCH"
    echo "✓ 已追加 insert 块: $PATCH"
  fi

  if ! is_registered "$PATCH"; then
    cp "$backup" "$PATCH"
    echo "错误: 补丁写入后校验失败，已回滚到 $backup" >&2
    exit 1
  fi
}

write_patch

# ---- 3. 组合校验 --------------------------------------------------------------

if command -v dsh >/dev/null 2>&1; then
  echo ""
  echo "正在校验组合结果…"
  if DSH_HOME="$DSH_HOME" dsh --profile "$PROFILE" --dump-config 2>/dev/null | grep -q "name: $PLUGIN_NAME"; then
    echo "✓ 组合校验通过，$PLUGIN_NAME 已进入 profile '$PROFILE' 的装载树"
  else
    echo "⚠ 未能从 --dump-config 确认该插件（可能 dsh 版本差异），请启动后检查侧边栏"
  fi
fi

cat <<EOF

安装完成。

下一步：
  1. 确认该 profile 已配置 DEEPSEEK_API_KEY 凭证（插件要用它查余额）
  2. 重启 dsh web，或刷新浏览器页面
  3. 侧边栏底部应出现 [¥] 余额指示器，点击可立即刷新

卸载：./uninstall.sh --profile $PROFILE
EOF
