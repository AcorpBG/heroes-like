"""Remove measured green/magenta plate excess from two-pixel matte boundaries."""
import argparse,json
import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt
import produce as p

def run(take):
    out=p.SOURCE_DIR/take;original=json.loads((out/'matte.json').read_bytes())
    target=out/'edge_matte';target.mkdir(exist_ok=True);hashes=[];details=[]
    for i,sha in enumerate(original['rgba_sha256']):
        source=out/'matte'/f'rgba_{i:03}.png';assert p.sha(source)==sha
        before=np.array(Image.open(source).convert('RGBA'));after=before.copy()
        edge=(before[:,:,3]>=8)&(distance_transform_edt(before[:,:,3]>=8)<=2)
        rgb=before[:,:,:3].astype(np.int16);r,g,b=rgb[:,:,0],rgb[:,:,1],rgb[:,:,2]
        green=edge&(g-np.maximum(r,b)>24)
        magenta=edge&(np.minimum(r,b)-g>24)
        excess=np.maximum(0,np.minimum(r,b)-g)
        after[:,:,1][green]=np.maximum(r,b)[green]
        after[:,:,0][magenta]=(r-excess)[magenta]
        after[:,:,2][magenta]=(b-excess)[magenta]
        assert np.array_equal(before[:,:,3],after[:,:,3])
        assert np.array_equal(before[~edge],after[~edge])
        file=target/source.name;Image.fromarray(after).save(file)
        hashes.append(p.sha(file));details.append(dict(green_pixels=int(green.sum()),magenta_pixels=int(magenta.sum()),alpha_and_geometry_unchanged=True,interior_rgb_unchanged=True))
    assert len(hashes)==124
    p.write(out/'edge_matte.json',dict(frames=124,fps=24,rgba_sha256=hashes,source_matte_sha256=p.sha(out/'matte.json'),source_tool_sha256=p.sha(p.SOURCE_DIR/'segment.py'),tool_sha256=p.sha(p.SOURCE_DIR/'edge_despill.py'),recipe='Only within two original pixels of alpha>=8 boundary: green excess g-max(r,b)>24 is neutralized to max(r,b); magenta excess min(r,b)-g>24 is subtracted equally from r,b. Preserve exact alpha/geometry and every interior source RGB pixel; original red gauges/brass untouched. No painted anatomy, stabilization or interpolation.',frame_details=details))
    p.review(out,json.loads((out/'config.json').read_bytes()))
    print('EDGE_DESPILLED',take,len(hashes),flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('takes',nargs='+');args=parser.parse_args()
    for take in args.takes:run(take)
