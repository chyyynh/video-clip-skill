---
name: clip-local
description: Clip a YouTube video locally using yt-dlp and ffmpeg. Supports transcription (YouTube subs or Groq Whisper), translation (OpenRouter), and CapCut-style karaoke subtitle burning. Use when the user wants to clip a video, fetch a transcript, or generate subtitles locally.
argument-hint: "[youtube-url-or-id] [start] [end] [output]"
---

# Video Clip (Local)

Full-featured YouTube video clipping pipeline using local tools.

## Decision Tree

```
User request
├─ "clip/cut/trim this video"
│   ├─ With subtitles? → Full pipeline (transcript → translate → ASS → clip --subs)
│   └─ Without subtitles? → clip.sh only (fast, stream copy)
├─ "get transcript/subtitles"
│   └─ transcript.sh (YouTube auto-subs, falls back to Whisper)
├─ "translate subtitles"
│   └─ translate.sh (OpenRouter Gemini 2.5 Flash)
└─ "burn subtitles into video"
    └─ generate-ass.py → clip.sh --subs
```

## Prerequisites

Check that required tools are installed:
```bash
yt-dlp --version && ffmpeg -version | head -1 && python3 --version
```

If missing:
- macOS: `brew install yt-dlp ffmpeg python3`
- Linux: `pip install yt-dlp && sudo apt install ffmpeg python3`

Optional env vars for advanced features:
- `GROQ_API_KEY` — Whisper transcription (when YouTube has no auto-subs)
- `OPENROUTER_API_KEY` — subtitle translation

## Scripts Reference

All scripts are in `$PLUGIN_DIR/scripts/`. Run them with `bash` or `python3`.

### clip.sh — Clip video

```bash
bash "$PLUGIN_DIR/scripts/clip.sh" <url-or-id> <start> <end> [output.mp4] [--subs subs.ass]
```

How it works:
1. Resolves direct stream URLs via `yt-dlp --get-url` (~2-3s, no download)
2. Clips via `ffmpeg` with input seeking (`-ss` before `-i`) — only downloads the needed segment
3. Without `--subs`: stream copy (very fast, no re-encoding)
4. With `--subs`: re-encodes with `libx264 -preset fast -crf 23` + ASS subtitle filter

### transcript.sh — Fetch transcript

```bash
bash "$PLUGIN_DIR/scripts/transcript.sh" <url-or-id> [--lang en] [--whisper] [-o output.vtt]
```

Two-stage fallback:
1. **YouTube auto-subs** — free, instant, uses `yt-dlp --write-auto-sub`
2. **Groq Whisper** — requires `GROQ_API_KEY`, downloads audio then transcribes via `whisper-large-v3`

Output: WebVTT file with timestamps.

### translate.sh — Translate subtitles

```bash
bash "$PLUGIN_DIR/scripts/translate.sh" <input.vtt> <target-lang> [-o output.vtt] [--bilingual]
```

- Uses OpenRouter (Gemini 2.5 Flash) for fast, natural translation
- `--bilingual` preserves original text alongside translation
- Supported languages: `zh-TW`, `zh-CN`, `ja`, `ko`, `en`, `es`, `fr`, `de`
- Requires `OPENROUTER_API_KEY`

### generate-ass.py — Generate karaoke subtitles

```bash
python3 "$PLUGIN_DIR/scripts/generate-ass.py" <input.vtt> [-o subs.ass] [-t translated.vtt] [--offset N]
```

CapCut-inspired ASS subtitle generation:
- Bold Noto Sans TC, thick black outline + shadow (no background box)
- Per-word karaoke highlight: grey → white, timed by character/word length
- CJK-aware: splits Chinese/Japanese into per-character units
- Bilingual display: original karaoke on top, translation on bottom
- `--offset` adjusts timestamps to match clip start time
- Handles YouTube rolling caption deduplication automatically

## Full Pipeline Example

Clip + transcribe + translate + burn bilingual karaoke subtitles:

```bash
VIDEO="dQw4w9WgXcQ"
START=10
END=60

# 1. Get transcript
bash "$PLUGIN_DIR/scripts/transcript.sh" "$VIDEO" -o subs.vtt

# 2. Translate to Traditional Chinese (bilingual)
bash "$PLUGIN_DIR/scripts/translate.sh" subs.vtt zh-TW -o subs.zh-TW.vtt --bilingual

# 3. Generate ASS with karaoke (offset = clip start time)
python3 "$PLUGIN_DIR/scripts/generate-ass.py" subs.vtt -o subs.ass -t subs.zh-TW.vtt --offset "$START"

# 4. Clip with subtitles burned in
bash "$PLUGIN_DIR/scripts/clip.sh" "$VIDEO" "$START" "$END" output.mp4 --subs subs.ass
```

## Time Parsing

Accept flexible time formats and convert to seconds:
- `1:30` → 90
- `0:10-0:30` → start=10, end=30
- `10s to 30s` → start=10, end=30
- `from 1 minute to 2 minutes` → start=60, end=120
- `1h2m30s` → 3750

## Common Pitfalls

- **yt-dlp rate limiting**: YouTube may throttle. Add `--cookies-from-browser chrome` if downloads are slow or fail.
- **Missing fonts for ASS**: Karaoke subtitles use Noto Sans TC. If not installed, ffmpeg uses a fallback font. Install with `brew install font-noto-sans-cjk-tc` (macOS) or `sudo apt install fonts-noto-cjk` (Linux).
- **Large audio files for Whisper**: Groq has a 25MB limit. The transcript.sh script handles this, but very long videos (>50 min) may need manual splitting.
- **Stream URL expiry**: yt-dlp resolved URLs expire after ~6 hours. If a clip fails, re-run to get fresh URLs.

## Best Practices

- For quick clips without subtitles, ffmpeg uses stream copy — instant, no quality loss.
- Subtitle burning requires re-encoding (~1-3 min for a 60s clip on modern hardware).
- Use `--force-keyframes-at-cuts` in yt-dlp for frame-accurate cuts (slower but precise).
- After clipping: `open output.mp4` (macOS) or `xdg-open output.mp4` (Linux).
