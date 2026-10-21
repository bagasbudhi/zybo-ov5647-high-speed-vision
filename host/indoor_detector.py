"""Laptop-side indoor object detector using a fine-tuned YOLO11 nano model.

The script supports normal image/video/webcam sources and the Bayer8 frame dumps
made by fpga/dump_vga_frame_jtag.tcl. Neural inference is laptop-side; it is not
part of the Zybo RTL bitstream.
"""

import argparse
import csv
from itertools import islice
import json
from pathlib import Path
import sys
import time

try:
    from ultralytics import YOLO
except ImportError:  # keep --help usable before installing optional ML packages
    YOLO = None


# Labels for the fine-tuned indoor dataset plus common COCO labels from the
# initial checkpoint. Names, not numeric IDs, are used so both checkpoints work.
TARGET_LABELS = {
    "person", "backpack", "bottle", "cup", "chair", "couch", "sofa",
    "potted plant", "bed", "dining table", "table", "TV", "tv", "laptop",
    "book", "lamp", "wardrobe", "window", "door", "photo frame",
}


def require_yolo():
    if YOLO is None:
        raise SystemExit(
            "Missing optional dependencies. Install them with: "
            "python -m pip install -r host/requirements-ml.txt"
        )


def load_bayer(path: Path, width: int, height: int, phase: str):
    """Return an RGB numpy image from one tightly-packed Bayer8 frame."""
    try:
        import numpy as np
    except ImportError as exc:
        raise SystemExit("Bayer input requires numpy; install host/requirements-ml.txt") from exc
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from bayer8_to_rgb import demosaic

    rgb = demosaic(path.read_bytes(), width, height, phase)
    return np.frombuffer(rgb, dtype=np.uint8).reshape(height, width, 3).copy()


def write_results(results, output_dir: Path, metrics_path: Path):
    output_dir.mkdir(parents=True, exist_ok=True)
    records = []
    inference_ms = []
    frame_count = 0
    for index, result in enumerate(results):
        frame_count += 1
        inference_ms.append(float(result.speed.get("inference", 0.0)))
        result.save(filename=str(output_dir / f"detection_{index:04d}.jpg"))
        if result.boxes is None:
            continue
        for box in result.boxes:
            cls_id = int(box.cls.item())
            class_name = result.names[cls_id]
            if class_name.casefold() not in {name.casefold() for name in TARGET_LABELS}:
                continue
            x1, y1, x2, y2 = [float(x) for x in box.xyxy[0].tolist()]
            records.append({
                "image": Path(str(result.path)).name,
                "class_id": cls_id,
                "class_name": class_name,
                "confidence": float(box.conf.item()),
                "x1": round(x1, 2), "y1": round(y1, 2),
                "x2": round(x2, 2), "y2": round(y2, 2),
            })
    metrics_path.parent.mkdir(parents=True, exist_ok=True)
    with metrics_path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=(
            "image", "class_id", "class_name", "confidence", "x1", "y1", "x2", "y2"
        ))
        writer.writeheader()
        writer.writerows(records)
    summary = {
        "images_processed": frame_count,
        "detections": len(records),
        "detections_by_class": {
            name: sum(row["class_name"].casefold() == name.casefold() for row in records)
            for name in sorted(TARGET_LABELS)
        },
        "annotated_dir": str(output_dir),
        "metrics_csv": str(metrics_path),
        "mean_model_inference_ms": round(sum(inference_ms) / len(inference_ms), 2) if inference_ms else 0.0,
    }
    print(json.dumps(summary, indent=2))
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    detect = sub.add_parser("detect", help="run indoor-object detection on image/video/webcam or Bayer8 dump")
    detect.add_argument("source", help="image, video, webcam index, or Bayer8 file")
    detect.add_argument("--model", default="yolo11n.pt", help="COCO-pretrained or fine-tuned YOLO checkpoint")
    detect.add_argument("--output", type=Path, default=Path("build/indoor_detections"))
    detect.add_argument("--metrics", type=Path, default=Path("build/indoor_detections.csv"))
    detect.add_argument("--confidence", type=float, default=0.25)
    detect.add_argument("--width", type=int, default=640, help="Bayer8 width")
    detect.add_argument("--height", type=int, default=480, help="Bayer8 height")
    detect.add_argument("--phase", choices=("BG", "GB", "GR", "RG"), default="BG")
    detect.add_argument("--bayer8", action="store_true", help="interpret source as packed Bayer8 raw frame")
    detect.add_argument("--show", action="store_true", help="display live webcam/video while detecting")
    detect.add_argument("--max-frames", type=int, default=0, help="stop video/webcam after N frames (0 means until input ends)")

    train = sub.add_parser("train", help="fine-tune on the public HomeObjects-3K indoor dataset")
    train.add_argument("--model", default="yolo11n.pt", help="COCO-pretrained model checkpoint")
    train.add_argument("--data", default="HomeObjects-3K.yaml", help="public indoor detection dataset; downloads on first run")
    train.add_argument("--epochs", type=int, default=5)
    train.add_argument("--imgsz", type=int, default=320)
    train.add_argument("--fraction", type=float, default=1.0, help="fraction of training split (0 < fraction <= 1)")
    train.add_argument("--device", default="cpu", help="cpu, 0, or another torch device selector")
    train.add_argument("--dataset-dir", type=Path, default=Path("build/datasets"), help="local destination for public dataset images and labels")
    train.add_argument("--project", default="runs/indoor")
    train.add_argument("--name", default="homeobjects3k_yolo11n")

    args = parser.parse_args()
    require_yolo()

    if args.command == "detect":
        model = YOLO(args.model)
        source = args.source
        if args.bayer8:
            source = load_bayer(Path(source), args.width, args.height, args.phase)
        elif isinstance(source, str) and source.isdigit():
            source = int(source)
        started = time.perf_counter()
        results = model.predict(
            source=source,
            conf=args.confidence,
            stream=True,
            show=args.show,
            verbose=False,
        )
        if args.max_frames:
            if args.max_frames < 0:
                parser.error("--max-frames must be zero or positive")
            results = islice(results, args.max_frames)
        summary = write_results(results, args.output, args.metrics)
        elapsed_ms = (time.perf_counter() - started) * 1000.0
        print(json.dumps({
            "wall_time_ms": round(elapsed_ms, 2),
            "approx_end_to_end_fps": round(summary["images_processed"] * 1000.0 / elapsed_ms, 2) if elapsed_ms else 0.0,
        }, indent=2))
        return

    if not 0 < args.fraction <= 1:
        parser.error("--fraction must be greater than 0 and at most 1")
    model = YOLO(args.model)
    from ultralytics.data import utils as data_utils
    args.dataset_dir.resolve().mkdir(parents=True, exist_ok=True)
    data_utils.DATASETS_DIR = args.dataset_dir.resolve()
    run_dir = Path(args.project).resolve()
    model.train(
        data=args.data,
        epochs=args.epochs,
        imgsz=args.imgsz,
        fraction=args.fraction,
        device=args.device,
        project=str(run_dir),
        name=args.name,
        seed=7,
        deterministic=True,
    )
    print(f"Fine-tuned checkpoint: {run_dir / args.name / 'weights' / 'best.pt'}")


if __name__ == "__main__":
    main()
