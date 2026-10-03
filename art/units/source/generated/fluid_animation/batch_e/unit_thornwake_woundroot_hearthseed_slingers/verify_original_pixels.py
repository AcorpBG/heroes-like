"""Check every completed original RGB/RGBA pose before visual selection or cleanup."""
import argparse
import hashlib
import json
import re

import av
import numpy as np
from PIL import Image

import produce as p


def read(path):
    return json.loads(path.read_bytes())


def verify(take):
    assert re.fullmatch(r"[a-z]+_h3_v[0-9]+", take), take
    out = p.SOURCE_DIR / take
    config = read(out / "config.json")
    original = read(out / "original.json")
    matte = read(out / "matte.json")
    assert config["unit_id"] == p.SOURCE_DIR.name
    assert original["frames"] == matte["frames"] == 124
    assert len(original["decoded_rgb_sha256"]) == len(matte["rgba_sha256"]) == 124
    assert p.sha(out / "original_lossless.mkv") == original["sha256"], take
    count = 0
    with av.open(str(out / "original_lossless.mkv")) as video:
        for index, frame in enumerate(video.decode(video=0)):
            assert index < 124, (take, index)
            rgb = np.asarray(frame.to_image().convert("RGB"))
            assert hashlib.sha256(rgb.tobytes()).hexdigest() == original["decoded_rgb_sha256"][index], (take, index, "RGB hash")
            path = out / "matte" / f"rgba_{index:03}.png"
            assert p.sha(path) == matte["rgba_sha256"][index], (take, index, "RGBA hash")
            rgba = np.asarray(Image.open(path).convert("RGBA"))
            assert rgba.shape[:2] == rgb.shape[:2] == tuple(reversed(config["canvas"])), (take, index, "Canvas")
            opaque = rgba[:, :, 3] == 255
            assert opaque.any() and np.array_equal(rgba[:, :, :3][opaque], rgb[opaque]), (take, index, "Opaque subject RGB")
            count += 1
    assert count == 124, (take, count)
    return dict(frames=count, all_rgb_hashes=True, all_matte_hashes=True,
                all_opaque_rgb_coordinates_unchanged=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("takes", nargs="+")
    parser.add_argument("--record", action="store_true")
    args = parser.parse_args()
    results = {take: verify(take) for take in args.takes}
    if args.record:
        path = p.SOURCE_DIR / "source_reviews.json"
        reviews = read(path)
        reviews.setdefault("source_pixel_verification", {}).update(results)
        p.write(path, reviews)
    print("ALL_ORIGINAL_PIXELS_VERIFIED", results, flush=True)
