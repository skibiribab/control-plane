from __future__ import annotations

from pathlib import Path
from unittest.mock import MagicMock, patch

from typer.testing import CliRunner

from src.cli import app
from src.services.compress import FfmpegError, MediaInfo
from src.services.scanner import ScannerInfo

runner = CliRunner()


def _make_info(**overrides: object) -> MediaInfo:
    defaults: dict[str, object] = {
        "width": 1920,
        "height": 1080,
        "codec_name": "h264",
        "bit_rate": 10_240_000,
        "duration": 120.0,
        "fps": 23.976,
        "color_transfer": "bt709",
        "color_primaries": "bt709",
        "pix_fmt": "yuv420p",
        "field_order": "progressive",
        "audio_codec": "aac",
        "audio_channels": 2,
        "audio_bit_rate": 128000,
        "color_space": None,
    }
    defaults.update(overrides)
    return MediaInfo(**defaults)  # type: ignore[arg-type]


class TestCompressVideoCli:
    def test_missing_input(self) -> None:
        result = runner.invoke(app, ["compress", "video"])
        assert result.exit_code != 0

    def test_nonexistent_input(self) -> None:
        result = runner.invoke(app, [
            "compress", "video", "/nonexistent/file.mp4",
        ])
        assert result.exit_code != 0

    @patch("src.commands.compress.ffmpeg_available", return_value=False)
    def test_ffmpeg_not_found(self, _avail: MagicMock) -> None:
        result = runner.invoke(app, [
            "compress", "video", __file__,
        ])
        assert result.exit_code != 0
        assert "ffmpeg" in result.stdout.lower()

    @patch("src.commands.compress.ffmpeg_available", return_value=True)
    @patch("src.commands.compress.get_media_info")
    @patch("src.commands.compress.is_hdr", return_value=False)
    @patch("src.commands.compress.compress")
    @patch("src.internal.write.gate.confirm_prompt", return_value=True)
    def test_happy_path_crf(
        self,
        _gate: MagicMock,
        mock_compress: MagicMock,
        _hdr: MagicMock,
        mock_info: MagicMock,
        _avail: MagicMock,
    ) -> None:
        mock_info.return_value = _make_info()
        mock_compress.return_value = Path("/out.mp4")

        result = runner.invoke(app, [
            "compress", "video", __file__,
            "--resolution", "720",
            "--crf", "26",
            "--preset", "slow",
            "--yes",
        ])
        assert result.exit_code == 0, result.stdout
        mock_compress.assert_called_once()
        kwargs = mock_compress.call_args[1]
        assert kwargs.get("scale_height") == 720
        assert kwargs.get("crf") == 26
        assert kwargs.get("preset") == "slow"

    @patch("src.commands.compress.ffmpeg_available", return_value=True)
    @patch("src.commands.compress.get_media_info")
    @patch("src.commands.compress.is_hdr", return_value=False)
    @patch("src.commands.compress.compress")
    @patch("src.internal.write.gate.confirm_prompt", return_value=True)
    def test_vbr_bitrate(
        self,
        _gate: MagicMock,
        mock_compress: MagicMock,
        _hdr: MagicMock,
        mock_info: MagicMock,
        _avail: MagicMock,
    ) -> None:
        mock_info.return_value = _make_info()
        mock_compress.return_value = Path("/out.mp4")

        result = runner.invoke(app, [
            "compress", "video", __file__,
            "--bitrate", "1000",
            "--yes",
        ])
        assert result.exit_code == 0, result.stdout
        kwargs = mock_compress.call_args[1]
        assert kwargs.get("bitrate_k") == 1000
        assert kwargs.get("attempts") == 3

    @patch("src.commands.compress.ffmpeg_available", return_value=True)
    @patch("src.commands.compress.get_media_info")
    @patch("src.commands.compress.is_hdr", return_value=False)
    @patch("src.commands.compress.compress")
    @patch("src.internal.write.gate.confirm_prompt", return_value=True)
    def test_tonemap_never(
        self,
        _gate: MagicMock,
        mock_compress: MagicMock,
        _hdr: MagicMock,
        mock_info: MagicMock,
        _avail: MagicMock,
    ) -> None:
        mock_info.return_value = _make_info()
        mock_compress.return_value = Path("/out.mp4")

        result = runner.invoke(app, [
            "compress", "video", __file__,
            "--tonemap", "never",
            "--yes",
        ])
        assert result.exit_code == 0, result.stdout
        kwargs = mock_compress.call_args[1]
        assert kwargs.get("tonemap") == "never"

    @patch("src.commands.compress.ffmpeg_available", return_value=True)
    @patch("src.commands.compress.get_media_info")
    @patch("src.commands.compress.is_hdr", return_value=False)
    @patch("src.commands.compress.compress")
    @patch("src.internal.write.gate.confirm_prompt", return_value=True)
    def test_custom_audio(
        self,
        _gate: MagicMock,
        mock_compress: MagicMock,
        _hdr: MagicMock,
        mock_info: MagicMock,
        _avail: MagicMock,
    ) -> None:
        mock_info.return_value = _make_info()
        mock_compress.return_value = Path("/out.mp4")

        result = runner.invoke(app, [
            "compress", "video", __file__,
            "--audio-bitrate", "64k",
            "--audio-channels", "2",
            "--yes",
        ])
        assert result.exit_code == 0, result.stdout
        kwargs = mock_compress.call_args[1]
        assert kwargs.get("audio_bitrate") == "64k"
        assert kwargs.get("audio_channels") == 2

    @patch("src.commands.compress.ffmpeg_available", return_value=True)
    @patch("src.commands.compress.get_media_info")
    @patch("src.commands.compress.is_hdr", return_value=False)
    @patch("src.commands.compress.compress")
    @patch("src.internal.write.gate.confirm_prompt", return_value=True)
    def test_hdr_detected_in_preview(
        self,
        _gate: MagicMock,
        mock_compress: MagicMock,
        mock_hdr: MagicMock,
        mock_info: MagicMock,
        _avail: MagicMock,
    ) -> None:
        mock_info.return_value = _make_info(codec_name="hevc",
                                            color_transfer="smpte2084",
                                            color_primaries="bt2020")
        mock_hdr.return_value = True
        mock_compress.return_value = Path("/out.mp4")

        result = runner.invoke(app, [
            "compress", "video", __file__,
            "--yes",
        ])
        assert result.exit_code == 0, result.stdout
        assert "HDR" in result.stdout

    @patch("src.commands.compress.ffmpeg_available", return_value=True)
    @patch("src.commands.compress.get_media_info")
    @patch("src.commands.compress.is_hdr", return_value=False)
    @patch("src.commands.compress.compress",
           side_effect=FfmpegError(["ffmpeg"], 1, "encode failed"))
    @patch("src.internal.write.gate.confirm_prompt", return_value=True)
    def test_compress_error(
        self,
        _gate: MagicMock,
        mock_compress: MagicMock,
        _hdr: MagicMock,
        mock_info: MagicMock,
        _avail: MagicMock,
    ) -> None:
        mock_info.return_value = _make_info()
        result = runner.invoke(app, [
            "compress", "video", __file__,
            "--yes",
        ])
        assert result.exit_code != 0
        assert "encode failed" in result.stdout
        mock_compress.assert_called_once()

    @patch("src.commands.compress.ffmpeg_available", return_value=True)
    @patch("src.commands.compress.get_media_info")
    @patch("src.commands.compress.is_hdr", return_value=False)
    @patch("src.commands.compress.compress")
    @patch("src.internal.write.gate.confirm_prompt", return_value=True)
    def test_tune_grain_flag(
        self,
        _gate: MagicMock,
        mock_compress: MagicMock,
        _hdr: MagicMock,
        mock_info: MagicMock,
        _avail: MagicMock,
    ) -> None:
        mock_info.return_value = _make_info()
        mock_compress.return_value = Path("/out.mp4")

        result = runner.invoke(app, [
            "compress", "video", __file__,
            "--tune-grain",
            "--yes",
        ])
        assert result.exit_code == 0, result.stdout
        kwargs = mock_compress.call_args[1]
        assert kwargs.get("tune_grain") is True


class TestCompressBatchCli:
    @patch("src.commands.compress.ffmpeg_available", return_value=True)
    @patch("src.commands.compress.scan_directory_flat")
    def test_batch_no_matches(self, mock_scan: MagicMock, _avail: MagicMock) -> None:
        mock_scan.return_value = []
        result = runner.invoke(app, ["compress", "batch", "."])
        assert result.exit_code != 0
        assert "no matching" in result.stdout.lower()

    @patch("src.commands.compress.ffmpeg_available", return_value=True)
    @patch("src.commands.compress.scan_directory_flat")
    def test_batch_dry_run(self, mock_scan: MagicMock, _avail: MagicMock) -> None:
        info = ScannerInfo(
            filename="test.mkv", codec="h264", resolution="1920x1080",
            bitrate="15.00",
        )
        mock_scan.return_value = [info]
        result = runner.invoke(app, ["compress", "batch", ".", "--dry-run"])
        assert result.exit_code == 0
        assert "Would compress" in result.stdout
        assert "test.mkv" in result.stdout

    @patch("src.commands.compress.ffmpeg_available", return_value=True)
    @patch("src.commands.compress.scan_directory_flat")
    @patch("src.commands.compress.compress")
    @patch("src.internal.write.gate.confirm_prompt", return_value=True)
    def test_batch_happy_path(
        self,
        _gate: MagicMock,
        mock_compress: MagicMock,
        mock_scan: MagicMock,
        _avail: MagicMock,
    ) -> None:
        info = ScannerInfo(filename="test.mkv", codec="h264")
        mock_scan.return_value = [info]
        mock_compress.return_value = Path("/out.mp4")

        result = runner.invoke(app, [
            "compress", "batch", ".",
            "--crf", "26",
            "--yes",
        ])
        assert result.exit_code == 0, result.stdout
        assert mock_compress.called

    @patch("src.commands.compress.ffmpeg_available", return_value=True)
    @patch("src.commands.compress.scan_directory_flat")
    def test_batch_filter(self, mock_scan: MagicMock, _avail: MagicMock) -> None:
        info = ScannerInfo(
            filename="test.mkv", codec="h265", hdr="HDR10",
        )
        mock_scan.return_value = [info]
        result = runner.invoke(app, [
            "compress", "batch", ".",
            "--filter", "codec=h265",
            "--dry-run",
        ])
        assert result.exit_code == 0
        assert "test.mkv" in result.stdout
