# video-clip-skill

Claude Code plugin for YouTube video clipping, transcription, and subtitle generation.

## Skills

| Skill | Description | Requirements |
|-------|-------------|--------------|
| `/clip` | Clip via hosted API, returns download URL | `CLIP_API_KEY` |
| `/clip-local` | Clip locally with full subtitle pipeline | `yt-dlp` + `ffmpeg` + `python3` |

Both skills support clipping, transcription, translation, and CapCut-style karaoke subtitle burning.

## Install

```
/plugin install github:chyyynh/video-clip-skill
```

## Setup

### API mode (`/clip`)

```bash
export CLIP_API_KEY="nsc_your_key_here"
```

### Local mode (`/clip-local`)

```bash
brew install yt-dlp ffmpeg   # macOS

# Optional
export GROQ_API_KEY="gsk_..."           # Whisper transcription
export OPENROUTER_API_KEY="sk-or-..."   # Subtitle translation
```

## Usage

```
/clip dQw4w9WgXcQ 0:10 0:30
/clip get transcript of dQw4w9WgXcQ
/clip-local clip dQw4w9WgXcQ 1:00 2:00 with bilingual zh-TW subtitles
```

## License

MIT
