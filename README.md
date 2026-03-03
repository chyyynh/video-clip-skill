# video-clip-skill

Claude Code skills for YouTube video clipping, transcription, and bilingual subtitle generation.

## Skills

| Plugin | Skill | What it does | Requirements |
|--------|-------|-------------|--------------|
| `clip-api` | `/clip` | Clip via hosted API, returns download URL | `CLIP_API_KEY` |
| `clip-local` | `/clip-local` | Clip locally with full subtitle pipeline | `yt-dlp` + `ffmpeg` + `python3` |

## Install

```
/plugin marketplace add github:chyyynh/video-clip-skill
/plugin install clip-local
```

Restart Claude Code after installing.

## Setup

### clip-api

```bash
export CLIP_API_KEY="nsc_your_key_here"
```

### clip-local

```bash
# macOS
brew install yt-dlp ffmpeg

# Linux
pip install yt-dlp && sudo apt install ffmpeg

# Optional — Whisper transcription when YouTube has no auto-subs
export GROQ_API_KEY="gsk_..."
```

## Usage

### Clip with time range

```
/clip-local clip dQw4w9WgXcQ from 0:10 to 0:30
/clip-local clip dQw4w9WgXcQ 1:00 2:00 with bilingual zh-TW subtitles
```

### Auto-highlight (no time range)

```
/clip-local find the best moments in https://youtube.com/watch?v=xxx
/clip-local extract highlights from dQw4w9WgXcQ with Chinese subtitles
```

Claude reads the full transcript, picks 3–5 highlights, and lets you choose which to clip.

### Transcript only

```
/clip-local get the transcript of dQw4w9WgXcQ
```

### Via API

```
/clip dQw4w9WgXcQ 0:10 0:30
/clip get transcript of dQw4w9WgXcQ
```

## Features

- **Clip** — trim video to a specific time range
- **Auto-highlight** — AI picks the best moments, you choose which to clip
- **Transcribe** — YouTube auto-subs or Groq Whisper fallback
- **Translate** — bilingual subtitles translated by Claude (not YouTube auto-translate)
- **Karaoke subtitles** — CapCut-style word-by-word highlight, burned into video

## License

MIT
