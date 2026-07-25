#!/usr/bin/env bash
# Notion 页面字数统计
# 用法: bash scripts/wordcount.sh <page_id>
# 依赖: NOTION_TOKEN 环境变量, curl, jq (可选)

set -euo pipefail

PAGE_ID="${1:-}"
if [ -z "$PAGE_ID" ]; then
  echo "用法: bash scripts/wordcount.sh <page_id>"
  exit 1
fi

NOTION_API="https://api.notion.com/v1"
NOTION_VERSION="2022-06-28"

# 支持连字符格式的 UUID 和纯 32 位 hex
PAGE_ID="$(echo "$PAGE_ID" | tr -d '-' | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\)/\1-\2-\3-\4-\5/')"

fetch_blocks() {
  local block_id="$1"
  local cursor="${2:-}"
  local url="${NOTION_API}/blocks/${block_id}/children"
  local params="page_size=100"
  [ -n "$cursor" ] && params="${params}&start_cursor=${cursor}"

  curl -sf "$url?${params}" \
    -H "Authorization: Bearer ${NOTION_TOKEN}" \
    -H "Notion-Version: ${NOTION_VERSION}" 2>/dev/null || echo '{"results":[],"has_more":false}'
}

# 递归提取所有 rich_text 的 plain_text
extract_text() {
  local block_id="$1"
  local cursor=""
  while true; do
    local resp
    resp=$(fetch_blocks "$block_id" "$cursor")
    echo "$resp" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for block in data.get('results', []):
    bt = block.get('type', '')
    content = block.get(bt, {})
    # 文本类 block
    for key in ['rich_text', 'text', 'caption']:
        items = content.get(key, [])
        if isinstance(items, list):
            for item in items:
                t = item.get('plain_text', '') or item.get('text', {}).get('content', '')
                if t:
                    sys.stdout.write(t + '\n')
    # 嵌套 block (toggle, col, synced, etc.)
    if block.get('has_children', False):
        sys.stdout.write(f'__NEST__:{block[\"id\"]}\n')
"
    has_more=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('has_more', False))")
    if [ "$has_more" != "True" ]; then break; fi
    cursor=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('next_cursor', ''))")
  done
}

# 收集所有文本
TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

# 第一层
extract_text "$PAGE_ID" > "$TMPFILE"

# 递归处理嵌套
while grep -q "^__NEST__:" "$TMPFILE"; do
  nest_id=$(grep "^__NEST__:" "$TMPFILE" | head -1 | sed 's/^__NEST__://')
  sed -i '/^__NEST__:/d' "$TMPFILE"
  extract_text "$nest_id" >> "$TMPFILE"
done

# 统计分析
python3 -c "
import sys, re

with open('$TMPFILE') as f:
    text = f.read()

# 去除空白和标记行
lines = [l for l in text.split('\n') if l.strip() and not l.startswith('__NEST__')]
full_text = '\n'.join(lines)

# 中文字符
cn_chars = len(re.findall(r'[\u4e00-\u9fff\u3400-\u4dbf]', full_text))

# 英文单词
en_words = len(re.findall(r'[a-zA-Z]+', full_text))

# 数字
digits = len(re.findall(r'[0-9]', full_text))

# 总字符数（不含空白）
total_chars = len(full_text.replace(' ', '').replace('\n', ''))

# 总字符数（含空白）
total_with_space = len(full_text)

# 段落数
paras = len([p for p in full_text.split('\n') if p.strip()])

print(f'━━━━━━━━━━━━━━━━━━━━━━━━━━')
print(f'  Notion 页面字数统计')
print(f'━━━━━━━━━━━━━━━━━━━━━━━━━━')
print(f'  中文字符:     {cn_chars:>8,}')
print(f'  英文单词:     {en_words:>8,}')
print(f'  数字:         {digits:>8,}')
print(f'  总字符(去空): {total_chars:>8,}')
print(f'  总字符(含空): {total_with_space:>8,}')
print(f'  段落数:       {paras:>8,}')
print(f'━━━━━━━━━━━━━━━━━━━━━━━━━━')
"