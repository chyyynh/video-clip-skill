#!/usr/bin/env python3
"""
generate-ass.py — Generate ASS subtitles with karaoke highlighting from VTT.
CapCut-inspired style: bold sans-serif, thick outline + shadow, word-by-word highlight.

Usage:
  python3 generate-ass.py <input.vtt> [--output subs.ass] [--translation translated.vtt] [--offset 0]
"""

import argparse
import re
import sys
from pathlib import Path

CJK_RE = re.compile(r'[\u4e00-\u9fff\u3400-\u4dbf\u3040-\u309f\u30a0-\u30ff\uff00-\uffef]')

ASS_HEADER = """[Script Info]
Title: Clip Subtitles
ScriptType: v4.00+
PlayResX: 1920
PlayResY: 1080
WrapStyle: 0
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Noto Sans TC,60,&H00FFFFFF,&H00555555,&H00000000,&H80000000,-1,0,0,0,100,100,0,0,1,4,3,2,40,40,100,1
Style: Translation,Noto Sans TC,44,&H00FFFFFF,&H00555555,&H00000000,&H80000000,-1,0,0,0,100,100,0,0,1,3,2,2,40,40,40,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""


def format_ass_time(seconds: float) -> str:
    total_cs = round(seconds * 100)
    h = total_cs // 360000
    m = (total_cs % 360000) // 6000
    s = (total_cs % 6000) // 100
    cs = total_cs % 100
    return f"{h}:{m:02d}:{s:02d}.{cs:02d}"


def escape_ass(text: str) -> str:
    return text.replace("\\", "\\\\").replace("{", "\\{").replace("}", "\\}").replace("\n", "\\N")


def split_karaoke_units(text: str) -> list[str]:
    words = text.split()
    if not CJK_RE.search(text):
        return words
    units = []
    for word in words:
        if CJK_RE.search(word) and not re.search(r'[a-zA-Z0-9]', word):
            units.extend(list(word))
        else:
            units.append(word)
    return units


def build_karaoke(text: str, duration_cs: int) -> str:
    units = split_karaoke_units(text)
    if not units:
        return escape_ass(text)
    if len(units) == 1:
        return f"{{\\k{duration_cs}}}{escape_ass(units[0])}"

    total_chars = sum(len(u) for u in units)
    used_cs = 0
    parts = []
    for i, unit in enumerate(units):
        is_last = i == len(units) - 1
        unit_cs = (duration_cs - used_cs) if is_last else max(1, round(len(unit) / total_chars * duration_cs))
        used_cs += unit_cs
        sep = " " if i > 0 and (len(unit) > 1 or not CJK_RE.search(unit)) else ""
        parts.append(f"{sep}{{\\k{unit_cs}}}{escape_ass(unit)}")
    return "".join(parts)


def parse_vtt_time(ts: str) -> float:
    parts = ts.strip().split(":")
    if len(parts) == 3:
        h, m, s = parts
    else:
        h = "0"
        m, s = parts
    return int(h) * 3600 + int(m) * 60 + float(s)


def parse_vtt(path: str) -> list[dict]:
    content = Path(path).read_text(encoding="utf-8")
    pattern = r"(\d{2}:\d{2}:\d{2}\.\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2}\.\d{3})\n((?:(?!\d{2}:\d{2}:\d{2}).+\n)*)"
    segments = []
    for match in re.finditer(pattern, content):
        start = parse_vtt_time(match.group(1))
        end = parse_vtt_time(match.group(2))
        text = re.sub(r"<[^>]+>", "", match.group(3)).strip().replace("\n", " ")
        if text:
            # Merge consecutive identical text
            if segments and segments[-1]["text"] == text:
                segments[-1]["end"] = end
            else:
                segments.append({"start": start, "end": end, "text": text})
    return deduplicate_rolling(segments)


def deduplicate_rolling(segments: list[dict]) -> list[dict]:
    if len(segments) <= 1:
        return segments
    # Remove prefix segments
    non_prefix = []
    for i, seg in enumerate(segments):
        if i + 1 < len(segments) and segments[i + 1]["text"].startswith(seg["text"]):
            continue
        non_prefix.append(seg)
    if len(non_prefix) <= 1:
        return non_prefix
    # Trim suffix-prefix overlap
    result = [non_prefix[0]]
    for seg in non_prefix[1:]:
        prev = result[-1]
        overlap = suffix_prefix_overlap(prev["text"], seg["text"])
        if overlap > 0:
            trimmed = seg["text"][overlap:].strip()
            if not trimmed:
                prev["end"] = max(prev["end"], seg["end"])
            else:
                result.append({"start": seg["start"], "end": seg["end"], "text": trimmed})
        else:
            result.append(seg)
    return result


def suffix_prefix_overlap(a: str, b: str) -> int:
    max_len = min(len(a), len(b))
    for length in range(max_len, 0, -1):
        if b.startswith(a[-length:]):
            return length
    return 0


def main():
    parser = argparse.ArgumentParser(description="Generate ASS subtitles with karaoke")
    parser.add_argument("input", help="Input VTT file")
    parser.add_argument("--output", "-o", default="subs.ass", help="Output ASS file")
    parser.add_argument("--translation", "-t", help="Translated VTT file for bilingual display")
    parser.add_argument("--offset", type=float, default=0, help="Time offset in seconds (clip start time)")
    args = parser.parse_args()

    segments = parse_vtt(args.input)
    if not segments:
        print("[ass] No segments found in VTT", file=sys.stderr)
        sys.exit(1)

    # Load translations if provided
    translations = {}
    if args.translation:
        trans_segs = parse_vtt(args.translation)
        for i, seg in enumerate(trans_segs):
            if i < len(segments):
                translations[i] = seg["text"]

    events = []
    for i, seg in enumerate(segments):
        rel_start = max(0, seg["start"] - args.offset)
        rel_end = max(rel_start, seg["end"] - args.offset)
        start = format_ass_time(rel_start)
        end = format_ass_time(rel_end)
        duration_cs = round((rel_end - rel_start) * 100)

        karaoke = build_karaoke(seg["text"], duration_cs)
        events.append(f"Dialogue: 0,{start},{end},Default,,0,0,0,,{karaoke}")

        if i in translations:
            events.append(f"Dialogue: 1,{start},{end},Translation,,0,0,0,,{escape_ass(translations[i])}")

    Path(args.output).write_text(ASS_HEADER + "\n".join(events) + "\n", encoding="utf-8")
    print(f"[ass] Generated {args.output} ({len(segments)} segments, {len(translations)} translations)")


if __name__ == "__main__":
    main()
