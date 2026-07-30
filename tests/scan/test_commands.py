from __future__ import annotations

from pathlib import Path
from unittest.mock import MagicMock, patch

from typer.testing import CliRunner

from src.cli import app
from src.services.scanner import ScannerInfo

runner = CliRunner()


class TestScanVideoCli:
    def test_missing_path(self) -> None:
        result = runner.invoke(app, ["scan", "video"])
        assert result.exit_code != 0

    def test_nonexistent_path(self) -> None:
        result = runner.invoke(app, ["scan", "video", "/nonexistent"])
        assert result.exit_code != 0

    @patch("src.commands.scan.ffmpeg_available", return_value=False)
    def test_ffmpeg_not_found(self, _avail: MagicMock) -> None:
        result = runner.invoke(app, ["scan", "video", "."])
        assert result.exit_code != 0
        assert "ffmpeg" in result.stdout.lower()

    @patch("src.commands.scan.ffmpeg_available", return_value=True)
    @patch("src.commands.scan.scan_directory")
    def test_happy_path_stdout(self, mock_scan: MagicMock, _avail: MagicMock) -> None:
        info = ScannerInfo(filename="test.mkv", codec="h264", resolution="1920x1080")
        mock_scan.return_value = [(Path(".").resolve(), [info])]
        result = runner.invoke(app, ["scan", "video", "."])
        assert result.exit_code == 0, result.stdout
        assert "test.mkv" in result.stdout
        assert "h264" in result.stdout
        assert "generated:" in result.stdout

    @patch("src.commands.scan.ffmpeg_available", return_value=True)
    @patch("src.commands.scan.scan_directory")
    def test_output_file(self, mock_scan: MagicMock, _avail: MagicMock) -> None:
        info = ScannerInfo(filename="test.mkv")
        mock_scan.return_value = [(Path(".").resolve(), [info])]
        out = Path("/tmp/test_scan_output.md")
        try:
            result = runner.invoke(app, ["scan", "video", ".", "-o", str(out)])
            assert result.exit_code == 0, result.stdout
            assert out.exists()
            assert "test.mkv" in out.read_text()
        finally:
            if out.exists():
                out.unlink()

    @patch("src.commands.scan.ffmpeg_available", return_value=True)
    @patch("src.commands.scan.scan_directory_flat")
    @patch("src.commands.scan.scan_directory")
    def test_flat_mode(
        self, mock_tree: MagicMock, mock_flat: MagicMock, _avail: MagicMock,
    ) -> None:
        info = ScannerInfo(filename="test.mkv")
        mock_flat.return_value = [info]
        result = runner.invoke(app, ["scan", "video", ".", "--flat"])
        assert result.exit_code == 0
        mock_flat.assert_called_once()

    @patch("src.commands.scan.ffmpeg_available", return_value=True)
    @patch("src.commands.scan.scan_directory")
    def test_filter_cli(self, mock_scan: MagicMock, _avail: MagicMock) -> None:
        info = ScannerInfo(filename="test.mkv", codec="h264")
        mock_scan.return_value = [(Path(".").resolve(), [info])]
        result = runner.invoke(app, [
            "scan", "video", ".", "--filter", "codec=h264",
        ])
        assert result.exit_code == 0

    @patch("src.commands.scan.ffmpeg_available", return_value=True)
    @patch("src.commands.scan.scan_directory")
    def test_exclude_cli(self, mock_scan: MagicMock, _avail: MagicMock) -> None:
        info = ScannerInfo(filename="test-compressed.mp4")
        mock_scan.return_value = [(Path(".").resolve(), [info])]
        result = runner.invoke(app, [
            "scan", "video", ".", "--exclude", "*-compressed.mp4",
        ])
        assert result.exit_code == 0
        assert "test-compressed" not in result.stdout

    @patch("src.commands.scan.ffmpeg_available", return_value=True)
    @patch("src.commands.scan.scan_directory")
    def test_stats_flag(self, mock_scan: MagicMock, _avail: MagicMock) -> None:
        info = ScannerInfo(
            filename="test.mkv", codec="h264", _height=1080,
            _size_bytes=1_000_000_000, _duration_secs=3600,
        )
        mock_scan.return_value = [(Path(".").resolve(), [info])]
        result = runner.invoke(app, ["scan", "video", ".", "--stats"])
        assert result.exit_code == 0
        assert "Files:" in result.stdout
        assert "By codec:" in result.stdout

    @patch("src.commands.scan.ffmpeg_available", return_value=True)
    @patch("src.commands.scan.scan_directory")
    def test_csv_format(self, mock_scan: MagicMock, _avail: MagicMock) -> None:
        info = ScannerInfo(filename="test.mkv", codec="h264")
        mock_scan.return_value = [(Path(".").resolve(), [info])]
        result = runner.invoke(app, ["scan", "video", ".", "--format", "csv"])
        assert result.exit_code == 0
        assert "Codec" in result.stdout  # header
        assert "h264" in result.stdout

    @patch("src.commands.scan.ffmpeg_available", return_value=True)
    @patch("src.commands.scan.scan_directory")
    def test_json_format(self, mock_scan: MagicMock, _avail: MagicMock) -> None:
        info = ScannerInfo(filename="test.mkv", codec="h264")
        mock_scan.return_value = [(Path(".").resolve(), [info])]
        result = runner.invoke(app, ["scan", "video", ".", "--format", "json"])
        assert result.exit_code == 0
        assert '"filename": "test.mkv"' in result.stdout
