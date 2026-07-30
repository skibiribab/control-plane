from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from src.services.compress import (
    CropRect,
    FfmpegError,
    MediaInfo,
    auto_bitrate_k,
    auto_crf,
    auto_max_bitrate_k,
    auto_resolution,
    auto_step_k,
    compose_vf,
    is_hdr,
    parse_ffprobe_output,
    resolve_codec,
)

SDR_PROBE = {
    "streams": [
        {
            "codec_type": "video",
            "codec_name": "h264",
            "width": 1920,
            "height": 1080,
            "r_frame_rate": "24000/1001",
            "avg_frame_rate": "24000/1001",
            "pix_fmt": "yuv420p",
            "color_transfer": "bt709",
            "color_primaries": "bt709",
            "field_order": "progressive",
        },
        {
            "codec_type": "audio",
            "codec_name": "aac",
            "channels": 6,
            "bit_rate": 384000,
        },
    ],
    "format": {"duration": "120.0", "bit_rate": "10240000"},
}

HDR_PROBE = {
    "streams": [
        {
            "codec_type": "video",
            "codec_name": "hevc",
            "width": 3840,
            "height": 2160,
            "r_frame_rate": "24000/1001",
            "avg_frame_rate": "24000/1001",
            "pix_fmt": "yuv420p10le",
            "color_transfer": "smpte2084",
            "color_primaries": "bt2020",
            "field_order": "progressive",
        },
        {
            "codec_type": "audio",
            "codec_name": "eac3",
            "channels": 8,
            "bit_rate": 512000,
        },
    ],
    "format": {"duration": "180.0", "bit_rate": "45000000"},
}

MINIMAL_PROBE = {
    "streams": [
        {
            "codec_type": "video",
            "codec_name": "h264",
            "width": 1280,
            "height": 720,
            "r_frame_rate": "30000/1001",
            "pix_fmt": "yuv420p",
        },
    ],
    "format": {"duration": "60.0", "bit_rate": "5000000"},
}


class TestParseProbe:
    def test_sdr(self) -> None:
        info = parse_ffprobe_output(SDR_PROBE)
        assert (info.width, info.height) == (1920, 1080)
        assert info.codec_name == "h264"
        assert info.bit_rate == 10_240_000
        assert info.fps == pytest.approx(23.976, rel=1e-2)
        assert info.color_transfer == "bt709"
        assert info.audio_channels == 6
        assert info.audio_bit_rate == 384_000
        assert info.pix_fmt == "yuv420p"

    def test_hdr(self) -> None:
        info = parse_ffprobe_output(HDR_PROBE)
        assert (info.width, info.height) == (3840, 2160)
        assert info.codec_name == "hevc"
        assert info.bit_rate == 45_000_000
        assert info.color_transfer == "smpte2084"
        assert info.audio_channels == 8

    def test_minimal(self) -> None:
        info = parse_ffprobe_output(MINIMAL_PROBE)
        assert (info.width, info.height) == (1280, 720)
        assert info.fps == pytest.approx(29.97, rel=1e-2)
        assert info.audio_channels is None
        assert info.color_transfer is None

    def test_zero_division_fps(self) -> None:
        probe = {
            "streams": [{"codec_type": "video", "r_frame_rate": "0/0"}],
            "format": {},
        }
        info = parse_ffprobe_output(probe)
        assert info.fps == 0.0

    def test_missing_streams(self) -> None:
        info = parse_ffprobe_output({"streams": [], "format": {}})
        assert info.width == 0
        assert info.fps == 0.0


class TestIsHdr:
    def test_pq_hdr(self) -> None:
        assert is_hdr(parse_ffprobe_output(HDR_PROBE)) is True

    def test_hlg_hdr(self) -> None:
        info = parse_ffprobe_output(SDR_PROBE)
        info.color_transfer = "arib-std-b67"
        assert is_hdr(info) is True

    def test_sdr(self) -> None:
        assert is_hdr(parse_ffprobe_output(SDR_PROBE)) is False

    def test_missing_fields(self) -> None:
        info = MediaInfo(width=1280, height=720)
        assert is_hdr(info) is False


class TestAutoResolution:
    def test_keep_720p(self) -> None:
        info = MediaInfo(height=720)
        assert auto_resolution(info) == 720

    def test_1080p_to_720(self) -> None:
        info = MediaInfo(height=1080)
        assert auto_resolution(info) == 720

    def test_4k_to_1080(self) -> None:
        info = MediaInfo(height=2160)
        assert auto_resolution(info) == 1080

    def test_1440p_to_1080(self) -> None:
        info = MediaInfo(height=1440)
        assert auto_resolution(info) == 1080

    def test_480p_keep(self) -> None:
        info = MediaInfo(height=480)
        assert auto_resolution(info) == 480


class TestAutoCrf:
    def test_h265(self) -> None:
        assert auto_crf("libx265") == 24

    def test_h264(self) -> None:
        assert auto_crf("libx264") == 22

    def test_unknown(self) -> None:
        assert auto_crf("") == 24

    def test_h265_short(self) -> None:
        assert auto_crf("h265") == 24


class TestAutoBitrate:
    @pytest.mark.parametrize(
        ("height", "expected"),
        [
            (240, 200),
            (360, 400),
            (480, 600),
            (720, 1000),
            (1080, 1500),
            (1440, 3000),
            (2160, 6000),
        ],
    )
    def test_by_height(self, height: int, expected: int) -> None:
        assert auto_bitrate_k(height) == expected

    def test_capped_by_original(self) -> None:
        result = auto_bitrate_k(1080, original_bitrate=1_000_000)
        assert result <= int(1_000_000 / 1000 * 0.6)

    def test_floor(self) -> None:
        result = auto_bitrate_k(240, original_bitrate=100_000)
        assert result >= 200

    def test_large_with_original_cap(self) -> None:
        result = auto_bitrate_k(2160, original_bitrate=5_000_000)
        assert result <= 3000


class TestAutoMaxBitrate:
    def test_double(self) -> None:
        assert auto_max_bitrate_k(1000) == 2000


class TestAutoStep:
    def test_percentage(self) -> None:
        assert auto_step_k(1000) == 200

    def test_floor(self) -> None:
        assert auto_step_k(500) == 200

    def test_small_percentage(self) -> None:
        assert auto_step_k(300) == 200


class TestComposeVf:
    def test_noop(self) -> None:
        info = MediaInfo(height=720, fps=30.0, color_transfer="bt709",
                         field_order="progressive")
        assert compose_vf(info, tonemap="never") is None

    def test_scale(self) -> None:
        info = MediaInfo(height=1080, fps=24.0, color_transfer="bt709",
                         field_order="progressive")
        vf = compose_vf(info, tonemap="never", scale_height=720)
        assert vf is not None
        assert "scale=-2:720" in vf
        assert "tonemap" not in vf

    def test_fps_cap(self) -> None:
        info = MediaInfo(height=720, fps=120.0, color_transfer="bt709",
                         field_order="progressive")
        vf = compose_vf(info, tonemap="never", max_fps=60)
        assert "fps=60" in vf

    def test_fps_below_threshold(self) -> None:
        info = MediaInfo(height=720, fps=24.0, color_transfer="bt709",
                         field_order="progressive")
        vf = compose_vf(info, tonemap="never", max_fps=60)
        assert vf is None

    def test_tonemap_hdr_auto(self) -> None:
        info = MediaInfo(height=2160, fps=24.0, color_transfer="smpte2084",
                         field_order="progressive")
        vf = compose_vf(info, tonemap="auto")
        assert "tonemap" in vf

    def test_tonemap_never_skips_hdr(self) -> None:
        info = MediaInfo(height=2160, fps=24.0, color_transfer="smpte2084",
                         field_order="progressive")
        vf = compose_vf(info, tonemap="never")
        assert vf is None

    def test_tonemap_force_sdr(self) -> None:
        info = MediaInfo(height=1080, fps=24.0, color_transfer="bt709",
                         field_order="progressive")
        vf = compose_vf(info, tonemap="force")
        assert "tonemap" in vf

    def test_crop(self) -> None:
        info = MediaInfo(height=1080, fps=24.0, color_transfer="bt709",
                         field_order="progressive")
        crop = CropRect(w=1920, h=800, x=0, y=140)
        vf = compose_vf(info, tonemap="never", crop=crop)
        assert "crop=1920:800:0:140" in vf

    def test_denoise(self) -> None:
        info = MediaInfo(height=1080, fps=24.0, color_transfer="bt709",
                         field_order="progressive")
        vf = compose_vf(info, tonemap="never", denoise=True)
        assert "hqdn3d" in vf

    def test_deinterlace(self) -> None:
        info = MediaInfo(height=1080, fps=30.0, color_transfer="bt709",
                         field_order="ttsi")
        vf = compose_vf(info, tonemap="never")
        assert "yadif" in vf

    def test_filter_order(self) -> None:
        info = MediaInfo(height=2160, fps=120.0, color_transfer="smpte2084",
                         field_order="progressive")
        crop = CropRect(w=3840, h=1600, x=0, y=280)
        vf = compose_vf(info, tonemap="auto", crop=crop,
                        scale_height=1080, max_fps=60, denoise=True)
        assert vf is not None
        parts = vf.split(",")

        def find_idx(prefix: str) -> int:
            return next(i for i, p in enumerate(parts) if p.startswith(prefix))

        idx = {
            "tonemap": find_idx("tonemap"),
            "crop": find_idx("crop="),
            "scale": find_idx("scale="),
            "fps": find_idx("fps="),
            "hqdn3d": find_idx("hqdn3d"),
        }
        assert idx["tonemap"] < idx["crop"] < idx["scale"] < idx["fps"] < idx["hqdn3d"]

    def test_zscale_after_tonemap(self) -> None:
        info = MediaInfo(height=2160, fps=24.0, color_transfer="smpte2084",
                         field_order="progressive")
        vf = compose_vf(info, tonemap="auto")
        parts = vf.split(",")
        tonemap_pos = parts.index("tonemap=hable:desat=2")
        zscale_pos = next(i for i, p in enumerate(parts) if p.startswith("zscale"))
        assert tonemap_pos < zscale_pos


class TestResolveCodec:
    def test_libx265(self) -> None:
        assert resolve_codec("libx265") == "libx265"

    def test_libx264(self) -> None:
        assert resolve_codec("libx264") == "libx264"

    def test_h265_short(self) -> None:
        assert resolve_codec("h265") == "libx265"

    def test_h264_short(self) -> None:
        assert resolve_codec("h264") == "libx264"

    def test_auto_prefers_x265(self) -> None:
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0, stdout="libx265   HEVC (High Efficiency Video Coding)\n",
                stderr="",
            )
            assert resolve_codec("auto") == "libx265"

    def test_auto_fallback_x264(self) -> None:
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0, stdout="libx264   H.264 / AVC\n",
                stderr="",
            )
            assert resolve_codec("auto") == "libx264"

    def test_auto_oserror_fallback(self) -> None:
        with patch("subprocess.run", side_effect=OSError):
            assert resolve_codec("auto") == "libx264"


class TestFfmpegError:
    def test_message(self) -> None:
        err = FfmpegError(["ffmpeg", "-i", "in"], 1, "unknown format")
        assert "ffmpeg command failed (1)" in str(err)
        assert "unknown format" in str(err)
        assert err.cmd == ["ffmpeg", "-i", "in"]


class TestEncodeCrf:
    @patch("src.services.compress.run_ffmpeg")
    @patch("src.services.compress.get_media_info")
    @patch("src.services.compress.shutil.which", return_value="/usr/bin/ffmpeg")
    def test_basic_encode(
        self,
        _which: MagicMock,
        mock_info: MagicMock,
        mock_run: MagicMock,
    ) -> None:
        from src.services.compress import encode_crf

        mock_info.side_effect = [
            parse_ffprobe_output(SDR_PROBE),  # probe input
            parse_ffprobe_output(SDR_PROBE),  # probe output (bitrate readback)
        ]

        result = encode_crf(
            "/in.mp4", "/out.mp4",
            crf=24,
            maxrate_k=2000,
            preset="slow",
            codec="libx265",
            pix_fmt="yuv420p10le",
            audio_bitrate="128k",
            audio_channels=2,
            tune_grain=False,
            strip_meta=True,
            vf=None,
        )

        assert result == 10_240_000
        args = mock_run.call_args[0][0]
        assert "-crf" in args
        assert "24" in args[args.index("-crf") + 1]
        assert "-maxrate" in args
        assert "2000k" in args[args.index("-maxrate") + 1]
        assert "-bufsize" in args
        assert "1000k" in args[args.index("-bufsize") + 1]
        assert "-preset" in args
        assert "slow" in args[args.index("-preset") + 1]
        assert "-pix_fmt" in args
        assert "yuv420p10le" in args[args.index("-pix_fmt") + 1]
        assert "-c:a" in args
        assert "aac" in args[args.index("-c:a") + 1]
        assert "-ac" in args
        assert "2" in args[args.index("-ac") + 1]
        assert "-map_metadata" in args
        assert "-pass" not in args

    @patch("src.services.compress.run_ffmpeg")
    @patch("src.services.compress.get_media_info")
    @patch("src.services.compress.shutil.which", return_value="/usr/bin/ffmpeg")
    def test_with_vf(
        self,
        _which: MagicMock,
        mock_info: MagicMock,
        mock_run: MagicMock,
    ) -> None:
        from src.services.compress import encode_crf

        mock_info.side_effect = [
            parse_ffprobe_output(SDR_PROBE),
            parse_ffprobe_output(SDR_PROBE),
        ]

        encode_crf(
            "/in.mp4", "/out.mp4",
            crf=26, maxrate_k=1000,
            preset="medium", codec="libx264",
            pix_fmt="yuv420p",
            audio_bitrate="copy",
            audio_channels=None,
            tune_grain=True,
            strip_meta=False,
            vf="scale=-2:720,fps=30",
        )

        args = mock_run.call_args[0][0]
        vf_idx = args.index("-vf")
        assert args[vf_idx + 1] == "scale=-2:720,fps=30"
        assert "-c:a" in args
        assert "copy" in args[args.index("-c:a") + 1]
        assert "-map_metadata" not in args

    @patch("src.services.compress.run_ffmpeg")
    @patch("src.services.compress.get_media_info")
    @patch("src.services.compress.shutil.which", return_value="/usr/bin/ffmpeg")
    def test_x265_params_contains_tune_grain(
        self,
        _which: MagicMock,
        mock_info: MagicMock,
        mock_run: MagicMock,
    ) -> None:
        from src.services.compress import encode_crf

        mock_info.side_effect = [
            parse_ffprobe_output(SDR_PROBE),
            parse_ffprobe_output(SDR_PROBE),
        ]

        encode_crf(
            "/in.mp4", "/out.mp4",
            crf=24, maxrate_k=2000,
            preset="slow", codec="libx265",
            pix_fmt="yuv420p10le",
            audio_bitrate="128k", audio_channels=None,
            tune_grain=True, strip_meta=False,
            vf=None,
        )

        args = mock_run.call_args[0][0]
        x265_idx = args.index("-x265-params")
        params = args[x265_idx + 1]
        assert "tune=grain" in params


class TestEncodeVbr:
    @patch("src.services.compress.run_ffmpeg")
    @patch("src.services.compress.get_media_info")
    @patch("src.services.compress.shutil.which", return_value="/usr/bin/ffmpeg")
    def test_pass_structure(
        self,
        _which: MagicMock,
        mock_info: MagicMock,
        mock_run: MagicMock,
    ) -> None:
        from src.services.compress import encode_vbr

        mock_info.side_effect = [
            parse_ffprobe_output(SDR_PROBE),  # probe for pass 1
            parse_ffprobe_output(SDR_PROBE),  # probe for pass 2
            parse_ffprobe_output(SDR_PROBE),  # probe for readback
        ]

        mock_run.side_effect = [
            MagicMock(returncode=0, stdout="", stderr=""),  # pass 1
            MagicMock(returncode=0, stdout="", stderr=""),  # pass 2
        ]

        result = encode_vbr(
            "/in.mp4", "/out.mp4",
            vf=None, target_bitrate_k=1000, maxrate_k=2000,
            preset="slow", codec="libx265", pix_fmt="yuv420p10le",
            audio_bitrate="128k", audio_channels=None,
            tune_grain=False, strip_meta=True,
        )

        assert result == 10_240_000
        assert mock_run.call_count == 2
        pass1_args = mock_run.call_args_list[0][0][0]
        pass2_args = mock_run.call_args_list[1][0][0]

        assert "-pass" in pass1_args
        assert "1" in pass1_args[pass1_args.index("-pass") + 1]
        assert "-an" in pass1_args
        assert "/dev/null" in pass1_args

        assert "-pass" in pass2_args
        assert "2" in pass2_args[pass2_args.index("-pass") + 1]
        assert "-c:a" in pass2_args
        assert "-map_metadata" in pass2_args
        assert "/out.mp4" in pass2_args

    @patch("src.services.compress.run_ffmpeg")
    @patch("src.services.compress.get_media_info")
    @patch("src.services.compress.shutil.which", return_value="/usr/bin/ffmpeg")
    def test_audio_copy(
        self,
        _which: MagicMock,
        mock_info: MagicMock,
        mock_run: MagicMock,
    ) -> None:
        from src.services.compress import encode_vbr

        mock_info.side_effect = [
            parse_ffprobe_output(SDR_PROBE),
            parse_ffprobe_output(SDR_PROBE),
            parse_ffprobe_output(SDR_PROBE),
        ]

        mock_run.side_effect = [
            MagicMock(returncode=0, stdout="", stderr=""),
            MagicMock(returncode=0, stdout="", stderr=""),
        ]

        encode_vbr(
            "/in.mp4", "/out.mp4",
            vf=None, target_bitrate_k=1000, maxrate_k=2000,
            preset="slow", codec="libx265", pix_fmt="yuv420p10le",
            audio_bitrate="copy", audio_channels=None,
            tune_grain=False, strip_meta=False,
        )

        pass2_args = mock_run.call_args_list[1][0][0]
        copy_idx = pass2_args.index("-c:a")
        assert pass2_args[copy_idx + 1] == "copy"
