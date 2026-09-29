"""After two backdrop failures, add a painted midpoint and dense plate controls."""
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import prepare as r
import produce as p

out=p.SOURCE_DIR/'attack_raise_h3_v4';out.mkdir(exist_ok=False)
mid=dict(name='painted_half_raise',source=(p.SOURCE_DIR/'raise_mid_v1.png').relative_to(p.ROOT).as_posix(),rects=[[0,0,1536,1024]],anchor=[688,896],scale=.3125,alpha_noise_cutoff=8)
c=dict(unit_id=r.UID,clip='attack',canvas=[960,640],anchor=[430,560],scale=.5,key_rgb=[0,0,255],seed=2026092934,
 references=[r.ref(17),mid,r.ref(4)],guides=[[22,1],[50,2],[86,2]],last=2,
 prompt=(r.IDENTITY+'A single continuous preparation for a melee bow shove. Immediately raise the left-hand bow diagonally toward the chest while the right hand moves in to join the central handle. '
 'Smoothly pass through the halfway pose, widen the feet and bend knees, then finish in the final two-handed upright guard. '
 'The right hand travels toward the wooden grip and never draws the string. No arrow, shooting or actual shove; no sudden pose swaps. '+r.PLATE).strip(),
 tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
p.prepare(out,c);excess=[]
for i in range(3):
 a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
 excess.append(float((a[:,:,2]-np.maximum(a[:,:,0],a[:,:,1]))[mask].max()))
c['protected_foreground_chroma']=max(0,int(max(excess))+2)
c['foreground_measurement']=dict(rule='Opaque eroded guide interior blue excess plus two.',per_guide_max=excess)
p.write(out/'config.json',c)
p.write(p.SOURCE_DIR/'attack_raise_h3_v3'/'rejection.json',dict(status='rejected',reason='Background alternates magenta, yellow-green and red. Endpoint-only controls failed twice across different plate colors; do not relax extraction. Add an original painted halfway guide and intermediate control points on the blue plate.'))
