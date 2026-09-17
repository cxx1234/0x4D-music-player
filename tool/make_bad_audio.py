#!/usr/bin/env python3
"""生成"音频错误处理"测试素材（坏文件 + 对照用的真实文件）。

用法：
    python3 tool/make_bad_audio.py [输出目录]
默认输出到 ~/Desktop/0x4D-audio-test/

素材设计（文件名前缀决定顺序，标题缺失时 title 回退为文件名，故排序稳定）：

    场景 A — 失败后自动跳过并恢复播放
        01-bad-empty.mp3          0 字节
        02-bad-random.mp3         纯随机字节（无音频头）
        03-good-real.mp3          真实 mp3 完整拷贝（应当能正常播放）

    场景 B — 连续 3 次失败后停止自动跳过
        04-bad-id3-garbage.mp3    合法 ID3v2 头 + 垃圾"帧"数据
        05-bad-random-short.mp3   512 字节随机数据
        06-bad-empty-2.mp3        0 字节
        07-good-real-b.mp3        真实 mp3 拷贝（第 3 次失败后**不应**被播到）

    场景 C — 观察项（"看起来坏但可能仍能播"的真实情况）
        08-obs-truncated.mp3      真实 mp3 的前 64KB（截断）
        09-obs-flac-renamed.mp3   真实 flac 的前 256KB，仅改扩展名为 .mp3

注意：扫描只识别 .mp3/.flac/.m4a（见 lib/core/constants/audio_extensions.dart），
因此坏文件一律用 .mp3 扩展名。
"""

from __future__ import annotations

import random
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MUSIC_SRC = REPO_ROOT / "test" / "music"
DEFAULT_OUT = Path.home() / "Desktop" / "0x4D-audio-test"

# 真实文件（作对照 / 截断源）；缺失时给出提示而不是崩溃。
GOOD_MP3 = MUSIC_SRC / "黒うさP - 下弦の月.mp3"
GOOD_FLAC = MUSIC_SRC / "幽閉サテライト - 大地に咲く旋律 (with senya).flac"


def rand_bytes(size: int, seed: int) -> bytes:
    rnd = random.Random(seed)
    return bytes(rnd.getrandbits(8) for _ in range(size))


def _syncsafe(value: int) -> bytes:
    """ID3v2 的 28 位 syncsafe 整数编码。"""
    return bytes(
        [
            (value >> 21) & 0x7F,
            (value >> 14) & 0x7F,
            (value >> 7) & 0x7F,
            value & 0x7F,
        ]
    )


def strip_id3(data: bytes) -> bytes:
    """去掉 ID3v2 前缀与 ID3v1 结尾。

    目的：让对照文件的**元数据标题缺失**，从而回退为文件名——否则标题会是
    "下弦の月"，按标题排序会排到所有 0X-*.mp3 之后，破坏"坏→坏→好"的测试链条。
    """
    if data[:3] == b"ID3":
        size = (
            ((data[6] & 0x7F) << 21)
            | ((data[7] & 0x7F) << 14)
            | ((data[8] & 0x7F) << 7)
            | (data[9] & 0x7F)
        )
        data = data[10 + size :]
    if data[-128:-125] == b"TAG":  # ID3v1（末尾 128 字节）
        data = data[:-128]
    return data


def id3_with_garbage() -> bytes:
    """合法的 ID3v2.3 头（声明 512 字节标签）+ 垃圾"帧"数据。"""
    tag = rand_bytes(512, seed=7)
    header = b"ID3\x03\x00\x00" + _syncsafe(len(tag))
    return header + tag + rand_bytes(4096, seed=8)


def main() -> int:
    out = Path(sys.argv[1]).expanduser() if len(sys.argv) > 1 else DEFAULT_OUT
    if not MUSIC_SRC.is_dir():
        print(f"找不到真实音频目录：{MUSIC_SRC}")
        return 1
    if not GOOD_MP3.exists():
        print(f"找不到对照文件：{GOOD_MP3}")
        return 1

    out.mkdir(parents=True, exist_ok=True)

    # 场景 A / B 的坏文件
    (out / "01-bad-empty.mp3").write_bytes(b"")
    (out / "02-bad-random.mp3").write_bytes(rand_bytes(2048, seed=1))
    (out / "04-bad-id3-garbage.mp3").write_bytes(id3_with_garbage())
    (out / "05-bad-random-short.mp3").write_bytes(rand_bytes(512, seed=2))
    (out / "06-bad-empty-2.mp3").write_bytes(b"")

    # 对照文件（真实 mp3 完整拷贝，剥掉 ID3 → 标题回退为文件名，排序可控）
    good = strip_id3(GOOD_MP3.read_bytes())
    (out / "03-good-real.mp3").write_bytes(good)
    (out / "07-good-real-b.mp3").write_bytes(good)

    # 观察项
    with GOOD_MP3.open("rb") as f:
        (out / "08-obs-truncated.mp3").write_bytes(f.read(64 * 1024))
    if GOOD_FLAC.exists():
        with GOOD_FLAC.open("rb") as f:
            (out / "09-obs-flac-renamed.mp3").write_bytes(f.read(256 * 1024))
    else:
        print(f"（跳过 09：找不到 {GOOD_FLAC}）")

    print(f"已生成到 {out}\n")
    for path in sorted(out.iterdir()):
        print(f"  {path.name:28} {path.stat().st_size:>10,} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
