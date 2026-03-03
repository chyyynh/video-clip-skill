---
name: clip
description: Clip a YouTube video segment or fetch its transcript via the hosted Clip API. Use when the user asks to clip, cut, or trim a video, or get a transcript/subtitles. Requires CLIP_API_KEY.
argument-hint: "[youtube-url-or-id] [start] [end]"
---

# Video Clip (API)

## Environment

- `CLIP_API_KEY` — required, starts with `nsc_`
- `CLIP_API_URL` — optional, defaults to `https://clip-api-production-8bf7.up.railway.app`

If `CLIP_API_KEY` is not set, tell the user to get one from their account settings and `export CLIP_API_KEY="nsc_..."`.

## API Endpoints

Base URL: `${CLIP_API_URL}/v1`

### POST /clip — Submit clip job

Request:
```json
{
  "videoId": "dQw4w9WgXcQ",
  "startTime": 10,
  "endTime": 30,
  "title": "optional title",
  "option": {
    "burn": true,
    "translate": "zh-TW",
    "display": "bilingual"
  }
}
```

- `videoId` or `url` — one required
- `endTime` — optional (defaults to video end, max 600s)
- `option.burn` — burn subtitles into video
- `option.translate` — language code: `zh-TW`, `zh-CN`, `ja`, `ko`, `en`, `es`, `fr`, `de`
- `option.display` — `"translation"` or `"bilingual"`

Response: `{ "ok": true, "data": { "jobId": "uuid" } }`

### GET /clip/:jobId — Poll job status

Response: `{ "ok": true, "data": { "status": "...", "progress": 75, "result": { "clipUrl": "https://...", "fileName": "...", "durationSeconds": 20 } } }`

Status: `queued` → `resolving` → `transcribing` → `translating` → `clipping` → `uploading` → `done` | `error`

Poll every 3-5 seconds. When `done`, show `clipUrl`. When `error`, show `data.error`.

### POST /transcript — Fetch transcript

Request: `{ "videoId": "dQw4w9WgXcQ" }`

Response: `{ "ok": true, "data": { "segments": [{"startTime": 0.0, "endTime": 5.2, "text": "..."}], "language": "en" } }`

All endpoints require `Authorization: Bearer $CLIP_API_KEY` header.
