"""Keep original rainbow glass colours; no green/magenta despill of real panes."""
import argparse,json,shutil
from PIL import Image
import numpy as np
import produce as p

def run(take):
    out=p.SOURCE_DIR/take;manifest=json.loads((out/'matte.json').read_bytes())
    target=out/'edge_matte';target.mkdir(exist_ok=True);hashes=[]
    for i,digest in enumerate(manifest['rgba_sha256']):
        source=out/'matte'/f'rgba_{i:03}.png';assert p.sha(source)==digest
        file=target/source.name
        if file.exists():assert p.sha(file)==digest
        else:shutil.copyfile(source,file)
        assert np.array_equal(np.asarray(Image.open(file)),np.asarray(Image.open(source)))
        hashes.append(p.sha(file))
    assert len(hashes)==124
    p.write(out/'edge_matte.json',dict(frames=124,fps=24,rgba_sha256=hashes,source_matte_sha256=p.sha(out/'matte.json'),tool_sha256=p.sha(__file__),recipe='Exact original semantic matte pixels; no colour-based edge despill because iridescent glass legitimately includes cyan, magenta, green and blue. Measured dark plate is unmixed solely by segment.py at soft alpha. All alpha, geometry and RGB match the original matte byte for byte.'))
    p.review(out,json.loads((out/'config.json').read_bytes()))
    print('ORIGINAL_GLASS_MATTE_PRESERVED',take,124,flush=True)
