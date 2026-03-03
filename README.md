# video-clip-skill

Claude Code plugin for YouTube video clipping, transcription, and subtitle generation.

## Skills

| Skill | Description | Requirements |
|-------|-------------|--------------|
| `/clip` | Clip via hosted API, returns download URL | `CLIP_API_KEY` |
| `/clip-local` | Clip locally with full subtitle pipeline | `yt-dlp` + `ffmpeg` |

Both skills support:
- Video clipping with precise timestamps
- Transcript fetching (YouTube auto-subs or Whisper)
- Subtitle translation (10+ languages)
- CapCut-style karaoke subtitle burning (word-by-word highlight)
- Bilingual subtitle display

## Install

```
/plugin install github:chyyynh/video-clip-skill
```

## Setup

### API mode (`/clip`) — recommended

Get an API key, then:

```bash
export CLIP_API_KEY="nsc_your_key_here"
```

### Local mode (`/clip-local`)

```bash
# Required
brew install yt-dlp ffmpeg   # macOS
# or: pip install yt-dlp && sudo apt install ffmpeg

# Optional — for Whisper transcription
export GROQ_API_KEY="gsk_..."

# Optional — for subtitle translation
export OPENROUTER_API_KEY="sk-or-..."
```

## Usage Examples

```
/clip dQw4w9WgXcQ 0:10 0:30
/clip https://youtube.com/watch?v=dQw4w9WgXcQ from 1:00 to 2:00 with Chinese subtitles
/clip-local dQw4w9WgXcQ 0:30 1:30 output.mp4
/clip-local get the transcript of dQw4w9WgXcQ
/clip-local clip dQw4w9WgXcQ 0:00 to 1:00 with bilingual zh-TW subtitles burned in
```

## Scripts

The `scripts/` directory contains standalone tools usable outside Claude Code:

| Script | Purpose |
|--------|---------|
| `clip.sh` | Clip video via yt-dlp + ffmpeg |
| `transcript.sh` | Fetch YouTube subs or Groq Whisper transcription |
| `translate.sh` | Translate VTT subtitles via OpenRouter |
| `generate-ass.py` | Generate ASS with karaoke highlighting |

## License

MIT
