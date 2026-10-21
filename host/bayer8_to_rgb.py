"""Reference implementation and PNG writer for the FPGA's causal Bayer8 RGB block."""

import argparse
from pathlib import Path
import struct
import zlib


def cfa_color(x: int, y: int, phase: str) -> int:
    """Return 0=R, 1=G, 2=B for BGGR, GBRG, GRBG, or RGGB."""
    patterns = {
        "BG": ((2, 1), (1, 0)),
        "GB": ((1, 2), (0, 1)),
        "GR": ((1, 0), (2, 1)),
        "RG": ((0, 1), (1, 2)),
    }
    return patterns[phase][y & 1][x & 1]


def demosaic(raw: bytes, width: int, height: int, phase: str = "BG") -> bytes:
    """Match rtl/axis_bayer_demosaic.v, including its replicated-value border fallback."""
    if len(raw) != width * height:
        raise ValueError(f"Expected {width * height} Bayer bytes, got {len(raw)}")
    if phase not in {"BG", "GB", "GR", "RG"}:
        raise ValueError("phase must be BG, GB, GR, or RG")

    rgb = bytearray(width * height * 3)
    for y in range(height):
        for x in range(width):
            sample = raw[y * width + x]
            values = [sample if cfa_color(x, y, phase) == channel else 0 for channel in range(3)]
            counts = [1 if cfa_color(x, y, phase) == channel else 0 for channel in range(3)]
            neighbors = []
            if x > 0:
                neighbors.append((x - 1, y, raw[y * width + x - 1]))
            if y > 0:
                neighbors.append((x, y - 1, raw[(y - 1) * width + x]))
            if x > 0 and y > 0:
                neighbors.append((x - 1, y - 1, raw[(y - 1) * width + x - 1]))
            for nx, ny, value in neighbors:
                channel = cfa_color(nx, ny, phase)
                values[channel] += value
                counts[channel] += 1
            for channel in range(3):
                if counts[channel] == 0:
                    values[channel] = sample
                elif counts[channel] > 1:
                    values[channel] = (values[channel] + counts[channel] // 2) // counts[channel]
            offset = (y * width + x) * 3
            rgb[offset : offset + 3] = bytes(values)
    return bytes(rgb)


def _png_chunk(kind: bytes, data: bytes) -> bytes:
    payload = kind + data
    return struct.pack(">I", len(data)) + payload + struct.pack(">I", zlib.crc32(payload))


def write_png(rgb: bytes, output: Path, width: int, height: int) -> None:
    if len(rgb) != width * height * 3:
        raise ValueError(f"Expected {width * height * 3} RGB bytes, got {len(rgb)}")
    rows = b"".join(b"\x00" + rgb[y * width * 3 : (y + 1) * width * 3] for y in range(height))
    png = (
        b"\x89PNG\r\n\x1a\n"
        + _png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + _png_chunk(b"IDAT", zlib.compress(rows))
        + _png_chunk(b"IEND", b"")
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(png)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="tightly packed Bayer8 frame dump")
    parser.add_argument("output", type=Path, help="output RGB PNG")
    parser.add_argument("--width", type=int, default=640)
    parser.add_argument("--height", type=int, default=480)
    parser.add_argument("--phase", choices=("BG", "GB", "GR", "RG"), default="BG")
    args = parser.parse_args()
    rgb = demosaic(args.source.read_bytes(), args.width, args.height, args.phase)
    write_png(rgb, args.output, args.width, args.height)
    print(args.output)


if __name__ == "__main__":
    main()
