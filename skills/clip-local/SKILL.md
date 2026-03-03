---
name: clip-local
description: Clips a YouTube video locally using yt-dlp and ffmpeg. Supports auto-highlight detection, transcription, translation, and CapCut-style karaoke subtitle burning. Triggers when the user wants local video clipping, highlight extraction, or subtitle generation without an API key.
argument-hint: "[youtube-url-or-id] [start] [end] [output]"
---

# Video Clip (Local)

Requires `yt-dlp`, `ffmpeg`, and `python3`. Check with `command -v`.

## Finding plugin scripts

The ASS karaoke generator is bundled with this plugin. Find it once at the start:

```bash
ASS_SCRIPT=$(find ~/.claude/plugins -path '*/clip-local/*/scripts/ass-karaoke.py' 2>/dev/null | head -1)
```

## Auto-highlight mode

When the user does NOT specify start/end times (e.g., "幫我剪這個影片的精華" or "clip the best parts"):

1. Download the full transcript (step 1–2 below)
2. Read the entire transcript and identify 3–5 highlight segments. For each, note:
   - Start and end timestamps
   - A short description of why it's interesting (key insight, funny moment, dramatic turn, etc.)
3. Present the highlights to the user as numbered options and ask which ones to clip
4. Clip only the segments the user picks, then continue with the normal pipeline (translate, subtitle, etc.)

## Pipeline

### 1. Get video info and available subtitles

```bash
yt-dlp --print title --print duration_string --list-subs \
  --no-playlist --no-warnings --force-ipv4 "<URL>" 2>&1
```

This shows the title, duration, and all available subtitle tracks. Look at the output to determine the **original language** — it's the language listed under "Available automatic captions" that is NOT marked as "translated". YouTube metadata `language` field is often wrong, so always check the actual subtitle list.

### 2. Download original language subtitles

```bash
yt-dlp --write-auto-sub --sub-lang "<ORIGINAL_LANG>" --sub-format vtt --skip-download \
  --no-playlist --no-warnings --force-ipv4 \
  --extractor-args 'youtube:player-client=default,mweb' \
  -o "subs" "<URL>"
```

Only download subs in the **original language** you identified from step 1. Do NOT use YouTube's auto-translated subs — they are low quality. All translation is done by you.

### 2. Trim VTT to clip range

When clipping a portion (e.g., 10–130s), filter the VTT to only include cues in that range. Write a quick Python snippet to do this.

### 3. Translate subtitles

**Always translate yourself** — you are a language model. Read the trimmed VTT, translate each cue, and write a new VTT with the same timestamps.

- Keep translations concise and natural for subtitles
- Do not translate proper nouns unless they have well-known translations
- Write one translated VTT file (same timestamp format)

### 4. Generate ASS karaoke subtitles

```bash
python3 "$ASS_SCRIPT" <original.vtt> -o subs.ass -t <translated.vtt> --offset <START_SECONDS>
```

- First arg = **original language** VTT (karaoke timing on top line)
- `-t` = **translated** VTT (shown below karaoke line)
- `--offset` = clip start time (adjusts timestamps relative to clip start)

Handles YouTube rolling caption dedup, CJK per-char splitting, and bilingual layout.

### 5. Resolve stream URLs and clip

Get both video + audio URLs in **one call**:

```bash
URLS=$(yt-dlp --get-url -f 'bv[height<=720]+ba/b[height<=720]' \
  --no-playlist --no-warnings --force-ipv4 \
  --extractor-args 'youtube:player-client=default,mweb' "<URL>")
VIDEO_URL=$(echo "$URLS" | head -1)
AUDIO_URL=$(echo "$URLS" | tail -1)
```

Then clip with ffmpeg:

- With subtitles: `-vf "ass=subs.ass" -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 128k -movflags +faststart`
- Without subtitles: `-c copy -avoid_negative_ts make_zero`
- Input seeking: `-ss <START>` before each `-i`
- Separate streams: `-map 0:v:0 -map 1:a:0`

### Whisper fallback (no YouTube subs)

If yt-dlp finds no auto-subs and user has `GROQ_API_KEY`:

1. Download audio: `yt-dlp -f ba -x --audio-format mp3 --postprocessor-args 'ffmpeg:-ac 1 -ar 16000 -b:a 64k'`
2. Transcribe: `POST https://api.groq.com/openai/v1/audio/transcriptions` with `model=whisper-large-v3`, `response_format=verbose_json`
3. Convert segments to VTT

## Common issues

- YouTube throttling: add `--cookies-from-browser chrome`
- Missing CJK fonts for ASS: `brew install font-noto-sans-cjk-tc` (macOS)
- Groq 25MB audio limit: split audio for videos >50min
- Stream URLs expire ~6h: re-resolve if clip fails
- Subtitle burning re-encodes video (~1–3 min for 60s clip)
