"""Replace the first defense take's color-cycling plate and ghost residue."""
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import prepare as original
import produce as p

if __name__ == '__main__':
 out=p.SOURCE_DIR/'defend_h3_v2';out.mkdir(exist_ok=False)
 prompt=(original.IDENTITY+
  'Slowly lower into a firm defensive crouch. Keep the same facing throughout. Both feet remain planted, both knees bend steadily and the left elbow draws the woven shield up in front of the torso. '
  'Keep the round front of the shield visible while raising it. The right hand carries the club upright beside the right shoulder. '
  'Complete the lowering motion gradually, then hold the supplied final crouched guard. '
  'Locked elevated three-quarter orthographic camera, unchanged body size and centered root. '
  'Uniform pure saturated green RGB0,255,0 background throughout every frame. Keep this green plate completely static, even while the man moves. '
  'Full body, equipment and small helmet branches visible. Crisp continuous elbow and knee movement.').strip()
 c=dict(unit_id=original.UID,clip='defend',canvas=[960,640],anchor=[470,560],scale=.5,key_rgb=[0,255,0],seed=2026093401,
  references=[original.ref(13),original.ref(8)],guides=[[80,1]],last=1,prompt=prompt,
  tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
 p.prepare(out,c);bands=[]
 for i in range(2):
  a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float);m=binary_erosion(a[:,:,3]>240,iterations=3)
  bands.append(float((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[m].max()))
 c['protected_foreground_chroma']=max(0,int(max(bands))+2)
 c['foreground_measurement']=dict(rule='Eroded opaque green-minus-max(red,blue), plus two.',per_guide_max=bands)
 c['correction_reason']='First take cycles its plate and leaves visible background ghosts during active defense. Replace this action with a static green plate and planted-foot gradual brace; preserve rejected original.'
 p.write(out/'config.json',c)
