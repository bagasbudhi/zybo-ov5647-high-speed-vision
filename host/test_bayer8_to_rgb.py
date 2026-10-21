import unittest

from bayer8_to_rgb import demosaic, write_png


class BayerReferenceTests(unittest.TestCase):
    def test_constant_rgb_scene_for_all_cfa_phases(self):
        width = height = 6
        phases = {
            "BG": ((20, 100), (100, 200)),
            "GB": ((100, 20), (200, 100)),
            "GR": ((100, 200), (20, 100)),
            "RG": ((200, 100), (100, 20)),
        }
        expected = bytes((200, 100, 20))
        for phase, cfa in phases.items():
            with self.subTest(phase=phase):
                raw = bytes(cfa[y & 1][x & 1] for y in range(height) for x in range(width))
                rgb = demosaic(raw, width, height, phase)
                # Interior locations have all three colors available to the causal filter.
                for y in range(1, height):
                    for x in range(1, width):
                        offset = (y * width + x) * 3
                        self.assertEqual(rgb[offset : offset + 3], expected)

    def test_rejects_wrong_frame_size(self):
        with self.assertRaises(ValueError):
            demosaic(b"\x00", 2, 2)

    def test_writes_rgb_png(self):
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "frame.png"
            write_png(bytes((1, 2, 3)) * 4, path, 2, 2)
            self.assertEqual(path.read_bytes()[:8], b"\x89PNG\r\n\x1a\n")


if __name__ == "__main__":
    unittest.main()
