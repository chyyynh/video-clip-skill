#!/usr/bin/env bash
# clip.sh — Clip a YouTube video segment locally
# Usage: clip.sh <url-or-video-id> <start-seconds> <end-seconds> [output.mp4] [--subs subs.ass]
set -euo pipefail

URL_OR_ID="$1"
START="${2:-0}"
END="${3:-}"
OUTPUT="${4:-}"
ASS_PATH=""

# Parse optional --subs flag
shift 3 || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --subs) ASS_PATH="$2"; shift 2 ;;
    *) [[ -z "$OUTPUT" ]] && OUTPUT="$1"; shift ;;
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

# Default output filename
if [[ -z "$OUTPUT" ]]; then
  OUTPUT="clip_${VIDEO_ID}_${START}-${END}.mp4"
fi

# Get video duration if end not specified
if [[ -z "$END" ]]; then
  echo "[clip] No end time specified, querying video duration..."
  DURATION=$(yt-dlp --print duration --no-playlist --no-warnings --force-ipv4 "$FULL_URL" 2>/dev/null)
  END=$(printf "%.0f" "$DURATION")
  echo "[clip] Video duration: ${END}s"
fi

CLIP_DURATION=$((END - START))
echo "[clip] Clipping ${FULL_URL} from ${START}s to ${END}s (${CLIP_DURATION}s)"

# Resolve direct stream URLs (no download, just URL resolution ~2-3s)
echo "[clip] Resolving stream URLs..."
STREAM_URLS=$(yt-dlp --get-url -f 'bv[height<=720]+ba/b[height<=720]' \
  --no-playlist --no-warnings --force-ipv4 \
  --extractor-args 'youtube:player-client=default,mweb' \
  "$FULL_URL" 2>/dev/null)

VIDEO_URL=$(echo "$STREAM_URLS" | head -1)
AUDIO_URL=$(echo "$STREAM_URLS" | tail -1)

if [[ -z "$VIDEO_URL" ]]; then
  echo "[clip] ERROR: Failed to resolve stream URLs"
  exit 1
fi

# Build ffmpeg command
FFMPEG_ARGS=(-ss "$START" -i "$VIDEO_URL")

if [[ "$VIDEO_URL" != "$AUDIO_URL" ]]; then
  FFMPEG_ARGS+=(-ss "$START" -i "$AUDIO_URL")
  MAP_ARGS=(-map 0:v:0 -map 1:a:0)
else
  MAP_ARGS=(-map 0:v:0 -map 0:a:0)
fi

FFMPEG_ARGS+=(-t "$CLIP_DURATION" "${MAP_ARGS[@]}")

if [[ -n "$ASS_PATH" && -f "$ASS_PATH" ]]; then
  # Subtitle burn — re-encode
  echo "[clip] Burning subtitles from ${ASS_PATH}"
  FFMPEG_ARGS+=(
    -vf "ass=${ASS_PATH}"
    -c:v libx264 -preset fast -crf 23
    -c:a aac -b:a 128k
    -movflags +faststart
  )
else
  # No subtitles — stream copy (fast)
  FFMPEG_ARGS+=(-c copy -avoid_negative_ts make_zero)
fi

FFMPEG_ARGS+=(-y "$OUTPUT")

echo "[clip] Running ffmpeg..."
ffmpeg "${FFMPEG_ARGS[@]}" 2>/dev/null

SIZE=$(du -h "$OUTPUT" | cut -f1)
echo "[clip] Done! Output: ${OUTPUT} (${SIZE})"
