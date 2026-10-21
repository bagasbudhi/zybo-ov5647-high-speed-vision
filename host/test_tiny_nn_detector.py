import random
import unittest
from pathlib import Path

from host.tiny_nn_detector import detect, iou, load_model, synthetic_features


MODEL = Path(__file__).resolve().parents[1] / "models" / "tiny_patch_detector.json"


class TinyNeuralDetectorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model = load_model(MODEL)

    def test_held_out_synthetic_patch_metrics(self):
        rng = random.Random(121)
        samples = ([(synthetic_features(rng, True), 1) for _ in range(500)]
                   + [(synthetic_features(rng, False), 0) for _ in range(500)])
        threshold = 0.88
        tp = sum(self.model.score(features) >= threshold and label == 1
                 for features, label in samples)
        fp = sum(self.model.score(features) >= threshold and label == 0
                 for features, label in samples)
        fn = sum(self.model.score(features) < threshold and label == 1
                 for features, label in samples)
        self.assertGreaterEqual(tp, 495)
        self.assertEqual(fp, 0)
        self.assertLessEqual(fn, 5)

    def test_sliding_window_returns_target_box(self):
        width, height = 80, 64
        gray = bytearray([28] * (width * height))
        target = (32, 24, 48, 40)
        for y in range(target[1], target[3]):
            for x in range(target[0], target[2]):
                gray[y * width + x] = 230
        boxes = detect(bytes(gray), width, height, self.model, threshold=0.88, stride=4)
        self.assertTrue(boxes)
        self.assertGreater(iou(boxes[0][1], target), 0.4)


if __name__ == "__main__":
    unittest.main()
