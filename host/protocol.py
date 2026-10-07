"""Version 1 UDP video protocol. All fields are network byte order.

The 36-byte header is: magic[4], version[1], format[1], flags[2],
frame_id[4], sequence[4], width[2], height[2], chunk_index[2],
chunk_count[2], timestamp_ns[8], crc32[4]. CRC covers header without CRC
followed by payload. Format 1 is one 8-bit Bayer sample per pixel.
"""
from __future__ import annotations

from dataclasses import dataclass
import struct
import time
import zlib

MAGIC = b"ZCAM"
VERSION = 1
FORMAT_BAYER8 = 1
MAX_PAYLOAD = 1400
_BASE = struct.Struct("!4sBBHIIHHHHQ")
_CRC = struct.Struct("!I")
HEADER_SIZE = _BASE.size + _CRC.size


@dataclass(frozen=True)
class Packet:
    frame_id: int
    sequence: int
    width: int
    height: int
    chunk_index: int
    chunk_count: int
    timestamp_ns: int
    payload: bytes
    pixel_format: int = FORMAT_BAYER8
    flags: int = 0


def encode(packet: Packet) -> bytes:
    if not (0 < packet.width <= 4096 and 0 < packet.height <= 4096):
        raise ValueError("invalid dimensions")
    if not (0 < packet.chunk_count <= 65535 and 0 <= packet.chunk_index < packet.chunk_count):
        raise ValueError("invalid chunk index/count")
    if not (0 < len(packet.payload) <= MAX_PAYLOAD):
        raise ValueError("invalid payload length")
    base = _BASE.pack(MAGIC, VERSION, packet.pixel_format, packet.flags,
                      packet.frame_id, packet.sequence, packet.width,
                      packet.height, packet.chunk_index, packet.chunk_count,
                      packet.timestamp_ns)
    return base + _CRC.pack(zlib.crc32(base + packet.payload)) + packet.payload


def decode(data: bytes) -> Packet:
    if len(data) <= HEADER_SIZE or len(data) > HEADER_SIZE + MAX_PAYLOAD:
        raise ValueError("invalid datagram length")
    base = data[:_BASE.size]
    magic, version, fmt, flags, frame_id, sequence, width, height, index, count, timestamp = _BASE.unpack(base)
    if magic != MAGIC or version != VERSION or fmt != FORMAT_BAYER8:
        raise ValueError("unsupported packet")
    crc, = _CRC.unpack(data[_BASE.size:HEADER_SIZE])
    payload = data[HEADER_SIZE:]
    if zlib.crc32(base + payload) != crc:
        raise ValueError("CRC mismatch")
    packet = Packet(frame_id, sequence, width, height, index, count, timestamp, payload, fmt, flags)
    if width == 0 or height == 0 or width > 4096 or height > 4096 or count == 0 or index >= count:
        raise ValueError("invalid frame metadata")
    return packet


def fragment(frame: bytes, width: int, height: int, frame_id: int,
             sequence_start: int, timestamp_ns: int | None = None):
    if len(frame) != width * height:
        raise ValueError("frame length does not match dimensions")
    if timestamp_ns is None:
        timestamp_ns = time.time_ns()
    count = (len(frame) + MAX_PAYLOAD - 1) // MAX_PAYLOAD
    for index in range(count):
        payload = frame[index * MAX_PAYLOAD:(index + 1) * MAX_PAYLOAD]
        yield encode(Packet(frame_id, (sequence_start + index) & 0xffffffff,
                            width, height, index, count, timestamp_ns, payload))


class FrameAssembler:
    def __init__(self, timeout_s: float = 0.5, max_inflight: int = 4):
        self.timeout_s = timeout_s
        self.max_inflight = max_inflight
        self.pending: dict[int, dict] = {}
        self.dropped_frames = 0
        self.bad_packets = 0
        self.complete_frames = 0

    def push(self, data: bytes, now: float | None = None):
        if now is None:
            now = time.monotonic()
        for frame_id in list(self.pending):
            if now - self.pending[frame_id]["first"] > self.timeout_s:
                del self.pending[frame_id]
                self.dropped_frames += 1
        try:
            packet = decode(data)
        except ValueError:
            self.bad_packets += 1
            return None
        entry = self.pending.get(packet.frame_id)
        metadata = (packet.width, packet.height, packet.chunk_count, packet.timestamp_ns)
        if entry is None:
            if len(self.pending) >= self.max_inflight:
                oldest = min(self.pending, key=lambda k: self.pending[k]["first"])
                del self.pending[oldest]
                self.dropped_frames += 1
            entry = {"first": now, "metadata": metadata, "chunks": {}}
            self.pending[packet.frame_id] = entry
        if entry["metadata"] != metadata:
            self.bad_packets += 1
            return None
        entry["chunks"][packet.chunk_index] = packet.payload
        if len(entry["chunks"]) != packet.chunk_count:
            return None
        frame = b"".join(entry["chunks"][i] for i in range(packet.chunk_count))
        del self.pending[packet.frame_id]
        if len(frame) != packet.width * packet.height:
            self.bad_packets += 1
            return None
        self.complete_frames += 1
        return packet.frame_id, packet.width, packet.height, packet.timestamp_ns, frame
