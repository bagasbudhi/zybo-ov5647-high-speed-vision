"""Dependency-free tiny neural patch detector for OV5647 Bayer8 captures.

This is a laptop-side proof of concept. It does not run in the FPGA datapath.
The 16-8-1 MLP classifies sliding 24x24 grayscale windows; positives are
synthetic centered bright targets and negatives include off-center targets.
"""

from __future__ import annotations

import argparse
import json
import math
import random
import struct
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable
import zlib

try:
    from .bayer8_to_rgb import demosaic
except ImportError:  # Running as: python host/tiny_nn_detector.py
    from bayer8_to_rgb import demosaic


PATCH = 24
GRID = 4
HIDDEN = 8


@dataclass
class TinyMLP:
    w1: list[list[float]]
    b1: list[float]
    w2: list[float]
    b2: float

    def score(self, features: list[float]) -> float:
        hidden = [max(0.0, self.b1[j] + sum(w * x for w, x in zip(self.w1[j], features)))
                  for j in range(HIDDEN)]
        logit = self.b2 + sum(w * h for w, h in zip(self.w2, hidden))
        if logit >= 0:
            return 1.0 / (1.0 + math.exp(-min(logit, 60.0)))
        e = math.exp(max(logit, -60.0))
        return e / (1.0 + e)

    def to_dict(self) -> dict:
        return {"format": "tiny-mlp-patch-detector-v1", "patch": PATCH,
                "grid": GRID, "hidden": HIDDEN, "w1": self.w1,
                "b1": self.b1, "w2": self.w2, "b2": self.b2}

    @classmethod
    def from_dict(cls, data: dict) -> "TinyMLP":
        if (data.get("format"), data.get("patch"), data.get("grid"), data.get("hidden")) != (
                "tiny-mlp-patch-detector-v1", PATCH, GRID, HIDDEN):
            raise ValueError("Unsupported model format or dimensions")
        return cls(data["w1"], data["b1"], data["w2"], data["b2"])


def load_model(path: Path) -> TinyMLP:
    return TinyMLP.from_dict(json.loads(path.read_text(encoding="utf-8")))


def save_model(model: TinyMLP, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(model.to_dict(), indent=2) + "\n", encoding="utf-8")


def synthetic_features(rng: random.Random, positive: bool) -> list[float]:
    """Make pooled 4x4 features for a centered target or a hard negative."""
    background = rng.uniform(0.04, 0.32)
    bright = rng.uniform(0.62, 1.0)
    if positive:
        cx, cy = 12 + rng.uniform(-2.0, 2.0), 12 + rng.uniform(-2.0, 2.0)
        rw, rh = rng.uniform(7.0, 17.0), rng.uniform(7.0, 17.0)
    elif rng.random() < 0.68:
        # Hard negatives: a bright target exists, but away from window center.
        cx, cy = rng.choice((rng.uniform(2, 7), rng.uniform(17, 22))), rng.uniform(3, 21)
        if rng.random() < 0.5:
            cx, cy = rng.uniform(3, 21), rng.choice((rng.uniform(2, 7), rng.uniform(17, 22)))
        rw, rh = rng.uniform(6.0, 17.0), rng.uniform(6.0, 17.0)
    else:
        cx, cy, rw, rh = 12.0, 12.0, 0.0, 0.0
        bright = background

    x0, x1 = cx - rw / 2, cx + rw / 2
    y0, y1 = cy - rh / 2, cy + rh / 2
    features = []
    gradient = rng.uniform(-0.05, 0.05)
    for gy in range(GRID):
        for gx in range(GRID):
            left, right = gx * 6.0, (gx + 1) * 6.0
            top, bottom = gy * 6.0, (gy + 1) * 6.0
            overlap_x = max(0.0, min(right, x1) - max(left, x0))
            overlap_y = max(0.0, min(bottom, y1) - max(top, y0))
            fraction = overlap_x * overlap_y / 36.0
            value = background + fraction * (bright - background)
            value += gradient * ((gx - 1.5) / 1.5) + rng.uniform(-0.055, 0.055)
            features.append(min(1.0, max(0.0, value)))
    return features


def train_model(seed: int = 5647, epochs: int = 32, examples_per_epoch: int = 1200,
                learning_rate: float = 0.045) -> TinyMLP:
    """Train a small ReLU MLP on reproducible synthetic target patches."""
    rng = random.Random(seed)
    w1 = [[rng.uniform(-0.35, 0.35) for _ in range(GRID * GRID)] for _ in range(HIDDEN)]
    b1 = [rng.uniform(-0.1, 0.1) for _ in range(HIDDEN)]
    w2 = [rng.uniform(-0.25, 0.25) for _ in range(HIDDEN)]
    b2 = 0.0

    for _ in range(epochs):
        order = list(range(examples_per_epoch))
        rng.shuffle(order)
        for index in order:
            label = 1.0 if rng.random() < 0.5 else 0.0
            x = synthetic_features(rng, bool(label))
            z = [b1[j] + sum(w1[j][i] * x[i] for i in range(GRID * GRID))
                 for j in range(HIDDEN)]
            h = [max(0.0, value) for value in z]
            logit = b2 + sum(w2[j] * h[j] for j in range(HIDDEN))
            probability = 1.0 / (1.0 + math.exp(-max(-30.0, min(30.0, logit))))
            error = probability - label
            old_w2 = w2[:]
            for j in range(HIDDEN):
                w2[j] -= learning_rate * error * h[j]
            b2 -= learning_rate * error
            for j in range(HIDDEN):
                if z[j] > 0.0:
                    delta = error * old_w2[j]
                    for i in range(GRID * GRID):
                        w1[j][i] -= learning_rate * delta * x[i]
                    b1[j] -= learning_rate * delta
    return TinyMLP(w1, b1, w2, b2)


def patch_features(gray: bytes, width: int, height: int, x0: int, y0: int,
                   window: int = PATCH) -> list[float]:
    if window != PATCH or x0 < 0 or y0 < 0 or x0 + window > width or y0 + window > height:
        raise ValueError("Patch lies outside image or has unsupported size")
    features = []
    cell = window // GRID
    for gy in range(GRID):
        for gx in range(GRID):
            total = 0
            for yy in range(y0 + gy * cell, y0 + (gy + 1) * cell):
                row = yy * width + x0 + gx * cell
                total += sum(gray[row:row + cell])
            features.append(total / (cell * cell * 255.0))
    return features


def iou(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> float:
    x0, y0 = max(a[0], b[0]), max(a[1], b[1])
    x1, y1 = min(a[2], b[2]), min(a[3], b[3])
    intersection = max(0, x1 - x0) * max(0, y1 - y0)
    area_a = max(1, a[2] - a[0]) * max(1, a[3] - a[1])
    area_b = max(1, b[2] - b[0]) * max(1, b[3] - b[1])
    return intersection / (area_a + area_b - intersection)


def detect(gray: bytes, width: int, height: int, model: TinyMLP,
           threshold: float = 0.88, stride: int = 8, max_boxes: int = 10
           ) -> list[tuple[float, tuple[int, int, int, int]]]:
    if len(gray) != width * height:
        raise ValueError("Grayscale image size does not match width and height")
    candidates = []
    for y in range(0, height - PATCH + 1, stride):
        for x in range(0, width - PATCH + 1, stride):
            score = model.score(patch_features(gray, width, height, x, y))
            if score >= threshold:
                candidates.append((score, (x, y, x + PATCH, y + PATCH)))
    candidates.sort(reverse=True, key=lambda item: item[0])
    selected = []
    for candidate in candidates:
        if all(iou(candidate[1], old[1]) < 0.25 for old in selected):
            selected.append(candidate)
            if len(selected) == max_boxes:
                break
    return selected


def bayer8_to_gray(raw: bytes, width: int, height: int, phase: str) -> bytes:
    rgb = demosaic(raw, width, height, phase)
    gray = bytearray(width * height)
    for p in range(width * height):
        i = 3 * p
        gray[p] = (rgb[i] + 2 * rgb[i + 1] + rgb[i + 2]) // 4
    return bytes(gray)


def save_annotated_png(gray: bytes, width: int, height: int,
                       boxes: Iterable[tuple[float, tuple[int, int, int, int]]],
                       output: Path) -> None:
    rgb = bytearray(width * height * 3)
    for p, value in enumerate(gray):
        rgb[3 * p:3 * p + 3] = bytes((value, value, value))
    for _, (x0, y0, x1, y1) in boxes:
        for thickness in range(2):
            for x in range(x0, x1):
                for y in (y0 + thickness, y1 - 1 - thickness):
                    if 0 <= x < width and 0 <= y < height:
                        i = (y * width + x) * 3
                        rgb[i:i + 3] = b"\xff\x00\x00"
            for y in range(y0, y1):
                for x in (x0 + thickness, x1 - 1 - thickness):
                    if 0 <= x < width and 0 <= y < height:
                        i = (y * width + x) * 3
                        rgb[i:i + 3] = b"\xff\x00\x00"
    write_png(bytes(rgb), output, width, height)


def _png_chunk(kind: bytes, data: bytes) -> bytes:
    payload = kind + data
    return struct.pack(">I", len(data)) + payload + struct.pack(">I", zlib.crc32(payload))


def write_png(rgb: bytes, output: Path, width: int, height: int) -> None:
    if len(rgb) != width * height * 3:
        raise ValueError("RGB image size does not match width and height")
    rows = b"".join(b"\x00" + rgb[y * width * 3:(y + 1) * width * 3]
                    for y in range(height))
    png = (b"\x89PNG\r\n\x1a\n"
           + _png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
           + _png_chunk(b"IDAT", zlib.compress(rows))
           + _png_chunk(b"IEND", b""))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(png)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    train = sub.add_parser("train", help="train the synthetic patch classifier")
    train.add_argument("--model", type=Path, default=Path("models/tiny_patch_detector.json"))
    train.add_argument("--seed", type=int, default=5647)
    train.add_argument("--epochs", type=int, default=32)
    train.add_argument("--examples-per-epoch", type=int, default=1200)
    run = sub.add_parser("detect", help="detect centered bright targets in a Bayer8 raw frame")
    run.add_argument("raw8", type=Path)
    run.add_argument("--model", type=Path, default=Path("models/tiny_patch_detector.json"))
    run.add_argument("--output", type=Path, default=Path("build/tiny_nn_detection.png"))
    run.add_argument("--width", type=int, default=640)
    run.add_argument("--height", type=int, default=480)
    run.add_argument("--phase", choices=("BG", "GB", "GR", "RG"), default="BG")
    run.add_argument("--threshold", type=float, default=0.88)
    args = parser.parse_args()
    if args.command == "train":
        model = train_model(args.seed, args.epochs, args.examples_per_epoch)
        save_model(model, args.model)
        print(f"MODEL={args.model}")
        return
    raw = args.raw8.read_bytes()
    if len(raw) != args.width * args.height:
        raise SystemExit(f"Expected {args.width * args.height} Bayer8 bytes, got {len(raw)}")
    gray = bayer8_to_gray(raw, args.width, args.height, args.phase)
    boxes = detect(gray, args.width, args.height, load_model(args.model), args.threshold)
    save_annotated_png(gray, args.width, args.height, boxes, args.output)
    print(f"FRAME={args.width}x{args.height} DETECTIONS={len(boxes)}")
    for score, (x0, y0, x1, y1) in boxes:
        print(f"SCORE={score:.4f} BBOX={x0},{y0},{x1},{y1}")
    print(f"OUTPUT={args.output}")


if __name__ == "__main__":
    main()
