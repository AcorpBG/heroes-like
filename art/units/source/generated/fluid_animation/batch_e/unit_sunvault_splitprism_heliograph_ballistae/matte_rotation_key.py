"""One original key's pinned semantic matte, inside its own shared GPU lease."""
import json
from PIL import Image
import produce as p
import segment


def main():
    folder=p.SOURCE_DIR/'rolling_rotation_key_v4'
    generation=json.loads((folder/'generation.json').read_bytes())
    file=folder/'original.png'
    assert p.sha(file)==generation['original_sha256']
    assert not (folder/'matte.png').exists(), 'Preserve existing extraction; review before rebuilding'
    net=segment.model()
    original=Image.open(file).convert('RGB')
    rgba,detail=segment.extract(net,original)
    rgba.save(folder/'matte.png')
    p.write(folder/'matte.json',dict(source_sha256=p.sha(file),rgba_sha256=p.sha(folder/'matte.png'),model_manifest=json.loads((segment.BASE/'model_manifest.json').read_bytes()),background=detail,recipe='Same pinned BiRefNet semantic mask and soft plate unmix as video sources; opaque RGB retained, all original coordinates and dimensions retained. No redraw, wheel rotation or pose synthesis.',tool_sha256=p.sha(p.Path(segment.__file__)),review='pending personal native registration and original-edge review'))
    print('ONE_ORIGINAL_WHEEL_KEY_MATTED; CPU_REVIEW_REQUIRED_BEFORE_GENERATION',flush=True)


if __name__=='__main__':main()
