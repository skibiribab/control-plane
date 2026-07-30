from __future__ import annotations

import csv
import io
import json
import math
import os
import re
from collections.abc import Sequence
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path

from src.services.compress import FfmpegError, run_ffprobe

VIDEO_EXTENSIONS = frozenset({
    ".mp4", ".mkv", ".avi", ".mov", ".webm", ".m4v",
    ".mts", ".m2ts", ".ts", ".mpg", ".mpeg",
})

_FILENAME_RE = re.compile(r"^(?:(\d{2})-)?(.+?)(?:-\((\d{4})\))?$")
_FILTER_RE = re.compile(r"^(\w+)\s*(=|!=|<=|>=|<|>)\s*(.+)$")

_SIZE_UNITS = {"B": 1, "KiB": 1024, "MiB": 1024**2, "GiB": 1024**3, "TiB": 1024**4}

_RESOLUTION_TIERS: list[tuple[int, str]] = [
    (480, "SD"), (720, "HD"), (1080, "FHD"),
    (1440, "QHD"), (2160, "UHD"),
]


@dataclass
class ScannerInfo:
    filename: str = ""
    dir_rel: str = ""
    num: str = ""
    title: str = ""
    year: str = ""
    resolution: str = ""
    coded_res: str = ""
    dar: str = ""
    par: str = ""
    codec: str = ""
    profile: str = ""
    level: str = ""
    pix_fmt: str = ""
    bit_depth: str = ""
    color_range: str = ""
    color_space: str = ""
    color_transfer: str = ""
    color_primaries: str = ""
    hdr: str = ""
    bitrate: str = ""
    max_bitrate: str = ""
    fps: str = ""
    frames: str = ""
    scan_type: str = ""
    ref_frames: str = ""
    audio_codec: str = ""
    audio_channels: str = ""
    audio_layout: str = ""
    audio_rate: str = ""
    audio_bitrate: str = ""
    audio_streams: str = ""
    container: str = ""
    extension: str = ""
    size: str = ""
    runtime: str = ""
    total_streams: str = ""
    sub_streams: str = ""
    sub_languages: str = ""

    # Private fields for filtering (not in table output)
    _width: int = 0
    _height: int = 0
    _size_bytes: int = 0
    _bitrate_bps: int = 0
    _duration_secs: float = 0.0


_COLUMNS: list[str] = [
    "Title", "Year", "Filename", "Dir",
    "Resolution", "Coded_Res", "DAR", "PAR",
    "Codec", "Profile", "Level", "Pixel_Format", "Bit_Depth",
    "Color_Range", "Color_Space", "Color_Transfer", "Color_Primaries", "HDR",
    "Bitrate", "Max_Bitrate", "FPS", "Frames", "Scan_Type", "Ref_Frames",
    "Audio_Codec", "Audio_Channels", "Audio_Layout", "Audio_Rate",
    "Audio_Bitrate", "Audio_Streams",
    "Container", "Extension", "Size", "Runtime",
    "Total_Streams", "Sub_Streams", "Sub_Languages",
]


def probe_file(path: str | Path) -> ScannerInfo:
    path = str(path)
    data = run_ffprobe(["-show_streams", "-show_entries", "format=filename,nb_streams,format_name,duration,size,bit_rate", path])
    return _parse_probe(data, path)


def _locate_stream(streams: list[dict], codec_type: str) -> dict | None:
    for s in streams:
        if s.get("codec_type") == codec_type:
            return s
    return None


def _parse_probe(data: dict, path: str) -> ScannerInfo:
    info = ScannerInfo()
    info.filename = Path(path).name
    info.extension = Path(path).suffix.lower()

    streams = data.get("streams", [])
    video = _locate_stream(streams, "video")
    audio = _locate_stream(streams, "audio")

    fmt = data.get("format", {})

    # Container
    info.container = fmt.get("format_name", "")

    # Size
    raw_size = fmt.get("size")
    if raw_size:
        info._size_bytes = int(raw_size)
        info.size = _fmt_size(info._size_bytes)

    # Duration
    raw_dur = fmt.get("duration")
    if raw_dur:
        info._duration_secs = float(raw_dur)
        info.runtime = _fmt_duration(info._duration_secs)

    # Total streams
    info.total_streams = str(fmt.get("nb_streams", ""))

    # Stream counts
    audio_count = sum(1 for s in streams if s.get("codec_type") == "audio")
    info.audio_streams = str(audio_count)
    sub_count = sum(1 for s in streams if s.get("codec_type") == "subtitle")
    info.sub_streams = str(sub_count)
    sub_langs = sorted(
        set(
            s.get("tags", {}).get("language", "?")
            for s in streams if s.get("codec_type") == "subtitle"
        )
    )
    info.sub_languages = ",".join(sub_langs) if sub_langs else ""

    # ── Video ──
    if video:
        w = video.get("width")
        h = video.get("height")
        if w and h:
            info._width = int(w)
            info._height = int(h)
            info.resolution = f"{w}x{h}"

        cw = video.get("coded_width")
        ch = video.get("coded_height")
        if cw and ch and (int(cw) != info._width or int(ch) != info._height):
            info.coded_res = f"{cw}x{ch}"

        dar = video.get("display_aspect_ratio", "")
        if dar:
            info.dar = dar
        elif info._width and info._height:
            g = _gcd(info._width, info._height)
            info.dar = f"{info._width // g}:{info._height // g}"

        sar = video.get("sample_aspect_ratio", "")
        if sar:
            info.par = sar

        info.codec = video.get("codec_name", "")
        info.profile = _normalize_profile(video.get("profile", ""))
        info.level = str(video.get("level", "") or "")
        info.pix_fmt = video.get("pix_fmt", "")
        raw_depth = video.get("bits_per_raw_sample")
        info.bit_depth = str(raw_depth) if raw_depth else ""
        info.color_range = video.get("color_range", "")
        info.color_space = video.get("color_space", "")
        info.color_transfer = video.get("color_transfer", "")
        info.color_primaries = video.get("color_primaries", "")
        info.hdr = _detect_hdr(info.color_transfer, info.color_primaries)

        # Bitrate
        vbr = video.get("bit_rate")
        if vbr:
            info._bitrate_bps = int(vbr)
            info.bitrate = _fmt_bitrate_mbps(int(vbr))
        elif raw_size and raw_dur:
            computed = int(int(raw_size) * 8 / float(raw_dur))
            info._bitrate_bps = computed
            info.bitrate = _fmt_bitrate_mbps(computed)

        max_vbr = video.get("max_bit_rate")
        if max_vbr:
            info.max_bitrate = _fmt_bitrate_mbps(int(max_vbr))

        # FPS
        info.fps = _parse_fps(video.get("avg_frame_rate", ""))

        # Frames
        nf = video.get("nb_frames")
        if nf is not None and nf != "N/A":
            info.frames = str(nf)

        # Scan type
        field = video.get("field_order", "")
        if field in ("progressive", "unknown", ""):
            info.scan_type = "progressive"
        else:
            info.scan_type = field

        # Ref frames
        refs = video.get("refs")
        if refs is not None:
            info.ref_frames = str(refs)

    # ── Audio ──
    if audio:
        info.audio_codec = audio.get("codec_name", "")
        ch = audio.get("channels")
        if ch is not None:
            info.audio_channels = str(ch)
        info.audio_layout = audio.get("channel_layout", "")
        sr = audio.get("sample_rate")
        if sr:
            info.audio_rate = _fmt_sample_rate(int(sr))
        abr = audio.get("bit_rate")
        if abr:
            info.audio_bitrate = _fmt_bitrate_kbps(int(abr))

    return info


def _gcd(a: int, b: int) -> int:
    while b:
        a, b = b, a % b
    return a


def _detect_hdr(transfer: str | None, primaries: str | None) -> str:
    if transfer == "smpte2084":
        return "HDR10"
    if transfer == "arib-std-b67":
        return "HLG"
    if transfer == "smpte428":
        return "HDR"
    if primaries == "bt2020":
        return "HDR10" if transfer == "smpte2084" else "WCG"
    return ""


def _parse_fps(rational: str) -> str:
    if not rational:
        return ""
    if "/" in rational:
        parts = rational.split("/")
        try:
            num, den = float(parts[0]), float(parts[1])
            if den != 0:
                fps = num / den
                if fps == int(fps):
                    return str(int(fps))
                return f"{fps:.3f}".rstrip("0").rstrip(".")
            return ""
        except (ValueError, IndexError):
            return ""
    try:
        fps = float(rational)
        if fps == int(fps):
            return str(int(fps))
        return f"{fps:.3f}".rstrip("0").rstrip(".")
    except ValueError:
        return ""


def _fmt_bitrate_mbps(bps: int) -> str:
    if bps <= 0:
        return ""
    mbps = bps / 1_000_000
    if mbps < 0.01:
        return "<0.01"
    return f"{mbps:.2f}"


def _fmt_bitrate_kbps(bps: int) -> str:
    if bps <= 0:
        return ""
    return f"{bps // 1000}"


def _fmt_sample_rate(hz: int) -> str:
    if hz <= 0:
        return ""
    khz = hz / 1000
    if khz == int(khz):
        return str(int(khz))
    return f"{khz:.1f}"


def _fmt_size(bytes_val: int) -> str:
    if bytes_val <= 0:
        return ""
    for unit, divisor in [("TiB", 1024**4), ("GiB", 1024**3),
                          ("MiB", 1024**2), ("KiB", 1024)]:
        if bytes_val >= divisor:
            val = bytes_val / divisor
            if val >= 1:
                return f"{val:.2f}{unit}"
    return f"{bytes_val}B"


def _fmt_duration(secs: float) -> str:
    if secs <= 0:
        return ""
    total_s = int(secs)
    hours = total_s // 3600
    mins = (total_s % 3600) // 60
    if hours:
        return f"{hours}h{mins:02d}m"
    return f"{mins}m"


def _normalize_profile(profile: str) -> str:
    if profile == "Main 10":
        return "M10"
    if profile == "High 10":
        return "H10"
    if profile == "Main":
        return "Main"
    return profile


# ── Filename parsing ──

def parse_filename(name: str) -> tuple[str, str, str]:
    stem = Path(name).stem
    m = _FILENAME_RE.match(stem)
    if not m:
        return ("", stem, "")
    return (m.group(1) or "", m.group(2) or stem, m.group(3) or "")


# ── Directory walk ──

def probe_file_with_name(path: str | Path, dir_rel: str = "") -> ScannerInfo:
    info = probe_file(path)
    info.dir_rel = dir_rel
    num, title, year = parse_filename(info.filename)
    info.num = num
    info.title = title
    info.year = year
    return info


def scan_directory(path: str | Path) -> list[tuple[Path, list[ScannerInfo]]]:
    groups: dict[Path, list[ScannerInfo]] = {}
    root = Path(path).resolve()

    for dirpath, _dirs, files in os.walk(root, followlinks=False):
        current = Path(dirpath)
        video_files = sorted(f for f in files
                             if Path(f).suffix.lower() in VIDEO_EXTENSIONS)
        if not video_files:
            continue

        group: list[ScannerInfo] = []
        for f in video_files:
            fpath = current / f
            try:
                rel = str(fpath.parent.relative_to(root)) if fpath.parent != root else ""
                info = probe_file_with_name(str(fpath), dir_rel=rel)
                group.append(info)
            except FfmpegError:
                continue
        if group:
            groups[current] = group

    return sorted(groups.items(), key=lambda item: item[0])


def scan_directory_flat(path: str | Path) -> list[ScannerInfo]:
    all_files: list[ScannerInfo] = []
    for _dir, files in scan_directory(path):
        all_files.extend(files)
    return all_files


# ── Filtering ──

_FIELD_MAP: dict[str, str] = {
    "codec": "codec", "hdr": "hdr", "container": "container",
    "extension": "extension", "profile": "profile", "pix_fmt": "pix_fmt",
    "audio_codec": "audio_codec", "title": "title", "year": "year",
    "scan_type": "scan_type",
}


def _get_filter_field(info: ScannerInfo, field: str) -> str:
    attr = _FIELD_MAP.get(field)
    if attr:
        return getattr(info, attr, "")
    if field in ("resolution", "width"):
        return str(info._width) if info._width else ""
    if field == "height":
        return str(info._height) if info._height else ""
    if field == "bitrate":
        return str(info._bitrate_bps) if info._bitrate_bps else ""
    if field == "fps":
        return info.fps
    if field == "size":
        return str(info._size_bytes) if info._size_bytes else ""
    if field == "runtime":
        return str(info._duration_secs) if info._duration_secs else ""
    return ""


def _parse_size_human(s: str) -> int:
    s = s.strip()
    for unit in ("KiB", "MiB", "GiB", "TiB"):
        if s.endswith(unit):
            try:
                val = float(s[: -len(unit)].strip())
                return int(val * _SIZE_UNITS[unit])
            except ValueError:
                continue
    try:
        return int(s)
    except ValueError:
        raise ValueError(f"invalid size: {s}")


def _compare_str(val: str, op: str, target: str) -> bool:
    if op == "=":
        return val.lower() == target.lower()
    if op == "!=":
        return val.lower() != target.lower()

    try:
        v = float(val)
        t = float(target)
        if op == "<": return v < t
        if op == ">": return v > t
        if op == "<=": return v <= t
        if op == ">=": return v >= t
    except ValueError:
        pass

    try:
        v = _parse_size_human(val)
        t = _parse_size_human(target)
        if op == "<": return v < t
        if op == ">": return v > t
        if op == "<=": return v <= t
        if op == ">=": return v >= t
    except ValueError:
        pass

    return False


def apply_filters(files: list[ScannerInfo], filters: Sequence[str] | None) -> list[ScannerInfo]:
    if not filters:
        return files
    result = list(files)
    for expr in filters:
        m = _FILTER_RE.match(expr)
        if not m:
            continue
        field, op, target = m.group(1), m.group(2), m.group(3)
        result = [f for f in result if _compare_str(_get_filter_field(f, field), op, target)]
    return result


def apply_exclude(files: list[ScannerInfo], excludes: Sequence[str] | None) -> list[ScannerInfo]:
    if not excludes:
        return files
    import fnmatch
    result = list(files)
    for pat in excludes:
        result = [f for f in result if not fnmatch.fnmatch(f.filename, pat)]
    return result


# ── Stats ──

@dataclass
class ScanStats:
    total_files: int = 0
    total_size: str = ""
    total_runtime: str = ""
    avg_bitrate: str = ""
    by_codec: dict[str, int] | None = None
    by_hdr: dict[str, int] | None = None
    by_resolution_tier: dict[str, int] | None = None
    by_container: dict[str, int] | None = None
    largest: list[tuple[str, str, str]] | None = None


def _resolution_tier(height: int) -> str:
    for max_h, label in _RESOLUTION_TIERS:
        if height <= max_h:
            return label
    return "UHD+"


def compute_stats(files: list[ScannerInfo]) -> ScanStats:
    stats = ScanStats()
    stats.total_files = len(files)
    stats.by_codec = {}
    stats.by_hdr = {}
    stats.by_resolution_tier = {}
    stats.by_container = {}
    by_size: list[tuple[int, str, str, str]] = []

    total_size = 0
    total_dur = 0.0
    total_bitrate = 0
    bitrate_count = 0

    for f in files:
        stats.by_codec[f.codec] = stats.by_codec.get(f.codec, 0) + 1
        hdr_label = f.hdr if f.hdr else "SDR"
        stats.by_hdr[hdr_label] = stats.by_hdr.get(hdr_label, 0) + 1
        tier = _resolution_tier(f._height)
        stats.by_resolution_tier[tier] = stats.by_resolution_tier.get(tier, 0) + 1
        cont = f.container.split(",")[0] if f.container else "unknown"
        stats.by_container[cont] = stats.by_container.get(cont, 0) + 1

        total_size += f._size_bytes
        total_dur += f._duration_secs
        if f._bitrate_bps:
            total_bitrate += f._bitrate_bps
            bitrate_count += 1
        by_size.append((f._size_bytes, f.filename, f.size, f.bitrate))

    stats.total_size = _fmt_size(total_size)
    stats.total_runtime = _fmt_duration(total_dur)
    if bitrate_count:
        stats.avg_bitrate = _fmt_bitrate_mbps(total_bitrate // bitrate_count)

    by_size.sort(key=lambda x: x[0], reverse=True)
    stats.largest = [(fn, sz, br) for _, fn, sz, br in by_size[:5]]

    return stats


def format_stats_text(stats: ScanStats) -> str:
    lines: list[str] = []
    lines.append(f"Files: {stats.total_files}")
    lines.append(f"Total size: {stats.total_size}")
    lines.append(f"Total runtime: {stats.total_runtime}")
    if stats.avg_bitrate:
        lines.append(f"Average bitrate: {stats.avg_bitrate} Mbps")

    if stats.by_codec:
        lines.append("")
        lines.append("By codec:")
        total = sum(stats.by_codec.values())
        for k in sorted(stats.by_codec):
            pct = stats.by_codec[k] / total * 100
            lines.append(f"  {k}: {stats.by_codec[k]} ({pct:.1f}%)")

    if stats.by_hdr:
        lines.append("")
        lines.append("By HDR:")
        total = sum(stats.by_hdr.values())
        for k in sorted(stats.by_hdr):
            pct = stats.by_hdr[k] / total * 100
            lines.append(f"  {k}: {stats.by_hdr[k]} ({pct:.1f}%)")

    if stats.by_resolution_tier:
        lines.append("")
        lines.append("By resolution:")
        total = sum(stats.by_resolution_tier.values())
        for k in sorted(stats.by_resolution_tier):
            pct = stats.by_resolution_tier[k] / total * 100
            lines.append(f"  {k}: {stats.by_resolution_tier[k]} ({pct:.1f}%)")

    if stats.by_container:
        lines.append("")
        lines.append("By container:")
        total = sum(stats.by_container.values())
        for k in sorted(stats.by_container):
            pct = stats.by_container[k] / total * 100
            lines.append(f"  {k}: {stats.by_container[k]} ({pct:.1f}%)")

    if stats.largest:
        lines.append("")
        lines.append("Largest:")
        for fn, sz, br in stats.largest:
            bit = f", {br} Mbps" if br else ""
            lines.append(f"  {fn} — {sz}{bit}")

    return "\n".join(lines)


# ── Output generators ──

_FIELD_VALUE_MAP: dict[str, str] = {c: c for c in _COLUMNS}
_FIELD_VALUE_MAP.update({
    "Title": "title", "Year": "year",
    "Dir": "dir_rel", "Filename": "filename",
    "Resolution": "resolution", "Coded_Res": "coded_res",
    "DAR": "dar", "PAR": "par",
    "Codec": "codec", "Profile": "profile", "Level": "level",
    "Pixel_Format": "pix_fmt", "Bit_Depth": "bit_depth",
    "Color_Range": "color_range", "Color_Space": "color_space",
    "Color_Transfer": "color_transfer", "Color_Primaries": "color_primaries",
    "HDR": "hdr",
    "Bitrate": "bitrate", "Max_Bitrate": "max_bitrate",
    "FPS": "fps", "Frames": "frames", "Scan_Type": "scan_type",
    "Ref_Frames": "ref_frames",
    "Audio_Codec": "audio_codec", "Audio_Channels": "audio_channels",
    "Audio_Layout": "audio_layout", "Audio_Rate": "audio_rate",
    "Audio_Bitrate": "audio_bitrate", "Audio_Streams": "audio_streams",
    "Container": "container", "Extension": "extension",
    "Size": "size", "Runtime": "runtime",
    "Total_Streams": "total_streams", "Sub_Streams": "sub_streams",
    "Sub_Languages": "sub_languages",
})


def _field_value(info: ScannerInfo, col: str) -> str:
    attr = _FIELD_VALUE_MAP.get(col)
    if attr:
        return getattr(info, attr, "")
    return ""


def _all_numbered(files: list[ScannerInfo]) -> bool:
    return bool(files) and all(f.num for f in files)


def _sanitize(val: str) -> str:
    return val.replace("|", "\\|")


def generate_table(files: list[ScannerInfo], *, numbered: bool = False) -> str:
    cols = _COLUMNS
    lines: list[str] = []
    header = "| " + ("# | " if numbered else "")
    header += " | ".join(cols) + " |"
    lines.append(header)
    sep = "| " + ("--- | " if numbered else "")
    sep += " | ".join("---" for _ in cols) + " |"
    lines.append(sep)
    for f in files:
        row = "| " + (f"{f.num} | " if numbered else "")
        row += " | ".join(_sanitize(_field_value(f, c)) for c in cols) + " |"
        lines.append(row)
    return "\n".join(lines)


def _report_body(groups: list[tuple[Path, list[ScannerInfo]]], root: Path) -> str:
    parts: list[str] = []
    for dir_path, files in groups:
        rel = str(dir_path.relative_to(root)) if dir_path != root else ""
        numbered = _all_numbered(files)
        if rel:
            depth = len(Path(rel).parts) + 1
            heading = "#" * depth
            parts.append(f"{heading} {rel}/")
            parts.append("")
        elif len(groups) > 1:
            continue
        parts.append(generate_table(files, numbered=numbered))
        parts.append("")
    return "\n".join(parts)


def generate_report(root: str, groups: list[tuple[Path, list[ScannerInfo]]]) -> str:
    root_path = Path(root).resolve()
    root_name = root_path.name
    timestamp = datetime.now(timezone.utc).isoformat()
    parts: list[str] = [
        f"# {root_name}",
        f'generated: "{timestamp}"',
        f'source: "{root}"',
        "",
    ]
    body = _report_body(groups, root_path)
    if body:
        parts.append(body)
    return "\n".join(parts)


def generate_json(groups: list[tuple[Path, list[ScannerInfo]]]) -> str:
    result: list[dict] = []
    for _dir_path, files in groups:
        for f in files:
            d = asdict(f)
            d.pop("_width", None)
            d.pop("_height", None)
            d.pop("_size_bytes", None)
            d.pop("_bitrate_bps", None)
            d.pop("_duration_secs", None)
            result.append(d)
    return json.dumps(result, indent=2)


def generate_csv(files: list[ScannerInfo]) -> str:
    cols = _COLUMNS
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(cols)
    for f in files:
        writer.writerow([_field_value(f, c) for c in cols])
    return output.getvalue()
