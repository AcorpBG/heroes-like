"""Protect measured original costume bands without relaxing plate separation."""
import json
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import produce as p

if __name__=='__main__':
    path=p.SOURCE_DIR/'foreground_measurement.json'
    rows=json.loads(path.read_bytes())
    for take in ['attack_h3_v2','ranged_release_h3_v2','death_h3_v2','hit_h3_v2']:
        out=p.SOURCE_DIR/take;c=json.loads((out/'config.json').read_bytes())
        green=c['key_rgb']==[0,255,0];guides=[]
        for guide in sorted(out.glob('guide_*_rgba.png')):
            a=np.asarray(Image.open(guide).convert('RGBA'),dtype=np.float32)
            mask=binary_erosion(a[:,:,3]>=240,iterations=2)
            chroma=a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]) if green else np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1]
            guides.append(dict(guide=guide.name,opaque_pixels=int(mask.sum()),max_foreground_chroma=float(chroma[mask].max())))
        protected=max(26,int(max(g['max_foreground_chroma'] for g in guides))+2)
        assert 250-protected>=80
        settings=dict(protected_foreground_chroma=protected,key_palette='green' if green else 'magenta',rule='Eroded original opaque guide palette plus2; flat corner spread<=10 and background chroma>=80 remain required.')
        p.write(out/'extraction_settings.json',settings)
        rows[take]=dict(guides=guides,**settings)
        print(take,protected)
    p.write(path,rows)
