#!/usr/bin/env bash
# Notion 页面字数统计
# Usage: bash scripts/wordcount.sh <page_id>
# Depends: NOTION_TOKEN env var, curl, python3

set -euo pipefail

PAGE_ID="${1:-}"
if [ -z "$PAGE_ID" ]; then
  echo "Usage: bash scripts/wordcount.sh <page_id>"
  exit 1
fi

NOTION_API="https://api.notion.com/v1"
NOTION_VERSION="2022-06-28"

# Normalize UUID
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
    for key in ['rich_text', 'text', 'caption']:
        items = content.get(key, [])
        if isinstance(items, list):
            for item in items:
                t = item.get('plain_text', '') or item.get('text', {}).get('content', '')
                if t:
                    sys.stdout.write(t + '\n')
    if block.get('has_children', False):
        sys.stdout.write('__NEST__:' + block['id'] + '\n')
"
    local has_more
    has_more=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('has_more', False))")
    if [ "$has_more" != "True" ]; then break; fi
    cursor=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('next_cursor', ''))")
  done
}

TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

extract_text "$PAGE_ID" > "$TMPFILE"

while grep -q "^__NEST__:" "$TMPFILE"; do
  nest_id=$(grep "^__NEST__:" "$TMPFILE" | head -1 | sed 's/^__NEST__://')
  sed -i '/^__NEST__:/d' "$TMPFILE"
  extract_text "$nest_id" >> "$TMPFILE"
done

python3 -c "
import sys, re
with open('$TMPFILE') as f:
    text = f.read()
lines = [l for l in text.split('\n') if l.strip() and not l.startswith('__NEST__')]
full_text = '\n'.join(lines)
cn = len(re.findall(r'[\u4e00-\u9fff\u3400-\u4dbf]', full_text))
en = len(re.findall(r'[a-zA-Z]+', full_text))
digits = len(re.findall(r'[0-9]', full_text))
print(f'Word count: {cn + en + digits}')
"