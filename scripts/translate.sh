#!/usr/bin/env bash
# translate.sh — Translate VTT subtitle file via OpenRouter (Gemini 2.5 Flash)
# Usage: translate.sh <input.vtt> <target-lang> [--output translated.vtt] [--bilingual]
set -euo pipefail

INPUT="$1"
TARGET_LANG="${2:-zh-TW}"
OUTPUT=""
BILINGUAL=false

shift 2 || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output|-o) OUTPUT="$2"; shift 2 ;;
    --bilingual) BILINGUAL=true; shift ;;
    *) shift ;;
  esac
done

[[ -z "$OUTPUT" ]] && OUTPUT="${INPUT%.vtt}.${TARGET_LANG}.vtt"

if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
  echo "[translate] ERROR: OPENROUTER_API_KEY not set."
  echo "  export OPENROUTER_API_KEY='sk-or-...'"
  exit 1
fi

# Extract text lines from VTT with index
echo "[translate] Extracting text from ${INPUT}..."
LINES=$(python3 -c "
import re, sys

with open('$INPUT') as f:
    content = f.read()

# Parse VTT cues
pattern = r'(\d{2}:\d{2}:\d{2}\.\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2}\.\d{3})\n((?:(?!\d{2}:\d{2}:\d{2}).+\n)*)'
cues = re.findall(pattern, content)

for i, (start, end, text) in enumerate(cues):
    clean = re.sub(r'<[^>]+>', '', text).strip().replace('\n', ' ')
    if clean:
        print(f'{i}|{clean}')
")

if [[ -z "$LINES" ]]; then
  echo "[translate] No text found in VTT file"
  exit 1
fi

NUM_LINES=$(echo "$LINES" | wc -l | tr -d ' ')
echo "[translate] Translating ${NUM_LINES} lines to ${TARGET_LANG}..."

# Language name mapping
declare -A LANG_NAMES=(
  ["zh-TW"]="Traditional Chinese"
  ["zh-CN"]="Simplified Chinese"
  ["ja"]="Japanese"
  ["ko"]="Korean"
  ["en"]="English"
  ["es"]="Spanish"
  ["fr"]="French"
  ["de"]="German"
)
LANG_NAME="${LANG_NAMES[$TARGET_LANG]:-$TARGET_LANG}"

# Call OpenRouter
PROMPT="Translate the following subtitle lines to ${LANG_NAME}.

Rules:
- Each line is formatted as \"index|text\"
- Return ONLY the translated lines in the same \"index|translated_text\" format
- Keep the same index numbers
- Do not add or remove lines
- Keep translations concise and natural for subtitles
- Do not translate proper nouns unless they have well-known translations

${LINES}"

RESPONSE=$(curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg prompt "$PROMPT" '{
    model: "google/gemini-2.5-flash",
    messages: [{role: "user", content: $prompt}],
    temperature: 0.3
  }')")

TRANSLATED=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty')

if [[ -z "$TRANSLATED" ]]; then
  echo "[translate] ERROR: Empty response from API"
  echo "$RESPONSE" | jq '.error // .' 2>/dev/null
  exit 1
fi

TRANS_COUNT=$(echo "$TRANSLATED" | grep -c '|' || echo "0")
echo "[translate] Got ${TRANS_COUNT}/${NUM_LINES} translations"

# Build translated VTT
python3 -c "
import re, sys

# Parse translations
translations = {}
for line in '''$TRANSLATED'''.strip().split('\n'):
    line = line.strip()
    if '|' not in line: continue
    idx, text = line.split('|', 1)
    try:
        translations[int(idx)] = text.strip()
    except ValueError:
        pass

# Parse original VTT
with open('$INPUT') as f:
    content = f.read()

pattern = r'(\d{2}:\d{2}:\d{2}\.\d{3}\s*-->\s*\d{2}:\d{2}:\d{2}\.\d{3})\n((?:(?!\d{2}:\d{2}:\d{2}).+\n)*)'
cues = list(re.finditer(pattern, content))

bilingual = $([[ "$BILINGUAL" == true ]] && echo "True" || echo "False")

print('WEBVTT')
print()

for i, match in enumerate(cues):
    timestamp = match.group(1)
    original = re.sub(r'<[^>]+>', '', match.group(2)).strip()
    translated = translations.get(i, '')

    print(timestamp)
    if bilingual and translated:
        print(original)
        print(translated)
    elif translated:
        print(translated)
    else:
        print(original)
    print()
" > "$OUTPUT"

echo "[translate] Done! Saved ${OUTPUT}"
