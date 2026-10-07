"""Send moving synthetic Bayer frames to test the transport and viewer."""
import argparse
import socket
import time

from protocol import fragment


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=5005)
    parser.add_argument("--frames", type=int, default=300)
    args = parser.parse_args()
    width, height = 640, 480
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sequence = 0
    for frame_id in range(args.frames):
        frame = bytearray(width * height)
        bar = (frame_id * 5) % width
        for y in range(height):
            for x in range(width):
                frame[y * width + x] = 230 if bar <= x < bar + 60 else (x // 4 + y // 4) & 0xff
        for datagram in fragment(bytes(frame), width, height, frame_id, sequence):
            sock.sendto(datagram, (args.host, args.port))
            sequence = (sequence + 1) & 0xffffffff
        time.sleep(1 / 15)
    sock.close()


if __name__ == "__main__":
    main()
