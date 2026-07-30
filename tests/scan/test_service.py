from __future__ import annotations

from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from src.services.scanner import (
    ScannerInfo,
    ScanStats,
    _COLUMNS,
    _compare_str,
    _detect_hdr,
    _fmt_bitrate_mbps,
    _fmt_duration,
    _fmt_size,
    _gcd,
    _normalize_profile,
    _parse_fps,
    _parse_size_human,
    _resolution_tier,
    apply_exclude,
    apply_filters,
    compute_stats,
    format_stats_text,
    generate_csv,
    generate_json,
    generate_report,
    generate_table,
    parse_filename,
    probe_file,
)

# ── ParseFilename ──

class TestParseFilename:
    def test_basic(self) -> None:
        assert parse_filename("Movie.mp4") == ("", "Movie", "")

    def test_with_num(self) -> None:
        assert parse_filename("12-Movie.mp4") == ("12", "Movie", "")

    def test_with_year(self) -> None:
        assert parse_filename("Movie-(2024).mp4") == ("", "Movie", "2024")

    def test_with_both(self) -> None:
        assert parse_filename("12-Movie-(2024).mkv") == ("12", "Movie", "2024")

    def test_complex_title(self) -> None:
        assert parse_filename("The-Last-Airbender-(2010).mp4") == ("", "The-Last-Airbender", "2010")

    def test_no_match(self) -> None:
        assert parse_filename("some_random_file.mkv") == ("", "some_random_file", "")

    def test_only_num_no_year(self) -> None:
        assert parse_filename("05-Video.mov") == ("05", "Video", "")


# ── DetectHdr ──

class TestDetectHdr:
    def test_pq(self) -> None:
        assert _detect_hdr("smpte2084", "bt2020") == "HDR10"

    def test_hlg(self) -> None:
        assert _detect_hdr("arib-std-b67", "bt2020") == "HLG"

    def test_sdr(self) -> None:
        assert _detect_hdr("bt709", "bt709") == ""

    def test_missing(self) -> None:
        assert _detect_hdr(None, None) == ""

    def test_wcg(self) -> None:
        assert _detect_hdr("", "bt2020") == "WCG"


# ── FormatHelpers ──

class TestFmtDuration:
    def test_zero(self) -> None:
        assert _fmt_duration(0) == ""

    def test_minutes_only(self) -> None:
        assert _fmt_duration(1800) == "30m"

    def test_hours(self) -> None:
        assert _fmt_duration(3600) == "1h00m"

    def test_hours_and_minutes(self) -> None:
        assert _fmt_duration(3661) == "1h01m"

    def test_long(self) -> None:
        assert _fmt_duration(95400) == "26h30m"

    def test_negative(self) -> None:
        assert _fmt_duration(-1) == ""


class TestFmtSize:
    def test_zero(self) -> None:
        assert _fmt_size(0) == ""

    def test_bytes(self) -> None:
        assert _fmt_size(500) == "500B"

    def test_kib(self) -> None:
        assert _fmt_size(2048) == "2.00KiB"

    def test_mib(self) -> None:
        assert _fmt_size(5_242_880) == "5.00MiB"

    def test_gib(self) -> None:
        assert _fmt_size(1_073_741_824) == "1.00GiB"

    def test_tib(self) -> None:
        val = 1_099_511_627_776
        assert _fmt_size(val) == "1.00TiB"

    def test_negative(self) -> None:
        assert _fmt_size(-1) == ""


class TestFmtBitrateMbps:
    def test_zero(self) -> None:
        assert _fmt_bitrate_mbps(0) == ""

    def test_value(self) -> None:
        assert _fmt_bitrate_mbps(15_000_000) == "15.00"

    def test_small(self) -> None:
        assert _fmt_bitrate_mbps(500_000) == "0.50"


class TestParseFps:
    def test_rational(self) -> None:
        assert _parse_fps("24000/1001") == "23.976"

    def test_integer_rational(self) -> None:
        assert _parse_fps("60/1") == "60"

    def test_decimal(self) -> None:
        assert _parse_fps("29.970") == "29.97"

    def test_empty(self) -> None:
        assert _parse_fps("") == ""

    def test_invalid(self) -> None:
        assert _parse_fps("abc") == ""


class TestNormalizeProfile:
    def test_main10(self) -> None:
        assert _normalize_profile("Main 10") == "M10"

    def test_high10(self) -> None:
        assert _normalize_profile("High 10") == "H10"

    def test_main(self) -> None:
        assert _normalize_profile("Main") == "Main"

    def test_other(self) -> None:
        assert _normalize_profile("High@L4") == "High@L4"


class TestGcd:
    def test_basic(self) -> None:
        assert _gcd(1920, 1080) == 120
        assert _gcd(16, 9) == 1
        assert _gcd(0, 5) == 5


class TestResolutionTier:
    def test_sd(self) -> None:
        assert _resolution_tier(480) == "SD"

    def test_hd(self) -> None:
        assert _resolution_tier(720) == "HD"

    def test_fhd(self) -> None:
        assert _resolution_tier(1080) == "FHD"

    def test_qhd(self) -> None:
        assert _resolution_tier(1440) == "QHD"

    def test_uhd(self) -> None:
        assert _resolution_tier(2160) == "UHD"

    def test_uhd_plus(self) -> None:
        assert _resolution_tier(4320) == "UHD+"


# ── Filtering ──

class TestCompareStr:
    def test_eq(self) -> None:
        assert _compare_str("h264", "=", "h264") is True
        assert _compare_str("h264", "=", "H264") is True
        assert _compare_str("h264", "=", "h265") is False

    def test_neq(self) -> None:
        assert _compare_str("h264", "!=", "h265") is True
        assert _compare_str("h264", "!=", "h264") is False

    def test_numeric_lt(self) -> None:
        assert _compare_str("5", "<", "10") is True
        assert _compare_str("10", "<", "5") is False

    def test_numeric_gt(self) -> None:
        assert _compare_str("10", ">", "5") is True
        assert _compare_str("5", ">", "10") is False

    def test_size_compare(self) -> None:
        assert _compare_str("500MiB", ">", "1GiB") is False
        assert _compare_str("2GiB", ">", "500MiB") is True


class TestApplyFilters:
    def make_info(self, **kw: object) -> ScannerInfo:
        defaults: dict[str, object] = {
            "filename": "test.mkv", "codec": "h264", "hdr": "HDR10",
            "container": "matroska", "extension": ".mkv",
            "_width": 1920, "_height": 1080,
            "_bitrate_bps": 15_000_000,
            "_size_bytes": 2_000_000_000,
            "_duration_secs": 6000.0,
        }
        defaults.update(kw)
        return ScannerInfo(**defaults)  # type: ignore[arg-type]

    def test_exact_match(self) -> None:
        files = [self.make_info(codec="h264"), self.make_info(codec="h265")]
        result = apply_filters(files, ["codec=h264"])
        assert len(result) == 1
        assert result[0].codec == "h264"

    def test_numeric_gt(self) -> None:
        files = [self.make_info(_height=720), self.make_info(_height=1080)]
        result = apply_filters(files, ["height>720"])
        assert len(result) == 1
        assert result[0]._height == 1080

    def test_multiple_and(self) -> None:
        files = [
            self.make_info(codec="h264", hdr="HDR10"),
            self.make_info(codec="h264", hdr=""),
            self.make_info(codec="h265", hdr="HDR10"),
        ]
        result = apply_filters(files, ["codec=h264", "hdr=HDR10"])
        assert len(result) == 1

    def test_no_match(self) -> None:
        files = [self.make_info(codec="h264")]
        result = apply_filters(files, ["codec=h265"])
        assert len(result) == 0

    def test_empty_filters(self) -> None:
        files = [self.make_info()]
        assert apply_filters(files, None) == files
        assert apply_filters(files, []) == files

    def test_size_compare(self) -> None:
        small = self.make_info(_size_bytes=500_000_000)
        big = self.make_info(_size_bytes=2_000_000_000)
        result = apply_filters([small, big], ["size>1GiB"])
        assert len(result) == 1
        assert result[0]._size_bytes == 2_000_000_000


class TestApplyExclude:
    def make_info(self, filename: str = "test.mkv") -> ScannerInfo:
        return ScannerInfo(filename=filename)

    def test_glob(self) -> None:
        files = [self.make_info("a.mp4"), self.make_info("b-compressed.mp4")]
        result = apply_exclude(files, ["*-compressed.mp4"])
        assert len(result) == 1
        assert result[0].filename == "a.mp4"

    def test_multiple(self) -> None:
        files = [
            self.make_info("a.mp4"), self.make_info("b.mp4"),
            self.make_info("c.log"),
        ]
        result = apply_exclude(files, ["*.log"])
        assert len(result) == 2

    def test_empty(self) -> None:
        files = [self.make_info("a.mp4")]
        assert apply_exclude(files, None) == files
        assert apply_exclude(files, []) == files


# ── Stats ──

class TestComputeStats:
    def make_info(self, **kw: object) -> ScannerInfo:
        defaults: dict[str, object] = {
            "codec": "h264", "hdr": "", "_height": 720,
            "container": "mp4", "_size_bytes": 1_000_000_000,
            "_duration_secs": 3600.0, "_bitrate_bps": 2_000_000,
            "filename": "f.mp4", "size": "1.00GiB", "bitrate": "2.00",
        }
        defaults.update(kw)
        return ScannerInfo(**defaults)  # type: ignore[arg-type]

    def test_total_count(self) -> None:
        stats = compute_stats([self.make_info(), self.make_info()])
        assert stats.total_files == 2

    def test_codec_breakdown(self) -> None:
        files = [self.make_info(codec="h264"), self.make_info(codec="h264"),
                 self.make_info(codec="h265")]
        stats = compute_stats(files)
        assert stats.by_codec == {"h264": 2, "h265": 1}

    def test_hdr_breakdown(self) -> None:
        files = [self.make_info(hdr="HDR10"), self.make_info(hdr="")]
        stats = compute_stats(files)
        assert stats.by_hdr == {"HDR10": 1, "SDR": 1}

    def test_resolution_tier(self) -> None:
        files = [self.make_info(_height=720), self.make_info(_height=1080)]
        stats = compute_stats(files)
        assert stats.by_resolution_tier["HD"] == 1
        assert stats.by_resolution_tier["FHD"] == 1

    def test_largest(self) -> None:
        files = [
            self.make_info(filename="big.mkv", _size_bytes=5_000_000_000, size="5.00GiB"),
            self.make_info(filename="small.mkv", _size_bytes=1_000_000_000, size="1.00GiB"),
        ]
        stats = compute_stats(files)
        assert stats.largest is not None
        assert stats.largest[0][0] == "big.mkv"

    def test_empty(self) -> None:
        stats = compute_stats([])
        assert stats.total_files == 0
        assert stats.total_size == ""


class TestFormatStatsText:
    def test_basic(self) -> None:
        stats = ScanStats(
            total_files=5, total_size="10.00GiB", total_runtime="10h00m",
            avg_bitrate="15.00",
            by_codec={"h264": 3, "h265": 2},
            by_hdr={"SDR": 5},
            by_resolution_tier={"FHD": 3, "HD": 2},
            by_container={"mp4": 5},
            largest=[("test.mkv", "5.00GiB", "15.00")],
        )
        text = format_stats_text(stats)
        assert "Files: 5" in text
        assert "Total size: 10.00GiB" in text
        assert "h264: 3" in text
        assert "SDR: 5" in text
        assert "FHD: 3" in text
        assert "test.mkv" in text

    def test_empty(self) -> None:
        text = format_stats_text(ScanStats())
        assert "Files: 0" in text


# ── ProbeFile ──

SAMPLE_PROBE = {
    "streams": [
        {
            "codec_type": "video",
            "codec_name": "hevc",
            "width": 3840, "height": 2160,
            "coded_width": 3840, "coded_height": 2160,
            "display_aspect_ratio": "16:9",
            "profile": "Main 10",
            "level": 150,
            "pix_fmt": "yuv420p10le",
            "bits_per_raw_sample": 10,
            "color_range": "tv",
            "color_space": "bt2020nc",
            "color_transfer": "smpte2084",
            "color_primaries": "bt2020",
            "field_order": "progressive",
            "avg_frame_rate": "24000/1001",
            "nb_frames": 143000,
            "refs": 1,
            "bit_rate": 45000000,
        },
        {
            "codec_type": "audio",
            "codec_name": "eac3",
            "channels": 6,
            "channel_layout": "5.1",
            "sample_rate": 48000,
            "bit_rate": 384000,
        },
        {
            "codec_type": "subtitle",
            "codec_name": "subrip",
            "tags": {"language": "eng"},
        },
        {
            "codec_type": "subtitle",
            "codec_name": "subrip",
            "tags": {"language": "spa"},
        },
    ],
    "format": {
        "filename": "/test/Movie.mkv",
        "nb_streams": 4,
        "format_name": "matroska,webm",
        "duration": "5971.000000",
        "size": "28000000000",
        "bit_rate": "45000000",
    },
}


class TestProbeFile:
    @patch("src.services.scanner.run_ffprobe")
    def test_sdr(self, mock_probe: MagicMock) -> None:
        from src.services.compress import parse_ffprobe_output

        data = {
            "streams": [{
                "codec_type": "video",
                "codec_name": "h264",
                "width": 1920, "height": 1080,
                "profile": "High",
                "level": 40,
                "pix_fmt": "yuv420p",
                "color_transfer": "bt709",
                "color_primaries": "bt709",
                "field_order": "progressive",
                "avg_frame_rate": "30000/1001",
                "nb_frames": 90000,
                "bit_rate": 8000000,
            }, {
                "codec_type": "audio",
                "codec_name": "aac",
                "channels": 2,
                "channel_layout": "stereo",
                "sample_rate": 48000,
                "bit_rate": 128000,
            }],
            "format": {
                "filename": "/test/video.mp4",
                "nb_streams": 2,
                "format_name": "mov,mp4,m4a,3gp,3g2,mj2",
                "duration": "3000.000000",
                "size": "3000000000",
                "bit_rate": "8000000",
            },
        }
        mock_probe.return_value = data
        info = probe_file("/test/video.mp4")
        assert info.filename == "video.mp4"
        assert info.resolution == "1920x1080"
        assert info.codec == "h264"
        assert info.profile == "High"
        assert info.hdr == ""
        assert info.audio_codec == "aac"
        assert info.audio_channels == "2"
        assert info.container == "mov,mp4,m4a,3gp,3g2,mj2"
        assert info.runtime == "50m"
        assert info.fps == "29.97"

    @patch("src.services.scanner.run_ffprobe")
    def test_hdr(self, mock_probe: MagicMock) -> None:
        mock_probe.return_value = SAMPLE_PROBE
        info = probe_file("/test/Movie.mkv")
        assert info.codec == "hevc"
        assert info.hdr == "HDR10"
        assert info.profile == "M10"
        assert info.bit_depth == "10"
        assert info.pix_fmt == "yuv420p10le"
        assert info.dar == "16:9"
        assert info.audio_codec == "eac3"
        assert info.audio_channels == "6"
        assert info.audio_layout == "5.1"
        assert info.sub_streams == "2"
        assert info.sub_languages == "eng,spa"
        assert info.total_streams == "4"
        assert info._size_bytes == 28_000_000_000

    @patch("src.services.scanner.run_ffprobe")
    def test_no_audio(self, mock_probe: MagicMock) -> None:
        data = {
            "streams": [{
                "codec_type": "video",
                "codec_name": "h264",
                "width": 1280, "height": 720,
                "avg_frame_rate": "30/1",
            }],
            "format": {"nb_streams": 1, "duration": "100", "size": "50000000"},
        }
        mock_probe.return_value = data
        info = probe_file("/test/silent.mp4")
        assert info.audio_codec == ""

    @patch("src.services.scanner.run_ffprobe")
    def test_missing_resolution_dar(self, mock_probe: MagicMock) -> None:
        data = {
            "streams": [{
                "codec_type": "video",
                "width": 1920, "height": 1080,
                "avg_frame_rate": "24000/1001",
            }],
            "format": {"nb_streams": 1, "duration": "100", "size": "100000000"},
        }
        mock_probe.return_value = data
        info = probe_file("/test/no_dar.mp4")
        # DAR should be computed from w:h
        assert info.dar == "16:9"


# ── GenerateTable ──

class TestGenerateTable:
    def make_info(self, **kw: object) -> ScannerInfo:
        defaults: dict[str, object] = {
            "filename": "test.mkv", "title": "Test", "codec": "h264",
            "resolution": "1920x1080", "hdr": "",
        }
        defaults.update(kw)
        return ScannerInfo(**defaults)  # type: ignore[arg-type]

    def test_headers(self) -> None:
        table = generate_table([])
        for col in _COLUMNS:
            assert col in table

    def test_data_row(self) -> None:
        info = self.make_info()
        table = generate_table([info])
        assert "test.mkv" in table
        assert "Test" in table
        assert "h264" in table

    def test_numbered_column(self) -> None:
        info = self.make_info(num="01")
        table = generate_table([info], numbered=True)
        assert "| 01 |" in table or "|01|" in table

    def test_pipe_sanitize(self) -> None:
        info = self.make_info(title="A | B")
        table = generate_table([info])
        assert "A \\| B" in table


# ── GenerateReport ──

class TestGenerateReport:
    def test_root_heading(self) -> None:
        groups = []
        report = generate_report("/media/test", groups)
        assert "# test" in report
        assert "generated:" in report

    def test_subdir_heading(self) -> None:
        info = ScannerInfo(filename="f.mkv")
        groups = [(Path("/media/test/movies"), [info])]
        report = generate_report("/media/test", groups)
        assert "## movies/" in report

    def test_flat_single_group(self) -> None:
        info = ScannerInfo(filename="f.mkv")
        groups = [(Path("/media/test"), [info])]
        report = generate_report("/media/test", groups)
        assert "f.mkv" in report


# ── GenerateCsv ──

class TestGenerateCsv:
    def test_header(self) -> None:
        csv = generate_csv([])
        for col in _COLUMNS:
            assert col in csv

    def test_data_row(self) -> None:
        info = ScannerInfo(filename="f.mkv", codec="h264", resolution="1920x1080")
        csv = generate_csv([info])
        assert "f.mkv" in csv
        assert "h264" in csv


# ── GenerateJson ──

class TestGenerateJson:
    def test_valid_json(self) -> None:
        import json
        info = ScannerInfo(filename="f.mkv", codec="h264")
        groups = [(Path("/test"), [info])]
        output = generate_json(groups)
        parsed = json.loads(output)
        assert len(parsed) == 1
        assert parsed[0]["filename"] == "f.mkv"
        assert parsed[0]["codec"] == "h264"

    def test_private_fields_stripped(self) -> None:
        info = ScannerInfo(filename="f.mkv", _width=1920)
        groups = [(Path("/test"), [info])]
        output = generate_json(groups)
        assert "_width" not in output


# ── ParseSizeHuman ──

class TestParseSizeHuman:
    def test_bytes(self) -> None:
        assert _parse_size_human("500") == 500

    def test_kib(self) -> None:
        assert _parse_size_human("2KiB") == 2048

    def test_mib(self) -> None:
        assert _parse_size_human("5MiB") == 5 * 1024**2

    def test_gib(self) -> None:
        assert _parse_size_human("1GiB") == 1024**3
