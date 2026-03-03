---
name: clip-local
description: Clip a YouTube video locally using yt-dlp and ffmpeg. Supports transcription, translation, and CapCut-style karaoke subtitle burning. Use when the user wants local video clipping without an API key.
argument-hint: "[youtube-url-or-id] [start] [end] [output]"
---

# Video Clip (Local)

Requires `yt-dlp`, `ffmpeg`, and `python3`. Check with `command -v`.

## Pipeline

Depending on what the user asks for, run the relevant stages:

### 1. Clip video

Use `yt-dlp --get-url` to resolve direct stream URLs (no download), then `ffmpeg` to clip.

- Without subtitles: use `-c copy` (stream copy, instant).
- With subtitles: re-encode with `-vf "ass=subs.ass" -c:v libx264 -preset fast -crf 23`.
- Use input seeking (`-ss` before `-i`) so only the needed segment is downloaded.
- If separate video+audio streams, use two inputs with `-map 0:v:0 -map 1:a:0`.
- yt-dlp args: `--no-playlist --no-warnings --force-ipv4 --extractor-args 'youtube:player-client=default,mweb'`

### 2. Get transcript

Try YouTube auto-subs first via `yt-dlp --write-auto-sub --sub-format vtt --skip-download`.

If no subs available and user has `GROQ_API_KEY`:
- Download audio: `yt-dlp -f ba -x --audio-format mp3 --postprocessor-args 'ffmpeg:-ac 1 -ar 16000 -b:a 64k'`
- Send to Groq Whisper API: `POST https://api.groq.com/openai/v1/audio/transcriptions` with `model=whisper-large-v3`, `response_format=verbose_json`
- Convert response segments to VTT format

### 3. Translate subtitles

Read the VTT file, translate the subtitle text yourself, and write a new VTT file with the translations. You are a language model — do this directly without calling any external API.

- Keep the exact same timestamps
- For bilingual mode: write both original and translated text under each timestamp
- Keep translations concise and natural for subtitles
- Do not translate proper nouns unless they have well-known translations

### 4. Generate karaoke subtitles (ASS)

Use the template at `$PLUGIN_DIR/scripts/ass-karaoke.py`:

```
python3 "$PLUGIN_DIR/scripts/ass-karaoke.py" subs.vtt -o subs.ass [-t translated.vtt] [--offset START_SECONDS]
```

This generates CapCut-style ASS subtitles with:
- Per-word karaoke highlight (grey → white)
- CJK text split by character for per-char timing
- Bilingual layout if translation VTT provided
- YouTube rolling caption deduplication built-in
- `--offset` adjusts timestamps relative to clip start

### 5. Burn subtitles into clip

Pass the ASS file to ffmpeg: `-vf "ass=subs.ass"` with re-encoding.

## Common Issues

- YouTube throttling: add `--cookies-from-browser chrome` to yt-dlp
- Missing CJK fonts for ASS: install `fonts-noto-cjk` (Linux) or `font-noto-sans-cjk-tc` (macOS Homebrew)
- Groq 25MB audio limit: for videos >50min, split audio into chunks first
- Stream URLs expire after ~6h: re-resolve if clip fails
