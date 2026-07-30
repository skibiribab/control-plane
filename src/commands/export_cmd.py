from __future__ import annotations

import os
from datetime import datetime, timezone
from pathlib import Path

import typer
from rich import print as rprint

from src.internal.write.gate import require_write_gate
from src.services.backup_zip import export_repo_zip

export_app = typer.Typer(
    help="Export git repositories as zip archives.",
    no_args_is_help=True,
)


@export_app.command("repo")
def repo_cmd(
    path: Path = typer.Argument(
        ".",
        exists=True,
        file_okay=False,
        dir_okay=True,
        resolve_path=True,
        help="Git repository path (default: current dir).",
    ),
    output: Path | None = typer.Option(
        None,
        "--output",
        "-o",
        help="Output zip path. Default: {dir}-{timestamp}.zip",
    ),
    password: str | None = typer.Option(
        None,
        "--password",
        "-p",
        envvar="ZIP_PASSWORD",
        help="Password-protect the zip. Falls back to ZIP_PASSWORD env var.",
    ),
    lfs: bool = typer.Option(
        False,
        "--lfs",
        help="Include actual LFS file contents (not just pointer files).",
    ),
    include_git: bool = typer.Option(
        False,
        "--include-git",
        help="Include .git directory in the archive.",
    ),
    yes: bool = typer.Option(
        False,
        "--yes",
        "-y",
        help="Skip confirmation.",
    ),
) -> None:
    root = str(path)

    if output is None:
        ts = datetime.now(timezone.utc).strftime("%Y-%m-%d-%H-%M-%S")
        output = path / f"private-{ts}.zip"

    mode = "lfs" if lfs else "git archive"
    if password:
        mode += " + encrypted"

    extra: list[str] = [
        f"repository: {root}",
        f"mode: {mode}",
        f"lfs content: {'yes' if lfs else 'no'}",
        f"include .git: {'yes' if include_git else 'no'}",
    ]

    require_write_gate(
        "export-repo",
        summary_lines=[f"source: {path}", f"output: {output}"],
        question="Export repository?",
        yes=yes,
        extra_lines=extra,
    )

    try:
        out = export_repo_zip(
            root, str(output),
            password=password,
            lfs=lfs,
            include_git=include_git,
        )
        size = _fmt_size(os.path.getsize(str(out)))
        rprint(f"[green]ok[/green] {out} ({size})")
    except RuntimeError as exc:
        rprint(f"[red]failed[/red] {exc}")
        raise typer.Exit(1) from exc
    except FileNotFoundError:
        rprint("[red]not a git repository or git not found[/red]")
        raise typer.Exit(1) from None


def _fmt_size(bytes_val: int) -> str:
    for unit, divisor in [("GiB", 1024**3), ("MiB", 1024**2), ("KiB", 1024)]:
        if bytes_val >= divisor:
            val = bytes_val / divisor
            if val >= 1:
                return f"{val:.2f}{unit}"
    return f"{bytes_val}B"
