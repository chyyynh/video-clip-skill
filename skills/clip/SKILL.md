---
name: clip
description: Clip a YouTube video segment via the hosted Clip API. Use when the user asks to clip, cut, trim, or extract a portion of a YouTube video, or fetch its transcript. Requires a CLIP_API_KEY.
argument-hint: "[youtube-url-or-id] [start] [end]"
---

# Video Clip (API Mode)

Clip YouTube videos and fetch transcripts via the hosted Clip API.

## Setup

Check that `CLIP_API_KEY` is set. If not, tell the user:
```
export CLIP_API_KEY="nsc_..."
export CLIP_API_URL="https://clip-api-production-8bf7.up.railway.app"  # optional, this is the default
```

## Capabilities

This skill handles both **clipping** and **transcript** requests.

---

## 1. Clip a Video

### Submit job

```bash
curl -s -X POST "${CLIP_API_URL:-https://clip-api-production-8bf7.up.railway.app}/v1/clip" \
  -H "Authorization: Bearer $CLIP_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "videoId": "<VIDEO_ID>",
    "startTime": <START_SECONDS>,
    "endTime": <END_SECONDS>,
    "title": "<OPTIONAL_TITLE>",
    "option": {
      "burn": true,
      "translate": "zh-TW",
      "display": "bilingual"
    }
  }'
```

- `videoId` or `url` — one is required
- `startTime` — seconds (default: 0)
- `endTime` — seconds (optional, defaults to video end, max 600s)
- `option` — optional subtitle settings:
  - `burn: true` — burn subtitles into video
  - `translate` — target language code (`zh-TW`, `ja`, `ko`, `en`, `es`, `fr`, `de`)
  - `display` — `"translation"` (translated only) or `"bilingual"` (original + translated)

Response: `{ "ok": true, "data": { "jobId": "..." } }`

### Poll for completion

Poll every 3-5 seconds:

```bash
curl -s "${CLIP_API_URL:-https://clip-api-production-8bf7.up.railway.app}/v1/clip/<JOB_ID>" \
  -H "Authorization: Bearer $CLIP_API_KEY"
```

Response: `{ "ok": true, "data": { "status": "...", "progress": N, "result": {...} } }`

**Status progression:** `queued` → `resolving` → `transcribing` → `translating` → `clipping` → `uploading` → `done` | `error`

When `done`, show the user:
- `result.clipUrl` — download URL
- `result.fileName` — suggested filename
- `result.durationSeconds` — clip duration

If `error`, show `data.error` message.

---

## 2. Fetch Transcript

```bash
curl -s -X POST "${CLIP_API_URL:-https://clip-api-production-8bf7.up.railway.app}/v1/transcript" \
  -H "Authorization: Bearer $CLIP_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"videoId": "<VIDEO_ID>"}'
```

Response: `{ "ok": true, "data": { "segments": [{"startTime": 0, "endTime": 5.2, "text": "..."}], "language": "en" } }`

The API tries YouTube auto-subs first, then falls back to Groq Whisper transcription.

Display the transcript with timestamps. Offer to save as `.txt` or `.srt` if the user wants.

---

## Time Parsing

Accept flexible time formats from the user and convert to seconds:
- `1:30` → 90
- `0:10-0:30` → startTime=10, endTime=30
- `10s to 30s` → startTime=10, endTime=30
- `from 1 minute to 2 minutes` → startTime=60, endTime=120
- `1h2m30s` → 3750

## Error Handling

- If `CLIP_API_KEY` is not set, tell the user how to get one and set it.
- If polling exceeds 5 minutes, warn the user the job may have stalled.
- On HTTP 401, tell the user their API key may be invalid or expired.
