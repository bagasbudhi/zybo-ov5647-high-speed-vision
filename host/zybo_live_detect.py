"""Receive Bayer8 UDP frames from Zybo and run laptop-side YOLO detection."""

import argparse
import csv
import socket
import time
from pathlib import Path

import cv2
import numpy as np
from ultralytics import YOLO

from bayer8_to_rgb import demosaic
from protocol import FrameAssembler


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bind", default="0.0.0.0", help="listen on all laptop interfaces")
    parser.add_argument("--port", type=int, default=5005)
    parser.add_argument("--model", default="runs/indoor/homeobjects3k_yolo11n_320/weights/best.pt")
    parser.add_argument("--phase", choices=("BG", "GB", "GR", "RG"), default="BG")
    parser.add_argument("--confidence", type=float, default=0.25)
    parser.add_argument("--seconds", type=float, default=0, help="stop after N seconds (0 runs until q/Ctrl-C)")
    parser.add_argument("--save-dir", type=Path, default=Path("build/zybo_live"))
    parser.add_argument("--save-frames", action="store_true", help="save annotated frame JPEGs as well as the CSV")
    parser.add_argument("--no-display", action="store_true", help="save frames and CSV without opening a window")
    args = parser.parse_args()

    model_path = Path(args.model)
    if not model_path.is_file():
        parser.error(f"model checkpoint not found: {model_path}; train the model first or pass --model yolo11n.pt")
    model = YOLO(str(model_path))
    assembler = FrameAssembler(timeout_s=1.0, max_inflight=4)
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 8 * 1024 * 1024)
    sock.bind((args.bind, args.port))
    sock.settimeout(0.5)
    args.save_dir.mkdir(parents=True, exist_ok=True)
    csv_path = args.save_dir / "detections.csv"
    print(f"Listening for Zybo Bayer8 UDP on {args.bind}:{args.port}; model={model_path}", flush=True)
    print("Press q in the video window or Ctrl-C to stop.", flush=True)

    start = time.monotonic()
    frames = 0
    infer_ms_sum = 0.0
    packets = 0
    with csv_path.open("w", newline="", encoding="utf-8") as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=("frame_id", "timestamp_ns", "class", "confidence", "x1", "y1", "x2", "y2"))
        writer.writeheader()
        try:
            while not args.seconds or time.monotonic() - start < args.seconds:
                try:
                    packet, source = sock.recvfrom(2048)
                except socket.timeout:
                    continue
                packets += 1
                complete = assembler.push(packet)
                if complete is None:
                    continue
                frame_id, width, height, timestamp_ns, raw = complete
                bgr = cv2.cvtColor(np.frombuffer(demosaic(raw, width, height, args.phase), dtype=np.uint8)
                                   .reshape(height, width, 3), cv2.COLOR_RGB2BGR)
                t0 = time.perf_counter()
                result = model.predict(bgr, imgsz=320, conf=args.confidence, verbose=False)[0]
                infer_ms = (time.perf_counter() - t0) * 1000.0
                infer_ms_sum += infer_ms
                frames += 1
                annotated = result.plot()
                for box in result.boxes or []:
                    cls_id = int(box.cls.item())
                    x1, y1, x2, y2 = (float(v) for v in box.xyxy[0].tolist())
                    writer.writerow({"frame_id": frame_id, "timestamp_ns": timestamp_ns,
                                     "class": result.names[cls_id], "confidence": f"{float(box.conf.item()):.4f}",
                                     "x1": round(x1, 2), "y1": round(y1, 2),
                                     "x2": round(x2, 2), "y2": round(y2, 2)})
                csvfile.flush()
                elapsed = time.monotonic() - start
                fps = frames / elapsed if elapsed else 0.0
                cv2.putText(annotated, f"frame {frame_id} | {fps:.1f} FPS | infer {infer_ms:.1f} ms",
                            (8, 22), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 255, 255), 2)
                if args.save_frames:
                    cv2.imwrite(str(args.save_dir / f"frame_{frame_id:08d}.jpg"), annotated)
                if not args.no_display:
                    cv2.imshow("Zybo OV5647 live YOLO", annotated)
                    if cv2.waitKey(1) & 0xFF == ord("q"):
                        break
                print(f"frame={frame_id} size={width}x{height} src={source[0]} packets={packets} "
                      f"detect={len(result.boxes)} infer={infer_ms:.1f}ms avg_fps={fps:.2f} "
                      f"dropped={assembler.dropped_frames} bad={assembler.bad_packets}", flush=True)
        except KeyboardInterrupt:
            pass
        finally:
            sock.close()
            if not args.no_display:
                cv2.destroyAllWindows()
    elapsed = time.monotonic() - start
    print(f"Stopped: frames={frames} packets={packets} avg_infer_ms={infer_ms_sum / frames if frames else 0:.1f} "
          f"avg_fps={frames / elapsed if elapsed else 0:.2f} dropped={assembler.dropped_frames} "
          f"bad={assembler.bad_packets} csv={csv_path}")


if __name__ == "__main__":
    main()
