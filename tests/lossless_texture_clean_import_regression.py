#!/usr/bin/env python3
"""Exercise real first-import/changed-option paths on copies of original rasters."""
import argparse
import json
from pathlib import Path
import shutil
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import prepare_lossless_texture_imports as importer


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    sources = ["art/towns/runtime/scene_layers/faction_veilmourn/building_veilmourn_harpoon_gantry.png",
               "art/overworld/runtime/terrain_tiles/base_generated_v2/underground.png"]
    hashes = {p: importer.sha(ROOT / p) for p in sources}
    with tempfile.TemporaryDirectory(prefix="heroes-lossless-first-import-") as directory:
        root = Path(directory)
        (root / "project.godot").write_text("config_version=5\n[application]\nconfig/name=\"Lossless first-import test\"\n[rendering]\n" + importer.FACTOR + "=100.0\n")
        shutil.copyfile(ROOT / "export_presets.cfg", root / "export_presets.cfg")
        for source in sources:
            target = root / source
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / source, target)
        # One exact tracked import configuration; one genuinely unseen raster.
        shutil.copyfile(ROOT / (sources[0] + ".import"), root / (sources[0] + ".import"))
        first = importer.prepare(root, report=args.output / "first.json")
        cached = importer.prepare(root, report=args.output / "cached.json")
        options = root / (sources[0] + ".import")
        options.write_text(options.read_text().replace("mipmaps/generate=true", "mipmaps/generate=false"))
        changed = importer.prepare(root, report=args.output / "changed-options.json")
        assert first["reimported"] == 2 and all(r["baseline"] == "fresh_default_import" for r in first["rows"])
        assert cached["reimported"] == 0 and cached["cache_hits"] == 2
        assert changed["reimported"] == 1 and changed["cache_hits"] == 1
        assert changed["rows"][0]["baseline"] == "fresh_default_import" and changed["rows"][0]["decoded"]["mipmaps"] == 0
        assert hashes == {p: importer.sha(root / p) for p in sources}
    assert hashes == {p: importer.sha(ROOT / p) for p in sources}
    result = {"ok": True, "real_first_imports": 2, "cached_hits": 2, "changed_option_default_baseline": True,
              "original_rasters_unchanged": hashes, "first_seconds": first["seconds"], "cached_seconds": cached["seconds"]}
    (args.output / "report.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
