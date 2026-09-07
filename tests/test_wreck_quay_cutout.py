import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("cutout", ROOT / "tools/repair_wreck_quay_cutout.py")
cutout = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cutout)


class WreckQuayCutoutTests(unittest.TestCase):
    def test_before_fails_for_both_demonstrated_defects(self):
        report = cutout.inspect_image(cutout.SOURCE)
        self.assertFalse(report["ok"])
        self.assertEqual(report["divider_pixels"], 1238)
        self.assertEqual(report["magenta_pixels"], 6122)

    def test_runtime_is_clean_and_trimmed_matches(self):
        self.assertTrue(cutout.inspect_image(cutout.RUNTIME)["ok"])
        self.assertEqual(cutout.RUNTIME.read_bytes(), cutout.TRIMMED.read_bytes())

    def test_exact_original_pixels_and_canvas_are_preserved(self):
        with Image.open(cutout.SOURCE) as source, Image.open(cutout.RUNTIME) as runtime:
            self.assertEqual(runtime.size, source.size)
            repaired = cutout.repair_image(source)
            self.assertEqual(repaired.tobytes(), runtime.tobytes())
            unchanged = 0
            for y in range(120,390):
                for x in range(108,402):
                    r,g,b,a = source.getpixel((x,y))
                    if a and min(r,b)-g<=8:
                        self.assertEqual(runtime.getpixel((x,y)), (r,g,b,a))
                        unchanged += 1
            self.assertGreater(unchanged,40000)

    def test_registration_provenance_and_original_identity(self):
        manifest = json.loads((cutout.SOURCE.parent / "manifest.json").read_text())
        art = json.loads((ROOT / "art/overworld/manifest.json").read_text())["object_assets"]["mapobj_wreck_quay"]
        mapping = json.loads((ROOT / "art/overworld/map_object_sprites.json").read_text())["object_sprite_mappings"]["object_wreck_quay"]
        self.assertEqual(mapping["asset_id"], "mapobj_wreck_quay")
        self.assertEqual(art["assigned_map_object_id"], "object_wreck_quay")
        self.assertEqual(art["path"], manifest["runtime"])
        self.assertEqual(art["source_generated_atlas"], manifest["original_generated_atlas"])
        self.assertEqual(hashlib.sha256(cutout.SOURCE.read_bytes()).hexdigest(), manifest["input_sha256"])
        self.assertEqual(hashlib.sha256(cutout.RUNTIME.read_bytes()).hexdigest(), manifest["runtime_sha256"])
        self.assertEqual(art["runtime_sha256"], manifest["runtime_sha256"])

    def test_processing_is_idempotent_and_rejects_wrong_format(self):
        with Image.open(cutout.RUNTIME) as runtime:
            self.assertEqual(cutout.repair_image(runtime).tobytes(), runtime.tobytes())
            with self.assertRaises(ValueError):
                cutout.repair_image(runtime.convert("RGB"))


if __name__ == "__main__":
    unittest.main()
