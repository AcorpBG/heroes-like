"""Remove incompatible sprint/passing guides and require uninterrupted foot cycles."""
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import prepare as r
import produce as p

out=p.SOURCE_DIR/'move_h3_v2';out.mkdir(exist_ok=False)
c=dict(unit_id=r.UID,clip='move',canvas=[960,640],anchor=[440,560],scale=.5,key_rgb=[255,0,255],seed=2026092961,
 references=[r.ref(13)],guides=[],last=0,
 prompt=(r.IDENTITY+'Begin immediately walking in place at a steady pace, completing at least THREE uninterrupted reciprocal walking cycles. '
 'The near right leg and far left leg alternate heel contact, weight bearing, passing and toe lift. One boot supports the body as the other steps. '
 'Keep the original elevated three-quarter body orientation toward screen right throughout, without turning frontward or sideways. '
 'Keep both short blades lowered outside the legs with small natural elbow swings. No stops or held passing poses, no sprinting, jumping, flying, tiptoe hopping or forward translation. '
 'The camera and body root stay fixed while the arms and legs articulate. Return to the original ready stance only at the very end. '+r.PLATE).strip(),
 tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
p.prepare(out,c)
a=np.asarray(Image.open(out/'guide_0_rgba.png')).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
excess=float((np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1])[mask].max())
c['protected_foreground_chroma']=max(0,int(excess)+2);c['foreground_measurement']=dict(rule='Eroded opaque magenta excess plus two.',per_guide_max=[excess])
p.write(out/'config.json',c)
p.write(p.SOURCE_DIR/'move_h3_v1'/'rejection.json',dict(status='rejected',reason='The sprint-contact and more frontal passing guides produce a run-to-march posture change and long held passing phases. Replace with a consistent accepted ready reference and uninterrupted reciprocal gait; do not trim or retime away the inconsistent orientation.'))

out=p.SOURCE_DIR/'attack_h3_v1'
indices=list(range(23,46))+[49,55,62,68,74,78]+list(range(80,105))
p.write(out/'selection.json',dict(source_frames=indices,frame_msec=32,contact_frame=indices.index(43),review_note='All124 source frames and enlarged23/27/32/38/41/43/45/80/84/87/94/104 inspected. Two original blades retain their hands through windup, diagonal slash, crossed recovery and return. Long held contact shortened using only selected original frames; native-scale review pending.'))
p.build(out,p.json.loads((out/'config.json').read_bytes()))
