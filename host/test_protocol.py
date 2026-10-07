import unittest

from protocol import FrameAssembler, decode, fragment


class ProtocolTests(unittest.TestCase):
    def test_reordered_frame(self):
        frame = bytes(range(256)) * 12
        packets = list(fragment(frame, 64, 48, 7, 10, 1234))
        assembler = FrameAssembler()
        result = None
        for packet in reversed(packets):
            result = assembler.push(packet, now=1.0) or result
        self.assertEqual(result, (7, 64, 48, 1234, frame))
        self.assertEqual(assembler.complete_frames, 1)

    def test_crc_and_timeout(self):
        packets = list(fragment(bytes(3072), 64, 48, 1, 0))
        broken = bytearray(packets[0]); broken[-1] ^= 1
        assembler = FrameAssembler(timeout_s=0.1)
        self.assertIsNone(assembler.push(broken, now=1.0))
        self.assertEqual(assembler.bad_packets, 1)
        assembler.push(packets[0], now=1.0)
        assembler.push(packets[1], now=1.2)
        self.assertEqual(assembler.dropped_frames, 1)
        self.assertEqual(decode(packets[0]).chunk_index, 0)


if __name__ == "__main__":
    unittest.main()
