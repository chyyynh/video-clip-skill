---
name: clip-local
description: Clips a YouTube video locally using yt-dlp and ffmpeg. Supports transcription, translation, and CapCut-style karaoke subtitle burning. Triggers when the user wants local video clipping without an API key.
argument-hint: "[youtube-url-or-id] [start] [end] [output]"
---

# Video Clip (Local)

Requires `yt-dlp`, `ffmpeg`, and `python3`. Check with `command -v`.

## Pipeline

### 1. Clip video

Use `yt-dlp --get-url` to resolve direct stream URLs (no download), then `ffmpeg` to clip.

- Without subtitles: `-c copy` (stream copy, instant)
- With subtitles: re-encode with `-vf "ass=subs.ass" -c:v libx264 -preset fast -crf 23`
- Use input seeking (`-ss` before `-i`) so only the needed segment is downloaded
- Separate video+audio streams: two inputs with `-map 0:v:0 -map 1:a:0`
- yt-dlp args: `--no-playlist --no-warnings --force-ipv4 --extractor-args 'youtube:player-client=default,mweb'`

### 2. Get transcript

Try YouTube auto-subs first: `yt-dlp --write-auto-sub --sub-format vtt --skip-download`.

If no subs and user has `GROQ_API_KEY`:
- Download audio: `yt-dlp -f ba -x --audio-format mp3 --postprocessor-args 'ffmpeg:-ac 1 -ar 16000 -b:a 64k'`
- Transcribe: `POST https://api.groq.com/openai/v1/audio/transcriptions` with `model=whisper-large-v3`, `response_format=verbose_json`
- Convert response segments to VTT

### 3. Translate subtitles

Read the VTT file, translate the subtitle text yourself, and write a new VTT. You are a language model — do this directly without any external API.

- Keep exact same timestamps
- Bilingual mode: write both original and translated text under each timestamp
- Keep translations concise and natural for subtitles

### 4. Generate karaoke subtitles (ASS)

Use the script at `$PLUGIN_DIR/scripts/ass-karaoke.py`:

```
python3 "$PLUGIN_DIR/scripts/ass-karaoke.py" subs.vtt -o subs.ass [-t translated.vtt] [--offset START_SECONDS]
```

Features: per-word karaoke highlight (grey → white), CJK per-character splitting, bilingual layout, YouTube rolling caption deduplication.

### 5. Burn subtitles

Pass the ASS file to ffmpeg: `-vf "ass=subs.ass"` with re-encoding.

## Common Issues

- YouTube throttling: add `--cookies-from-browser chrome` to yt-dlp
- Missing CJK fonts: `brew install font-noto-sans-cjk-tc` (macOS) or `sudo apt install fonts-noto-cjk` (Linux)
- Groq 25MB limit: split audio for videos >50min
- Stream URLs expire after ~6h: re-resolve if clip fails
