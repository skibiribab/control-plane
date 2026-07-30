from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import tempfile
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path


@dataclass
class CropRect:
    w: int
    h: int
    x: int
    y: int


@dataclass
class MediaInfo:
    width: int = 0
    height: int = 0
    codec_name: str = ""
    bit_rate: int = 0
    duration: float = 0.0
    fps: float = 0.0
    color_transfer: str | None = None
    color_primaries: str | None = None
    color_space: str | None = None
    pix_fmt: str | None = None
    field_order: str | None = None
    audio_codec: str | None = None
    audio_channels: int | None = None
    audio_bit_rate: int | None = None


HDR_TRANSFERS = frozenset({"smpte2084", "arib-std-b67", "smpte428"})
HDR_PRIMARIES = frozenset({"bt2020"})

RESOLUTION_BITRATE_MAP: list[tuple[int, int]] = [
    (240, 200),
    (360, 400),
    (480, 600),
    (720, 1000),
    (1080, 1500),
    (1440, 3000),
    (2160, 6000),
]


class FfmpegError(RuntimeError):
    def __init__(self, cmd: Sequence[str], returncode: int, stderr: str) -> None:
        self.cmd = list(cmd)
        self.returncode = returncode
        self.stderr = stderr
        super().__init__(
            f"ffmpeg command failed ({returncode}): {' '.join(self.cmd)}\n{stderr}"
        )


def ffmpeg_available() -> bool:
    return shutil.which("ffmpeg") is not None and shutil.which("ffprobe") is not None


def ensure_ffmpeg() -> None:
    if not ffmpeg_available():
        raise RuntimeError("ffmpeg and ffprobe are required but not on PATH")


def run_ffmpeg(
    args: Sequence[str],
    *,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    ensure_ffmpeg()
    cmd = ["ffmpeg", *args]
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if check and result.returncode != 0:
        raise FfmpegError(cmd, result.returncode, result.stderr.strip())
    return result


def run_ffprobe(args: Sequence[str]) -> dict:
    ensure_ffmpeg()
    cmd = ["ffprobe", "-v", "error", "-of", "json", *args]
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise FfmpegError(cmd, result.returncode, result.stderr.strip())
    return json.loads(result.stdout)


def get_media_info(path: str | Path) -> MediaInfo:
    data = run_ffprobe([
        "-show_entries",
        "stream=width,height,codec_name,r_frame_rate,avg_frame_rate,pix_fmt,color_transfer,color_primaries,color_space,field_order:stream=index,codec_type,codec_name,channels,bit_rate:format=duration,bit_rate",
        str(path),
    ])
    return parse_ffprobe_output(data)


def parse_ffprobe_output(data: dict) -> MediaInfo:
    info = MediaInfo()
    video_stream: dict | None = None
    audio_stream: dict | None = None

    for s in data.get("streams", []):
        if s.get("codec_type") == "video" and video_stream is None:
            video_stream = s
        elif s.get("codec_type") == "audio" and audio_stream is None:
            audio_stream = s

    if video_stream:
        info.width = video_stream.get("width") or 0
        info.height = video_stream.get("height") or 0
        info.codec_name = video_stream.get("codec_name") or ""
        info.pix_fmt = video_stream.get("pix_fmt")
        info.color_transfer = video_stream.get("color_transfer")
        info.color_primaries = video_stream.get("color_primaries")
        info.color_space = video_stream.get("color_space")
        info.field_order = video_stream.get("field_order")

        r_frame = video_stream.get("r_frame_rate", "0/1")
        if "/" in r_frame:
            num, den = r_frame.split("/")
            try:
                info.fps = float(num) / float(den) if float(den) != 0 else 0.0
            except (ValueError, ZeroDivisionError):
                info.fps = 0.0

    if audio_stream:
        info.audio_codec = audio_stream.get("codec_name")
        info.audio_channels = audio_stream.get("channels")
        info.audio_bit_rate = audio_stream.get("bit_rate")

    fmt = data.get("format", {})
    info.duration = float(fmt.get("duration") or 0)
    info.bit_rate = int(fmt.get("bit_rate") or 0)

    return info


def is_hdr(info: MediaInfo) -> bool:
    if info.color_transfer in HDR_TRANSFERS:
        return True
    if info.color_primaries in HDR_PRIMARIES:
        return True
    return False


def detect_black_bars(path: str | Path, sample_secs: int = 10) -> CropRect | None:
    info = get_media_info(path)
    cmd = [
        "-t", str(sample_secs),
        "-i", str(path),
        "-vf", "cropdetect=round=2:skip=5",
        "-f", "null", "-",
    ]
    result = run_ffmpeg(cmd, check=False)
    if result.returncode != 0:
        return None

    best: tuple[int, int, int, int] | None = None
    for line in result.stderr.split("\n"):
        if m := re.search(r"crop=(\d+):(\d+):(-?\d+):(-?\d+)", line):
            best = (int(m[1]), int(m[2]), int(m[3]), int(m[4]))

    if best is None:
        return None
    w, h, x, y = best
    if w == info.width and h == info.height:
        return None
    return CropRect(w=w, h=h, x=x, y=y)


def compose_vf(
    info: MediaInfo,
    *,
    tonemap: str = "auto",
    scale_height: int | None = None,
    max_fps: int = 60,
    crop: CropRect | None = None,
    denoise: bool = False,
) -> str | None:
    filters: list[str] = []

    if info.field_order and info.field_order not in ("progressive", "unknown"):
        filters.append("yadif")

    apply_tonemap = tonemap == "force" or (tonemap == "auto" and is_hdr(info))
    if apply_tonemap:
        filters.append("tonemap=hable:desat=2")
        filters.append("zscale=t=bt709:m=bt709:r=tv")

    if crop:
        filters.append(f"crop={crop.w}:{crop.h}:{crop.x}:{crop.y}")

    if scale_height:
        filters.append(f"scale=-2:{scale_height}")

    if max_fps > 0 and info.fps > max_fps:
        filters.append(f"fps={max_fps}")

    if denoise:
        filters.append("hqdn3d=3:2:4:3")

    return ",".join(filters) if filters else None


def auto_resolution(info: MediaInfo) -> int:
    if info.height > 1080:
        return 1080
    if info.height > 720:
        return 720
    return info.height


def auto_crf(codec: str) -> int:
    if "264" in codec:
        return 22
    return 24


def auto_bitrate_k(target_height: int, *, original_bitrate: int = 0) -> int:
    result = 1500
    for h, br in RESOLUTION_BITRATE_MAP:
        if target_height <= h:
            result = br
            break

    if original_bitrate > 0:
        result = min(result, int(original_bitrate / 1000 * 0.6))

    return max(result, 200)


def auto_max_bitrate_k(target_bitrate_k: int) -> int:
    return target_bitrate_k * 2


def auto_step_k(bitrate_k: int) -> int:
    return max(200, int(bitrate_k * 0.2))


def resolve_codec(codec: str) -> str:
    if codec not in ("auto", "libx265", "libx264", "h265", "h264"):
        return codec
    if codec in ("libx265", "libx264"):
        return codec
    if codec == "h265":
        return "libx265"
    if codec == "h264":
        return "libx264"

    try:
        result = subprocess.run(
            ["ffmpeg", "-hide_banner", "-encoders"],
            capture_output=True, text=True, check=False,
        )
        if "libx265" in result.stdout:
            return "libx265"
    except OSError:
        pass
    return "libx264"


def _x265_params(preset: str, tune_grain: bool) -> str:
    params = (
        f"preset={preset}:aq-mode=3:no-sao=1:subme=5:rect=1:rc-lookahead=40"
    )
    if tune_grain:
        params += ":tune=grain:no-strong-intra-smoothing=1"
    return params


def _audio_args(
    info: MediaInfo,
    audio_bitrate: str,
    audio_channels: int | None,
) -> list[str]:
    if audio_bitrate == "copy":
        return ["-c:a", "copy"]

    args: list[str] = ["-c:a", "aac", "-b:a", audio_bitrate]

    if audio_channels is not None:
        args += ["-ac", str(audio_channels)]
    elif info.audio_channels and info.audio_channels > 2:
        args += ["-ac", "2"]

    return args


def encode_crf(
    input_path: str,
    output_path: str,
    *,
    vf: str | None,
    crf: int,
    maxrate_k: int,
    preset: str,
    codec: str,
    pix_fmt: str,
    audio_bitrate: str,
    audio_channels: int | None,
    tune_grain: bool,
    strip_meta: bool,
) -> int:
    info = get_media_info(input_path)
    x265p = _x265_params(preset, tune_grain)

    cmd: list[str] = ["-y", "-i", input_path]

    if vf:
        cmd += ["-vf", vf]

    cmd += [
        "-c:v", codec,
        "-crf", str(crf),
        "-maxrate", f"{maxrate_k}k",
        "-bufsize", f"{maxrate_k // 2}k",
        "-preset", preset,
        "-pix_fmt", pix_fmt,
        "-x265-params", x265p,
    ]

    cmd += _audio_args(info, audio_bitrate, audio_channels)

    if strip_meta:
        cmd += ["-map_metadata", "-1", "-map_chapters", "-1"]

    cmd += [str(output_path)]

    run_ffmpeg(cmd)

    return get_media_info(str(output_path)).bit_rate


def encode_vbr(
    input_path: str,
    output_path: str,
    *,
    vf: str | None,
    target_bitrate_k: int,
    maxrate_k: int,
    preset: str,
    codec: str,
    pix_fmt: str,
    audio_bitrate: str,
    audio_channels: int | None,
    tune_grain: bool,
    strip_meta: bool,
    passlogfile: str | None = None,
) -> int:
    info = get_media_info(input_path)
    x265p = _x265_params(preset, tune_grain)

    base: list[str] = ["-y", "-i", input_path]

    if vf:
        base += ["-vf", vf]

    if passlogfile:
        base += ["-passlogfile", passlogfile]

    base += [
        "-c:v", codec,
        "-b:v", f"{target_bitrate_k}k",
        "-maxrate", f"{maxrate_k}k",
        "-bufsize", f"{maxrate_k // 2}k",
        "-preset", preset,
        "-pix_fmt", pix_fmt,
        "-x265-params", x265p,
    ]

    run_ffmpeg([*base, "-pass", "1", "-an", "-f", "null", "/dev/null"])

    cmd2: list[str] = [
        *base, "-pass", "2",
        *_audio_args(info, audio_bitrate, audio_channels),
    ]

    if strip_meta:
        cmd2 += ["-map_metadata", "-1", "-map_chapters", "-1"]

    cmd2 += [str(output_path)]

    run_ffmpeg(cmd2)

    return get_media_info(str(output_path)).bit_rate


def compress(
    input_path: str,
    output_path: str,
    *,
    scale_height: int | None = None,
    crf: int | None = None,
    bitrate_k: int | None = None,
    max_bitrate_k: int | None = None,
    tonemap: str = "auto",
    max_fps: int = 60,
    preset: str = "slow",
    codec: str = "auto",
    pix_fmt: str = "yuv420p10le",
    tune_grain: bool = False,
    audio_bitrate: str = "128k",
    audio_channels: int | None = None,
    crop: bool = True,
    denoise: bool = False,
    strip_meta: bool = True,
    attempts: int = 3,
    step_k: int | None = None,
) -> Path:
    if not os.path.exists(input_path):
        raise FileNotFoundError(input_path)

    info = get_media_info(input_path)
    codec = resolve_codec(codec)

    if scale_height is None:
        scale_h = auto_resolution(info)
    else:
        scale_h = scale_height

    if scale_h >= info.height:
        scale_h = info.height

    crf_val = crf if crf is not None else auto_crf(codec)

    bars: CropRect | None = None
    if crop:
        bars = detect_black_bars(input_path)

    vf = compose_vf(
        info,
        tonemap=tonemap,
        scale_height=scale_h if scale_h != info.height else None,
        max_fps=max_fps,
        crop=bars,
        denoise=denoise,
    )

    if bitrate_k is not None:
        max_br = max_bitrate_k if max_bitrate_k is not None else auto_max_bitrate_k(bitrate_k)
        step = step_k if step_k is not None else auto_step_k(bitrate_k)
        tmp_dir = Path(tempfile.mkdtemp(prefix="cli-compress-"))
        try:
            current = input_path
            current_vf = vf

            for attempt in range(1, attempts + 1):
                target = max(bitrate_k - (attempt - 1) * step, 100)
                tmp_out = tmp_dir / f"pass_{attempt}.mp4"

                abr = audio_bitrate if attempt == 1 else "copy"

                encode_vbr(
                    current, str(tmp_out),
                    vf=current_vf,
                    target_bitrate_k=target,
                    maxrate_k=max_br,
                    preset=preset,
                    codec=codec,
                    pix_fmt=pix_fmt,
                    audio_bitrate=abr,
                    audio_channels=audio_channels,
                    tune_grain=tune_grain,
                    strip_meta=strip_meta,
                    passlogfile=str(tmp_dir / "pass"),
                )

                actual = get_media_info(str(tmp_out)).bit_rate
                if actual <= target * 1000:
                    shutil.move(str(tmp_out), output_path)
                    return Path(output_path)

                current = str(tmp_out)
                current_vf = None

            last = tmp_dir / f"pass_{attempts}.mp4"
            shutil.move(str(last), output_path)
            return Path(output_path)
        finally:
            shutil.rmtree(tmp_dir, ignore_errors=True)
    else:
        target_br = auto_bitrate_k(scale_h, original_bitrate=info.bit_rate)
        max_br = max_bitrate_k if max_bitrate_k is not None else auto_max_bitrate_k(target_br)

        encode_crf(
            input_path, output_path,
            vf=vf,
            crf=crf_val,
            maxrate_k=max_br,
            preset=preset,
            codec=codec,
            pix_fmt=pix_fmt,
            audio_bitrate=audio_bitrate,
            audio_channels=audio_channels,
            tune_grain=tune_grain,
            strip_meta=strip_meta,
        )

        return Path(output_path)
