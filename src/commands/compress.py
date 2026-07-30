from __future__ import annotations

from pathlib import Path

import typer
from rich import print as rprint

from src.internal.write.gate import require_write_gate
from src.services.compress import (
    FfmpegError,
    compress,
    ffmpeg_available,
    get_media_info,
    is_hdr,
)
from src.services.scanner import apply_exclude, apply_filters, scan_directory_flat

compress_app = typer.Typer(
    help="Compress media files (video, audio).",
    no_args_is_help=True,
)


def _require_ffmpeg() -> None:
    if not ffmpeg_available():
        raise typer.Exit("ffmpeg and ffprobe are required but not on PATH")


@compress_app.command("video")
def video_cmd(
    input: Path = typer.Argument(
        ...,
        exists=True,
        file_okay=True,
        dir_okay=False,
        readable=True,
        resolve_path=True,
        help="Input video file.",
    ),
    output: Path | None = typer.Option(
        None,
        "--output",
        "-o",
        help="Output path. Default: {input}-compressed.mp4",
    ),
    resolution: int | None = typer.Option(
        None,
        "--resolution",
        "-R",
        help="Target height (e.g. 720, 1080). Default: auto.",
    ),
    crf: int | None = typer.Option(
        None,
        "--crf",
        "-q",
        min=0,
        max=51,
        help="CRF 0-51 (lower = better quality). Default: 24 (h.265) / 22 (h.264).",
    ),
    bitrate: int | None = typer.Option(
        None,
        "--bitrate",
        "-b",
        help="Target bitrate in kbps. Switches to 2-pass VBR mode.",
    ),
    max_bitrate: int | None = typer.Option(
        None,
        "--max-bitrate",
        "-m",
        help="Max bitrate cap in kbps. Default: 2x target.",
    ),
    tonemap: str = typer.Option(
        "auto",
        "--tonemap",
        help="HDR to SDR tonemapping: auto, never, force.",
    ),
    max_fps: int = typer.Option(
        60,
        "--max-fps",
        help="Cap frame rate. 0 = keep original.",
    ),
    preset: str = typer.Option(
        "slow",
        "--preset",
        help="Encoding preset (ultrafast..veryslow).",
    ),
    codec: str = typer.Option(
        "auto",
        "--codec",
        "-c",
        help="Codec: auto, h265, h264.",
    ),
    pix_fmt: str = typer.Option(
        "yuv420p10le",
        "--pix-fmt",
        help="Pixel format. yuv420p10le=10-bit, yuv420p=8-bit.",
    ),
    tune_grain: bool = typer.Option(
        False,
        "--tune-grain",
        help="Film grain preservation mode.",
    ),
    audio_bitrate: str = typer.Option(
        "128k",
        "--audio-bitrate",
        "-a",
        help="Audio bitrate (e.g. 96k, 128k, copy).",
    ),
    audio_channels: int | None = typer.Option(
        None,
        "--audio-channels",
        help="Audio channels (2 = stereo downmix). Default: auto (2 if input >2).",
    ),
    crop: bool = typer.Option(
        True,
        "--crop/--no-crop",
        help="Auto-detect and crop black bars.",
    ),
    denoise: bool = typer.Option(
        False,
        "--denoise",
        help="Light denoising (hqdn3d) for better compression.",
    ),
    strip_meta: bool = typer.Option(
        True,
        "--strip-meta/--keep-meta",
        help="Strip metadata and chapters.",
    ),
    attempts: int = typer.Option(
        3,
        "--attempts",
        "-n",
        help="VBR mode: max compression attempts with decreasing bitrate.",
    ),
    step: int | None = typer.Option(
        None,
        "--step",
        help="VBR mode: bitrate reduction per attempt (kbps). Default: auto (~20%).",
    ),
    yes: bool = typer.Option(
        False,
        "--yes",
        "-y",
        help="Skip confirmation.",
    ),
) -> None:
    _require_ffmpeg()

    info = get_media_info(str(input))

    if output is None:
        output = input.with_name(f"{input.stem}-compressed.mp4")

    hdr_tag = "HDR " if is_hdr(info) else ""
    rprint(f"[bold]=== {input.name} ===[/bold]")
    rprint(
        f"[dim]→[/dim] {info.width}x{info.height} @ {info.bit_rate // 1000}k, "
        f"{info.fps:.2f}fps, {info.codec_name}"
        f"{' (' + hdr_tag + ')' if hdr_tag else ''}"
    )
    rprint(f"[dim]→[/dim] output: [bold]{output.name}[/bold]")

    extra = [
        f"target resolution: {resolution or 'auto'}",
        f"hdr: {'yes → SDR' if hdr_tag else 'no'}",
        f"bitrate: {info.bit_rate // 1000}k → {bitrate or 'auto'}k",
        f"mode: {'VBR 2-pass' if bitrate else 'CRF + VBV'}, "
        f"preset: {preset}, pix_fmt: {pix_fmt}",
    ]

    require_write_gate(
        "compress-video",
        summary_lines=[f"input: {input}", f"output: {output}"],
        question="Compress video?",
        yes=yes,
        extra_lines=extra,
    )

    codec_map = {"h265": "libx265", "h264": "libx264"}
    resolved_codec = codec_map.get(codec, codec)

    try:
        out = compress(
            str(input),
            str(output),
            scale_height=resolution,
            crf=crf,
            bitrate_k=bitrate,
            max_bitrate_k=max_bitrate,
            tonemap=tonemap,
            max_fps=max_fps,
            preset=preset,
            codec=resolved_codec,
            pix_fmt=pix_fmt,
            tune_grain=tune_grain,
            audio_bitrate=audio_bitrate,
            audio_channels=audio_channels,
            crop=crop,
            denoise=denoise,
            strip_meta=strip_meta,
            attempts=attempts,
            step_k=step,
        )
        rprint(f"[green]ok[/green] {out}")
    except FfmpegError as exc:
        rprint(f"[red]encoding failed[/red] {exc.stderr}")
        raise typer.Exit(1) from exc
    except FileNotFoundError:
        rprint(f"[red]file not found[/red] {input}")
        raise typer.Exit(1) from None


@compress_app.command("batch")
def batch_cmd(
    path: Path = typer.Argument(
        ...,
        exists=True,
        file_okay=False,
        dir_okay=True,
        resolve_path=True,
        help="Directory with video files to batch compress.",
    ),
    output_dir: Path | None = typer.Option(
        None,
        "--output-dir",
        "-O",
        help="Output directory. Default: same dir, files get '-compressed' suffix.",
    ),
    filter: list[str] = typer.Option(
        None,
        "--filter",
        help="Only compress matching files, e.g. --filter 'codec=h264'.",
    ),
    exclude: list[str] = typer.Option(
        None,
        "--exclude",
        help="Exclude files by glob, e.g. --exclude '*-compressed.mp4'.",
    ),
    dry_run: bool = typer.Option(
        False,
        "--dry-run",
        help="Show what would be compressed, do nothing.",
    ),
    resolution: int | None = typer.Option(
        None, "--resolution", "-R",
        help="Target height (e.g. 720, 1080). Default: auto.",
    ),
    crf: int | None = typer.Option(
        None, "--crf", "-q", min=0, max=51,
        help="CRF 0-51 (lower = better). Default: 24 (h.265) / 22 (h.264).",
    ),
    bitrate: int | None = typer.Option(
        None, "--bitrate", "-b",
        help="Target bitrate in kbps. Switches to 2-pass VBR mode.",
    ),
    max_bitrate: int | None = typer.Option(
        None, "--max-bitrate", "-m",
        help="Max bitrate cap in kbps. Default: 2x target.",
    ),
    tonemap: str = typer.Option(
        "auto", "--tonemap",
        help="HDR to SDR tonemapping: auto, never, force.",
    ),
    max_fps: int = typer.Option(
        60, "--max-fps",
        help="Cap frame rate. 0 = keep original.",
    ),
    preset: str = typer.Option(
        "slow", "--preset",
        help="Encoding preset (ultrafast..veryslow).",
    ),
    codec: str = typer.Option(
        "auto", "--codec", "-c",
        help="Codec: auto, h265, h264.",
    ),
    pix_fmt: str = typer.Option(
        "yuv420p10le", "--pix-fmt",
        help="Pixel format. yuv420p10le=10-bit, yuv420p=8-bit.",
    ),
    tune_grain: bool = typer.Option(
        False, "--tune-grain",
        help="Film grain preservation mode.",
    ),
    audio_bitrate: str = typer.Option(
        "128k", "--audio-bitrate", "-a",
        help="Audio bitrate (e.g. 96k, 128k, copy).",
    ),
    audio_channels: int | None = typer.Option(
        None, "--audio-channels",
        help="Audio channels (2 = stereo downmix). Default: auto (2 if input >2).",
    ),
    crop: bool = typer.Option(
        True, "--crop/--no-crop",
        help="Auto-detect and crop black bars.",
    ),
    denoise: bool = typer.Option(
        False, "--denoise",
        help="Light denoising (hqdn3d) for better compression.",
    ),
    strip_meta: bool = typer.Option(
        True, "--strip-meta/--keep-meta",
        help="Strip metadata and chapters.",
    ),
    attempts: int = typer.Option(
        3, "--attempts", "-n",
        help="VBR mode: max compression attempts with decreasing bitrate.",
    ),
    step: int | None = typer.Option(
        None, "--step",
        help="VBR mode: bitrate reduction per attempt (kbps). Default: auto (~20%).",
    ),
    yes: bool = typer.Option(
        False, "--yes", "-y",
        help="Skip confirmation.",
    ),
) -> None:
    _require_ffmpeg()

    root = str(path)
    files = scan_directory_flat(root)
    files = apply_exclude(apply_filters(files, filter), exclude)

    if not files:
        rprint("[yellow]no matching files[/yellow]")
        raise typer.Exit(1)

    if dry_run:
        rprint(f"[bold]Would compress {len(files)} file(s):[/bold]")
        for f in files:
            rprint(f"  {f.filename} ({f.resolution}, {f.bitrate} Mbps, {f.codec})")
        return

    rprint(f"[bold]Compressing {len(files)} file(s)[/bold]")
    for f in files[:5]:
        rprint(f"  {f.filename}")
    if len(files) > 5:
        rprint(f"  ... and {len(files) - 5} more")

    require_write_gate(
        "compress-batch",
        summary_lines=[f"directory: {path}", f"files: {len(files)}"],
        question="Batch compress?",
        yes=yes,
        extra_lines=[
            f"output dir: {output_dir or 'same dir (-compressed suffix)'}",
            f"filter: {filter or 'none'}",
            f"exclude: {exclude or 'none'}",
        ],
    )

    codec_map = {"h265": "libx265", "h264": "libx264"}
    resolved_codec = codec_map.get(codec, codec)

    success = 0
    failed = 0
    for f in files:
        input_path = Path(root) / f.dir_rel / f.filename if f.dir_rel else Path(root) / f.filename
        if output_dir:
            output_dir.mkdir(parents=True, exist_ok=True)
            out_path = output_dir / f.filename
            ext = Path(out_path).suffix
            stem = Path(out_path).stem
            out_path = out_path.with_stem(f"{stem}-compressed")
        else:
            out_path = input_path.with_name(f"{input_path.stem}-compressed.mp4")

        rprint(f"\n[dim]=== {f.filename} ===[/dim]")
        try:
            compress(
                str(input_path), str(out_path),
                scale_height=resolution,
                crf=crf,
                bitrate_k=bitrate,
                max_bitrate_k=max_bitrate,
                tonemap=tonemap,
                max_fps=max_fps,
                preset=preset,
                codec=resolved_codec,
                pix_fmt=pix_fmt,
                tune_grain=tune_grain,
                audio_bitrate=audio_bitrate,
                audio_channels=audio_channels,
                crop=crop,
                denoise=denoise,
                strip_meta=strip_meta,
                attempts=attempts,
                step_k=step,
            )
            rprint(f"[green]ok[/green] {out_path}")
            success += 1
        except FfmpegError as exc:
            rprint(f"[red]failed[/red] {exc.stderr}")
            failed += 1

    rprint(f"\n[bold]done[/bold] {success} ok, {failed} failed")
