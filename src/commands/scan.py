from __future__ import annotations

from pathlib import Path

import typer
from rich import print as rprint

from src.services.compress import ffmpeg_available
from src.services.scanner import (
    apply_exclude,
    apply_filters,
    compute_stats,
    format_stats_text,
    generate_csv,
    generate_json,
    generate_report,
    scan_directory,
    scan_directory_flat,
)

scan_app = typer.Typer(
    help="Scan media files and extract metadata.",
    no_args_is_help=True,
)


def _require_ffmpeg() -> None:
    if not ffmpeg_available():
        raise typer.Exit("ffmpeg and ffprobe are required but not on PATH")


@scan_app.command("video")
def video_cmd(
    path: Path = typer.Argument(
        ...,
        exists=True,
        file_okay=False,
        dir_okay=True,
        resolve_path=True,
        readable=True,
        help="Media directory to scan.",
    ),
    output: Path | None = typer.Option(
        None,
        "--output",
        "-o",
        help="Write report to file instead of stdout.",
    ),
    flat: bool = typer.Option(
        False,
        "--flat",
        "-F",
        help="Single flat table, no directory tree.",
    ),
    stats: bool = typer.Option(
        False,
        "--stats",
        "-s",
        help="Print summary statistics instead of full table.",
    ),
    fmt: str = typer.Option(
        "markdown",
        "--format",
        help="Output format: markdown (default), json, csv.",
    ),
    filter: list[str] = typer.Option(
        None,
        "--filter",
        help="Filter files by criteria, e.g. --filter 'codec=h264'. Can be repeated.",
    ),
    exclude: list[str] = typer.Option(
        None,
        "--exclude",
        help="Exclude files by glob pattern, e.g. --exclude '*-compressed.mp4'.",
    ),
) -> None:
    _require_ffmpeg()

    root = str(path)

    if flat:
        files = scan_directory_flat(root)
        files = apply_exclude(apply_filters(files, filter), exclude)
        groups: list[tuple[Path, list]] = [(path, files)]
    else:
        raw = scan_directory(root)
        groups = []
        for d, f in raw:
            f2 = apply_exclude(apply_filters(f, filter), exclude)
            if f2:
                groups.append((d, f2))

    if stats:
        all_files = [f for _, ff in groups for f in ff]
        stats_obj = compute_stats(all_files)
        text = format_stats_text(stats_obj)
        if output:
            output.write_text(text)
            rprint(f"[green]wrote[/green] {output}")
        else:
            typer.echo(text)
        return

    if fmt == "json":
        report = generate_json(groups)
    elif fmt == "csv":
        all_files = [f for _, ff in groups for f in ff]
        report = generate_csv(all_files)
    else:
        report = generate_report(root, groups)

    if output:
        output.write_text(report)
        rprint(f"[green]wrote[/green] {output}")
    else:
        typer.echo(report)
