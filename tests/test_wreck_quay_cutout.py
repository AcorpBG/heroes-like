import importlib.util
from pathlib import Path
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("cutout", ROOT / "tools/repair_wreck_quay_cutout.py")
cutout = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cutout)


class WreckQuayCutoutTests(unittest.TestCase):
    def test_runtime_is_clean(self):
        self.assertTrue(cutout.inspect_image(cutout.RUNTIME)["ok"])

    def test_processing_is_idempotent_and_rejects_wrong_format(self):
        with Image.open(cutout.RUNTIME) as runtime:
            self.assertEqual(cutout.repair_image(runtime).tobytes(), runtime.tobytes())
            with self.assertRaises(ValueError):
                cutout.repair_image(runtime.convert("RGB"))


if __name__ == "__main__":
    unittest.main()
