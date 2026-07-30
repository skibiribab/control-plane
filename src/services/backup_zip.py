"""Create tag zips via git archive (plain) or password-protected zip (private repos)."""

from __future__ import annotations

import os
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from src.utils.process import run_git

LFS_HEADER = b"version https://git-lfs.github.com/spec/v1"


def _is_lfs_pointer(content: bytes) -> bool:
    return content.startswith(LFS_HEADER)


def _parse_lfs_oid(content: bytes) -> str | None:
    if not _is_lfs_pointer(content):
        return None
    for line in content.split(b"\n"):
        if line.startswith(b"oid sha256:"):
            return line[len(b"oid sha256:"):].strip().decode()
    return None


def _find_lfs_object(repo_path: str, oid: str) -> bytes | None:
    obj = Path(repo_path) / ".git" / "lfs" / "objects" / oid[:2] / oid[2:4] / oid
    if obj.is_file():
        return obj.read_bytes()
    return None


def _timestamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d-%H-%M-%S")


def export_repo_zip(
    repo_path: str,
    output_path: str,
    *,
    password: str | None = None,
    lfs: bool = False,
    include_git: bool = False,
) -> Path:
    repo_path = str(Path(repo_path).resolve())
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)

    if lfs:
        subprocess.run(
            ["git", "lfs", "fetch", "--all"],
            cwd=repo_path, capture_output=True, check=True,
        )
        with tempfile.TemporaryDirectory(prefix="cli-export-") as tmp:
            tmpdir = Path(tmp)
            archive_file = tmpdir / "repo.tar"
            subprocess.run(
                ["git", "archive", "--format=tar", "-o", str(archive_file), "HEAD"],
                cwd=repo_path, check=True,
            )
            extract_dir = tmpdir / "tree"
            extract_dir.mkdir()
            subprocess.run(
                ["tar", "-xf", str(archive_file), "-C", str(extract_dir)],
                check=True,
            )

            for root, _dirs, files in os.walk(str(extract_dir)):
                for fname in files:
                    fpath = Path(root) / fname
                    try:
                        raw = fpath.read_bytes()
                    except OSError:
                        continue
                    oid = _parse_lfs_oid(raw)
                    if oid:
                        real = _find_lfs_object(repo_path, oid)
                        if real:
                            fpath.write_bytes(real)

            if include_git:
                subprocess.run(
                    ["cp", "-a", os.path.join(repo_path, ".git"), str(extract_dir / ".git")],
                    check=True,
                )

            _zip_dir(str(extract_dir), str(output), password=password)
    else:
        with tempfile.TemporaryDirectory(prefix="cli-export-") as tmp:
            tmpdir = Path(tmp)
            archive_file = tmpdir / "repo.zip"
            subprocess.run(
                ["git", "archive", "--format=zip", f"--output={archive_file}", "HEAD"],
                cwd=repo_path, check=True,
            )

            if include_git:
                extract_dir = tmpdir / "tree"
                extract_dir.mkdir()
                subprocess.run(
                    ["unzip", "-o", str(archive_file), "-d", str(extract_dir)],
                    capture_output=True, check=True,
                )
                subprocess.run(
                    ["cp", "-a", os.path.join(repo_path, ".git"), str(extract_dir / ".git")],
                    check=True,
                )
                _zip_dir(str(extract_dir), str(output), password=password)
            elif password:
                subprocess.run(
                    ["zip", "--password", password, str(output), str(archive_file)],
                    check=True,
                )
            else:
                os.replace(str(archive_file), str(output))

    return output


def _zip_dir(source_dir: str, output_path: str, *, password: str | None = None) -> None:
    if password:
        subprocess.run(
            ["zip", "--password", password, "-r", output_path, "."],
            cwd=source_dir, check=True,
        )
    else:
        subprocess.run(
            ["zip", "-r", output_path, "."],
            cwd=source_dir, check=True,
        )


def archive_tag_zip(
    repo_path: Path,
    tag: str,
    output: Path,
    *,
    encrypted: bool,
    password: str | None = None,
) -> Path:
    """Archive a git tag to ``output`` (plain zip or AES zip when ``encrypted``)."""
    repo_path = repo_path.resolve()
    run_git(["rev-parse", "-q", "--verify", f"refs/tags/{tag}"], cwd=repo_path)
    output.parent.mkdir(parents=True, exist_ok=True)

    if not encrypted:
        run_git(
            ["archive", "--format=zip", f"--output={output}", tag],
            cwd=repo_path,
        )
        return output

    if not password:
        raise RuntimeError(
            "BACKUP_ZIP_PASSWORD is not set. Export a zip encryption password "
            "for encrypted backup repositories."
        )

    if output.is_file():
        output.unlink()

    with tempfile.TemporaryDirectory(prefix="cli-backup-") as tmp:
        tmp_path = Path(tmp)
        archive = subprocess.run(
            ["git", "archive", tag],
            cwd=repo_path,
            capture_output=True,
            check=True,
        )
        subprocess.run(
            ["tar", "-x", "-C", str(tmp_path)],
            input=archive.stdout,
            check=True,
        )
        result = subprocess.run(
            ["zip", "-er", "-P", password, str(output), "."],
            cwd=tmp_path,
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            msg = (result.stderr or result.stdout or "zip failed").strip()
            raise RuntimeError(f"encrypted zip failed: {msg}")

    return output
