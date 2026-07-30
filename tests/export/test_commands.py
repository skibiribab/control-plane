from __future__ import annotations

import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

from typer.testing import CliRunner

from src.cli import app

runner = CliRunner()


def _touch(path: str) -> Path:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text("")
    return p


class TestExportRepoCli:
    def test_no_args(self) -> None:
        result = runner.invoke(app, ["export"])
        assert result.exit_code != 0

    def test_nonexistent_path(self) -> None:
        result = runner.invoke(app, ["export", "repo", "/nonexistent"])
        assert result.exit_code != 0

    @patch("src.commands.export_cmd.export_repo_zip")
    def test_default_path(self, mock_export: MagicMock) -> None:
        p = _touch(tempfile.mktemp(suffix=".zip"))
        mock_export.return_value = p
        result = runner.invoke(app, ["export", "repo", ".", "--yes"])
        assert result.exit_code == 0, result.stdout
        mock_export.assert_called_once()

    @patch("src.commands.export_cmd.export_repo_zip")
    def test_with_password(self, mock_export: MagicMock) -> None:
        p = _touch(tempfile.mktemp(suffix=".zip"))
        mock_export.return_value = p
        result = runner.invoke(app, [
            "export", "repo", ".", "--password", "secret", "--yes",
        ])
        assert result.exit_code == 0, result.stdout
        kwargs = mock_export.call_args[1]
        assert kwargs.get("password") == "secret"

    @patch("src.commands.export_cmd.export_repo_zip")
    def test_with_lfs(self, mock_export: MagicMock) -> None:
        p = _touch(tempfile.mktemp(suffix=".zip"))
        mock_export.return_value = p
        result = runner.invoke(app, [
            "export", "repo", ".", "--lfs", "--yes",
        ])
        assert result.exit_code == 0, result.stdout
        kwargs = mock_export.call_args[1]
        assert kwargs.get("lfs") is True

    @patch("src.commands.export_cmd.export_repo_zip")
    def test_include_git(self, mock_export: MagicMock) -> None:
        p = _touch(tempfile.mktemp(suffix=".zip"))
        mock_export.return_value = p
        result = runner.invoke(app, [
            "export", "repo", ".", "--include-git", "--yes",
        ])
        assert result.exit_code == 0, result.stdout
        kwargs = mock_export.call_args[1]
        assert kwargs.get("include_git") is True

    @patch("src.commands.export_cmd.export_repo_zip")
    def test_custom_output(self, mock_export: MagicMock) -> None:
        p = _touch(tempfile.mktemp(suffix=".zip"))
        mock_export.return_value = p
        result = runner.invoke(app, [
            "export", "repo", ".", "-o", str(p), "--yes",
        ])
        assert result.exit_code == 0, result.stdout
        args, kwargs = mock_export.call_args
        # output_path is 2nd positional arg (repo_path, output_path, ...)
        assert str(p) == args[1]

    @patch("src.commands.export_cmd.export_repo_zip")
    def test_all_options(self, mock_export: MagicMock) -> None:
        p = _touch(tempfile.mktemp(suffix=".zip"))
        mock_export.return_value = p
        result = runner.invoke(app, [
            "export", "repo", ".",
            "--password", "secret",
            "--lfs",
            "--include-git",
            "-o", str(p),
            "--yes",
        ])
        assert result.exit_code == 0, result.stdout
        kwargs = mock_export.call_args[1]
        assert kwargs.get("password") == "secret"
        assert kwargs.get("lfs") is True
        assert kwargs.get("include_git") is True

    @patch("src.commands.export_cmd.export_repo_zip")
    def test_error_handling(self, mock_export: MagicMock) -> None:
        mock_export.side_effect = RuntimeError("git error")
        result = runner.invoke(app, [
            "export", "repo", ".", "--yes",
        ])
        assert result.exit_code != 0
        assert "git error" in result.stdout
