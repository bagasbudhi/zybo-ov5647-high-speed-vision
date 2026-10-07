"""Receive Bayer8 video from the Zybo or display synthetic UDP test frames."""
import argparse
import socket
import time

from protocol import FrameAssembler


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bind", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=5005)
    parser.add_argument("--bayer", choices=["BG", "GB", "RG", "GR"], default="BG")
    args = parser.parse_args()
    try:
        import cv2
        import numpy as np
    except ImportError as exc:
        raise SystemExit("Install viewer dependencies: python -m pip install opencv-python numpy") from exc
    codes = {"BG": cv2.COLOR_BAYER_BG2BGR, "GB": cv2.COLOR_BAYER_GB2BGR,
             "RG": cv2.COLOR_BAYER_RG2BGR, "GR": cv2.COLOR_BAYER_GR2BGR}
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((args.bind, args.port))
    sock.settimeout(0.2)
    assembler = FrameAssembler()
    shown = 0
    start = time.monotonic()
    print(f"Listening on {args.bind}:{args.port}; press q in the video window to quit")
    while True:
        try:
            datagram, _ = sock.recvfrom(2048)
        except socket.timeout:
            if cv2.waitKey(1) & 0xff == ord("q"):
                break
            continue
        result = assembler.push(datagram)
        if result is None:
            continue
        frame_id, width, height, timestamp_ns, raw = result
        bayer = np.frombuffer(raw, dtype=np.uint8).reshape(height, width)
        rgb = cv2.cvtColor(bayer, codes[args.bayer])
        shown += 1
        elapsed = max(time.monotonic() - start, 0.001)
        overlay = f"frame {frame_id}  {shown/elapsed:.1f} fps  lost {assembler.dropped_frames}  bad {assembler.bad_packets}"
        cv2.putText(rgb, overlay, (8, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 255, 0), 1)
        cv2.imshow("Zybo OV5647", rgb)
        if cv2.waitKey(1) & 0xff == ord("q"):
            break
    sock.close()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
