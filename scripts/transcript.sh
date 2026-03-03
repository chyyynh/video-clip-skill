#!/usr/bin/env bash
# transcript.sh — Fetch YouTube transcript (auto-subs or Whisper)
# Usage: transcript.sh <url-or-video-id> [--whisper] [--lang en] [--output subs.vtt]
set -euo pipefail

URL_OR_ID="$1"; shift
USE_WHISPER=false
LANG="en"
OUTPUT=""
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --whisper) USE_WHISPER=true; shift ;;
    --lang) LANG="$2"; shift 2 ;;
    --output|-o) OUTPUT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Resolve full URL
if [[ "$URL_OR_ID" != http* ]]; then
  VIDEO_ID="$URL_OR_ID"
  FULL_URL="https://www.youtube.com/watch?v=${URL_OR_ID}"
else
  FULL_URL="$URL_OR_ID"
  VIDEO_ID=$(echo "$URL_OR_ID" | grep -oP '(?:v=|youtu\.be/)([A-Za-z0-9_-]{11})' | head -1 | sed 's/v=//' || echo "video")
fi

[[ -z "$OUTPUT" ]] && OUTPUT="transcript_${VIDEO_ID}.vtt"

# ── Try YouTube auto-subs first ──
if [[ "$USE_WHISPER" == false ]]; then
  echo "[transcript] Fetching YouTube auto-subs for ${VIDEO_ID}..."
  yt-dlp --write-auto-sub --sub-lang "${LANG}.*,en.*" --sub-format vtt \
    --skip-download --no-playlist --no-warnings --force-ipv4 \
    --extractor-args 'youtube:player-client=default,mweb' \
    -o "${WORK_DIR}/subs" "$FULL_URL" 2>/dev/null || true

  VTT_FILE=$(find "$WORK_DIR" -name 'subs.*.vtt' | head -1)
  if [[ -n "$VTT_FILE" ]]; then
    cp "$VTT_FILE" "$OUTPUT"
    SEGMENTS=$(grep -c '^\d\d:' "$OUTPUT" 2>/dev/null || echo "?")
    echo "[transcript] Done! Saved ${OUTPUT} (${SEGMENTS} cues)"
    exit 0
  fi
  echo "[transcript] No YouTube subs found, falling back to Whisper..."
fi

# ── Whisper transcription via Groq ──
if [[ -z "${GROQ_API_KEY:-}" ]]; then
  echo "[transcript] ERROR: GROQ_API_KEY not set. Required for Whisper transcription."
  echo "  export GROQ_API_KEY='gsk_...'"
  exit 1
fi

echo "[transcript] Downloading audio for Whisper..."
AUDIO_PATH="${WORK_DIR}/audio.mp3"
yt-dlp -f ba -x --audio-format mp3 \
  --postprocessor-args 'ffmpeg:-ac 1 -ar 16000 -b:a 64k' \
  --no-playlist --no-warnings --force-ipv4 \
  --extractor-args 'youtube:player-client=default,mweb' \
  -o "$AUDIO_PATH" "$FULL_URL" 2>/dev/null

AUDIO_SIZE=$(du -m "$AUDIO_PATH" | cut -f1)
echo "[transcript] Audio: ${AUDIO_SIZE}MB, sending to Groq whisper-large-v3..."

# Call Groq Whisper API
RESPONSE=$(curl -s -X POST "https://api.groq.com/openai/v1/audio/transcriptions" \
  -H "Authorization: Bearer ${GROQ_API_KEY}" \
  -F "file=@${AUDIO_PATH}" \
  -F "model=whisper-large-v3" \
  -F "response_format=verbose_json" \
  -F "timestamp_granularities[]=segment")

# Extract segments and build VTT
echo "WEBVTT" > "$OUTPUT"
echo "" >> "$OUTPUT"
echo "$RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for seg in data.get('segments', []):
    start = seg['start']
    end = seg['end']
    text = seg['text'].strip()
    sh = int(start // 3600)
    sm = int((start % 3600) // 60)
    ss = start % 60
    eh = int(end // 3600)
    em = int((end % 3600) // 60)
    es = end % 60
    print(f'{sh:02d}:{sm:02d}:{ss:06.3f} --> {eh:02d}:{em:02d}:{es:06.3f}')
    print(text)
    print()
" >> "$OUTPUT"

SEGMENTS=$(grep -c '^\d\d:' "$OUTPUT" 2>/dev/null || echo "?")
DETECTED_LANG=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('language','unknown'))" 2>/dev/null || echo "unknown")
echo "[transcript] Done! ${OUTPUT} (${SEGMENTS} segments, language=${DETECTED_LANG})"
