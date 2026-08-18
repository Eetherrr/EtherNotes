#!/usr/bin/env bash
# 生成一篇符合 EtherNotes 规范的新文章。
#
# 用法:
#   ./scripts/new-post.sh <目录: 列/子列[/系列]> <slug> "文章标题"
#
# 示例:
#   ./scripts/new-post.sh fpga/protocol/i2c i2c-arbitration "I2C 仲裁"
#   ./scripts/new-post.sh fpga/misc cdc-notes "跨时钟域补遗"
#
# 生成路径: docs/_posts/<目录>/<今天日期>-<slug>.md
# 若目标目录已存在文章，order 会自增（系列内排序用，非系列目录可自行删除该行）。
set -euo pipefail

usage() {
  echo "用法: $0 <目录: 列/子列[/系列]> <slug> \"文章标题\"" >&2
  exit 1
}
[ "$#" -ge 3 ] || usage

DIR="$1"
SLUG="$2"
TITLE="$3"

# slug 只看 ASCII 小写/数字/连字符
if ! printf '%s' "$SLUG" | grep -Eq '^[a-z0-9][a-z0-9-]*$'; then
  echo "slug 只能包含小写字母/数字/连字符: $SLUG" >&2
  exit 1
fi

DATE="$(date +%F)"
BASE="docs/_posts"
TARGET_DIR="$BASE/$DIR"
mkdir -p "$TARGET_DIR"
FILE="$TARGET_DIR/$DATE-$SLUG.md"

if [ -e "$FILE" ]; then
  echo "已存在: $FILE" >&2
  exit 1
fi

# categories = 目录路径
CATS="$(printf '%s' "$DIR" | tr '/' ' ')"

# 若目录下已有文章，order = 现有文章数
ORDER=""
COUNT="$(find "$TARGET_DIR" -maxdepth 1 -type f -name '[0-9][0-9][0-9][0-9]-*.md' | wc -l | tr -d ' ')"
if [ "$COUNT" -gt 0 ]; then
  ORDER="$COUNT"
fi

{
  echo "---"
  echo "layout: post"
  echo "title: $TITLE"
  echo "date: $DATE"
  echo "categories: [$CATS]"
  [ -n "$ORDER" ] && echo "order: $ORDER"
  echo "---"
  echo ""
  echo "# $TITLE"
  echo ""
  echo "> 📝 本文正在编写中…"
} > "$FILE"

echo "已创建: $FILE"
