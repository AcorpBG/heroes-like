"""Replace the rejected opening smear while preserving the valid shove."""
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import prepare as r
import produce as p

out=p.SOURCE_DIR/'attack_raise_h3_v2';out.mkdir(exist_ok=False)
c=dict(unit_id=r.UID,clip='attack',canvas=[960,640],anchor=[430,560],scale=.5,key_rgb=[0,0,255],seed=2026092931,
 references=[r.ref(17),r.ref(4)],guides=[],last=1,
 prompt=(r.IDENTITY+'Slowly prepare a melee shove, without performing the shove. Begin moving immediately: the left elbow bends to raise the short bow from the waist to a vertical guard in front of the chest. The free right hand moves smoothly across the abdomen to join the left hand at the central grip. Gradually widen the stance and bend both knees, keeping boots on the ground. End holding the vertical bow with two hands, elbows bent, exactly in the final windup pose. Every intermediate frame retains the original face, body and wooden bow geometry. No string drawing, shooting, lunging, motion smears or abrupt pose changes.'+r.PLATE).strip(),
 tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
p.prepare(out,c);excess=[]
for i in range(2):
 a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
 excess.append(float((a[:,:,2]-np.maximum(a[:,:,0],a[:,:,1]))[mask].max()))
c['protected_foreground_chroma']=max(0,int(max(excess))+2)
c['foreground_measurement']=dict(rule='Opaque interiors eroded three pixels; maximum blue excess plus two.',per_guide_max=excess)
p.write(out/'config.json',c)
p.write(p.SOURCE_DIR/'attack_h3_v1'/'rejection.json',dict(status='full_take_rejected_valid_intervals_retained',bad_frames=[23,24],reason='Opening transition smears face/body and changes bow geometry before snapping upright. Generate a slower separately guided raise; inspect its join into the valid shove and recovery.'))
