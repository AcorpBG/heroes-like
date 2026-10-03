"""Verify retained original RGB and unchanged opaque matte pixels on the CPU."""
import argparse, hashlib, json
import av
import numpy as np
from PIL import Image
import produce as p

def verify(take):
    folder = p.SOURCE_DIR / take
    original = json.loads((folder / 'original.json').read_bytes())
    matte = json.loads((folder / 'matte.json').read_bytes())
    assert p.sha(folder / 'original_lossless.mkv') == original['sha256']
    assert original['frames'] == 124 and original['size'] == [960, 640]
    checks, opaque_pixels = 0, 0
    with av.open(str(folder / 'original_lossless.mkv')) as container:
        frames = list(container.decode(video=0))
    assert len(frames) == 124
    for index, frame in enumerate(frames):
        rgb = np.asarray(frame.to_image().convert('RGB'))
        assert hashlib.sha256(rgb.tobytes()).hexdigest() == original['decoded_rgb_sha256'][index]
        path = folder / matte.get('matte_directory', 'matte') / f'rgba_{index:03}.png'
        assert p.sha(path) == matte['rgba_sha256'][index]
        rgba = np.asarray(Image.open(path).convert('RGBA'))
        assert rgba.shape == (640, 960, 4)
        opaque = rgba[:, :, 3] == 255
        assert np.array_equal(rgba[:, :, :3][opaque], rgb[opaque]), (take, index)
        opaque_pixels += int(opaque.sum())
        checks += 3
    result = dict(take=take, original_rgb_frames=124, matte_frames=124,
                  original_lossless_sha256=original['sha256'], checks=checks,
                  opaque_original_pixels_verified=opaque_pixels, failures=[])
    p.write(folder / 'original_pixel_proof.json', result)
    print(json.dumps(result), flush=True)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('takes', nargs='+')
    for take in parser.parse_args().takes:
        verify(take)
