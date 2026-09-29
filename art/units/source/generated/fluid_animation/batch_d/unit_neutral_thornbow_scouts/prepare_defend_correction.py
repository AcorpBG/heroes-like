"""Replace instant intermediate-guide cuts with a continuous endpoint brace."""
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import prepare as r
import produce as p

out=p.SOURCE_DIR/'defend_h3_v2';out.mkdir(exist_ok=False)
c=dict(unit_id=r.UID,clip='defend',canvas=[960,640],anchor=[430,560],scale=.5,key_rgb=[0,0,255],seed=2026092932,
 references=[r.ref(17),r.ref(8)],guides=[],last=1,
 prompt=(r.IDENTITY+'One slow continuous defensive duck from standing to the final crouch. Begin moving immediately. Raise the left-hand bow vertically beside the face while the right forearm folds protectively across the chest. Both knees bend gradually and the hips descend, with the right knee lowering toward the floor and the left boot supporting her weight. Retain the anatomical body size while crouching. End in the final low brace and hold it. Show the complete joint motion, not a cut between poses. No shooting, string drawing, attacking, scene cut, camera motion, disappearing limbs or sudden pose changes.'+r.PLATE).strip(),
 tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
p.prepare(out,c);excess=[]
for i in range(2):
 a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
 excess.append(float((a[:,:,2]-np.maximum(a[:,:,0],a[:,:,1]))[mask].max()))
c['protected_foreground_chroma']=max(0,int(max(excess))+2)
c['foreground_measurement']=dict(rule='Opaque interiors eroded three pixels; maximum blue excess plus two.',per_guide_max=excess)
p.write(out/'config.json',c)
p.write(p.SOURCE_DIR/'defend_h3_v1'/'rejection.json',dict(status='rejected',reason='Near-static holds separated by abrupt jumps25-to26 and65-to66; no continuous brace transition. Replace with endpoint-only guidance and an explicit continuous joint-motion prompt.'))
