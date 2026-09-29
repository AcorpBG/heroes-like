"""Correct the failed blue-to-olive backdrop without modifying creature pixels."""
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import prepare as r
import produce as p

out=p.SOURCE_DIR/'attack_raise_h3_v3';out.mkdir(exist_ok=False)
c=dict(unit_id=r.UID,clip='attack',canvas=[960,640],anchor=[430,560],scale=.5,key_rgb=[255,0,255],seed=2026092933,
 references=[r.ref(17),r.ref(4)],guides=[],last=1,
 prompt=('Flat uniform saturated MAGENTA chroma-key background remains unchanged throughout the video. '+r.IDENTITY+
 'Slowly prepare a melee shove without performing the shove. Begin moving immediately: bend the left elbow to raise the short bow from the waist into the final vertical chest guard. '
 'Move the free right hand smoothly across the abdomen to join the left hand at the central grip. Gradually widen the stance and bend both knees, keeping boots grounded. '
 'Hold the completed two-handed guard. Preserve the full gradual arm and knee articulation, face and rigid bow. No arrow, string drawing, lunge, blur, scene change or sudden pose change. '+
 r.PLATE.replace('BLUE','MAGENTA')+' The empty background is pure bright magenta, never green, olive, brown or scenery.').strip(),
 tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
p.prepare(out,c);excess=[]
for i in range(2):
 a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
 excess.append(float((np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1])[mask].max()))
c['protected_foreground_chroma']=max(0,int(max(excess))+2)
c['foreground_measurement']=dict(rule='Opaque interiors eroded three pixels; maximum magenta excess plus two.',per_guide_max=excess)
p.write(out/'config.json',c)
p.write(p.SOURCE_DIR/'attack_raise_h3_v2'/'rejection.json',dict(status='rejected',reason='Frames15-100 replace blue with dark olive backdrop (49.5,74,26), overlapping clothing colors during the entire active raise. Cannot safely matte or omit this interval. Correct the chroma plate and keep original geometry/scale guides.'))

guard=p.SOURCE_DIR/'defend_h3_v2'
p.write(guard/'selection.json',dict(source_frames=list(range(4,47)),frame_msec=32,review_note='All124 chronological frames and enlarged4/10/16/22/28/34/40/46 inspected. Continuous bow raise, right-arm chest guard and knee/hip lowering, correct two-limb anatomy, stable grip and held crouch. Native-scale review pending.'))
p.build(guard,p.json.loads((guard/'config.json').read_bytes()))
