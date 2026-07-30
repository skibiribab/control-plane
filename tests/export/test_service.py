from __future__ import annotations

import os
import subprocess
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from src.services.backup_zip import (
    _find_lfs_object,
    _is_lfs_pointer,
    _parse_lfs_oid,
    _timestamp,
    export_repo_zip,
)

LFS_POINTER = (
    b"version https://git-lfs.github.com/spec/v1\n"
    b"oid sha256:abc123def456\n"
    b"size 42\n"
)

NOT_LFS = b"hello world\n"


class TestLfsPointer:
    def test_is_pointer_true(self) -> None:
        assert _is_lfs_pointer(LFS_POINTER) is True

    def test_is_pointer_false(self) -> None:
        assert _is_lfs_pointer(NOT_LFS) is False

    def test_is_pointer_empty(self) -> None:
        assert _is_lfs_pointer(b"") is False

    def test_parse_oid(self) -> None:
        assert _parse_lfs_oid(LFS_POINTER) == "abc123def456"

    def test_parse_oid_not_pointer(self) -> None:
        assert _parse_lfs_oid(NOT_LFS) is None

    def test_parse_oid_empty(self) -> None:
        assert _parse_lfs_oid(b"") is None


class TestFindLfsObject:
    def test_found(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            obj_dir = Path(tmp) / ".git" / "lfs" / "objects" / "ab" / "c1"
            obj_dir.mkdir(parents=True)
            obj_file = obj_dir / "abc123"
            obj_file.write_bytes(b"real content")
            result = _find_lfs_object(tmp, "abc123")
            assert result == b"real content"

    def test_not_found(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = _find_lfs_object(tmp, "nonexistent")
            assert result is None

    def test_no_lfs_dir(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = _find_lfs_object(tmp, "oid")
            assert result is None


class TestTimestamp:
    def test_format(self) -> None:
        ts = _timestamp()
        parts = ts.split("-")
        assert len(parts) == 6
        assert len(parts[0]) == 4  # year


class TestExportRepoZip:
    @patch("src.services.backup_zip.subprocess.run")
    @patch("src.services.backup_zip.os.replace")
    def test_plain(self, mock_replace: MagicMock, mock_run: MagicMock) -> None:
        mock_run.return_value = MagicMock(returncode=0)
        output = str(Path(tempfile.mkdtemp()) / "out.zip")
        with tempfile.TemporaryDirectory() as repo:
            result = export_repo_zip(repo, output)
            assert result == Path(output)
            # git archive called
            git_calls = [
                c for c in mock_run.call_args_list
                if "git" in str(c)
            ]
            assert any("archive" in str(c) for c in git_calls)

    @patch("src.services.backup_zip.subprocess.run")
    def test_with_password(self, mock_run: MagicMock) -> None:
        mock_run.return_value = MagicMock(returncode=0)
        with tempfile.TemporaryDirectory() as tmp:
            output = str(Path(tmp) / "out.zip")
            repo = tempfile.mkdtemp()
            result = export_repo_zip(repo, output, password="secret")
            assert result == Path(output)
            # zip with --password called
            zip_calls = [
                c for c in mock_run.call_args_list
                if "zip" in str(c[0][0][0]) and "--password" in str(c[0][0])
            ]
            assert len(zip_calls) >= 1

    @patch("src.services.backup_zip.subprocess.run")
    def test_with_lfs_flag(self, mock_run: MagicMock) -> None:
        def mock_side_effect(cmd, **kw):
            if cmd[0] == "tar" and cmd[1] == "-xf":
                # Create a test file in the extract dir
                extract_idx = cmd.index("-C") + 1
                extract_dir = Path(cmd[extract_idx])
                extract_dir.mkdir(parents=True, exist_ok=True)
                (extract_dir / "README.md").write_text("hello")
            return MagicMock(returncode=0, stdout=b"", stderr=b"")

        mock_run.side_effect = mock_side_effect
        with tempfile.TemporaryDirectory() as tmp:
            output = str(Path(tmp) / "out.zip")
            repo = tempfile.mkdtemp()
            # Create .git dir so it looks like a repo
            Path(repo, ".git").mkdir(parents=True)
            result = export_repo_zip(repo, output, lfs=True)
            assert result == Path(output)

    @patch("src.services.backup_zip.subprocess.run")
    def test_include_git(self, mock_run: MagicMock) -> None:
        def mock_side_effect(cmd, **kw):
            if cmd[0] == "unzip" and cmd[1] == "-o":
                extract_idx = cmd.index("-d") + 1
                extract_dir = Path(cmd[extract_idx])
                extract_dir.mkdir(parents=True, exist_ok=True)
                (extract_dir / "README.md").write_text("hello")
            return MagicMock(returncode=0, stdout=b"", stderr=b"")

        mock_run.side_effect = mock_side_effect
        with tempfile.TemporaryDirectory() as tmp:
            output = str(Path(tmp) / "out.zip")
            repo = tempfile.mkdtemp()
            Path(repo, ".git").mkdir(parents=True)
            result = export_repo_zip(repo, output, include_git=True)
            assert result == Path(output)
