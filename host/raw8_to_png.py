"""Convert a tightly packed 8-bit grayscale frame dump to PNG (stdlib only)."""

import argparse
from pathlib import Path
import struct
import zlib


def chunk(kind: bytes, data: bytes) -> bytes:
    payload = kind + data
    return struct.pack(">I", len(data)) + payload + struct.pack(">I", zlib.crc32(payload))


def convert(source: Path, output: Path, width: int, height: int) -> None:
    pixels = source.read_bytes()
    expected = width * height
    if len(pixels) != expected:
        raise ValueError(f"Expected {expected} bytes, got {len(pixels)}")
    scanlines = b"".join(
        b"\x00" + pixels[y * width : (y + 1) * width]
        for y in range(height)
    )
    image = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 0, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(scanlines))
        + chunk(b"IEND", b"")
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(image)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--width", type=int, default=640)
    parser.add_argument("--height", type=int, default=480)
    args = parser.parse_args()
    convert(args.source, args.output, args.width, args.height)
    print(args.output)


if __name__ == "__main__":
    main()
