# video-clip-skill

Claude Code skills for YouTube video clipping, transcription, and bilingual subtitle generation.

## Plugins

| Plugin | Skill | What it does | Requirements |
|--------|-------|-------------|--------------|
| `clip-api` | `/clip` | Clip via hosted API, returns download URL | `CLIP_API_KEY` |
| `clip-local` | `/clip-local` | Clip locally with subtitle pipeline | `yt-dlp` + `ffmpeg` + `python3` |

## Install

```
/plugin install github:chyyynh/video-clip-skill
```

Restart Claude Code after installing. Both `/clip` and `/clip-local` will be available.

## Setup

### clip-api

Get an API key from your account settings, then:

```bash
export CLIP_API_KEY="nsc_your_key_here"
```

### clip-local

```bash
# macOS
brew install yt-dlp ffmpeg

# Linux
pip install yt-dlp && sudo apt install ffmpeg

# Optional — for Whisper transcription (when YouTube has no auto-subs)
export GROQ_API_KEY="gsk_..."
```

## Usage

```
/clip dQw4w9WgXcQ 0:10 0:30
/clip clip this video with Chinese subtitles https://youtube.com/watch?v=xxx

/clip-local dQw4w9WgXcQ 0:00 1:00
/clip-local 幫我剪這段影片 0:30 到 2:00 加上中英雙語字幕 https://youtube.com/watch?v=xxx
```

### What each skill can do

- **Clip** — trim a video to a specific time range
- **Transcribe** — get the transcript / subtitles
- **Translate** — bilingual subtitles (Claude translates, not YouTube auto-translate)
- **Karaoke subtitles** — CapCut-style word-by-word highlight, burned into video

## License

MIT
