"""Replace color-cycling support and death plates using fixed green guides."""
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import prepare as original
import produce as p

TAKES={
 'cast_h3_v2':([13,16],[[48,1],[70,1]],0,
  'Give one practical readiness signal to allies. Slowly bend the right elbow to lift the club hand slightly forward and outward beside the shoulder. Briefly hold that compact gesture, then deliberately lower the hand back to its original ready height. Keep the woven shield steady on the left arm and both boots planted. This is a physical, nonmagical militia signal. Show clear elbow and wrist motion during both raise and return.'),
 'death_h3_v2':([13,10,11,12],[[40,1],[80,2]],3,
  'Perform one slow continuous defeat collapse under body weight. Both knees gradually buckle and contact the ground while the shoulders droop. From the kneeling pose, tip toward screen right onto the right hip and forearm into the supplied side-fall pose. Then settle fully onto the right side, head to screen right and boots to screen left, into the supplied motionless final corpse. The body stays in contact with the ground through knees, hip and side. Settle the club beside the right hand and the woven shield across the torso. Preserve both legs and both arms with natural bending throughout.')
}

if __name__=='__main__':
 for n,(name,(indices,guides,last,action)) in enumerate(TAKES.items()):
  out=p.SOURCE_DIR/name;out.mkdir(exist_ok=False)
  prompt=(original.IDENTITY+action+
   ' Locked elevated three-quarter orthographic camera at the reference angle, unchanged body scale and centered root. '
   'Full body and all equipment visible. Uniform pure saturated green RGB0,255,0 background throughout every frame. '
   'Keep this green plate completely static while the man moves. Continuous physical joints and stable material colors.').strip()
  c=dict(unit_id=original.UID,clip=name.split('_')[0],canvas=[960,640],anchor=[470,560],scale=.5,key_rgb=[0,255,0],seed=2026093402+n,
   references=[original.ref(i) for i in indices],guides=guides,last=last,prompt=prompt,
   tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.prepare(out,c);bands=[]
  for i in range(len(indices)):
   a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
   bands.append(float((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[mask].max()))
  c['protected_foreground_chroma']=max(0,int(max(bands))+2)
  c['foreground_measurement']=dict(rule='Eroded opaque green-minus-max(red,blue), plus two.',per_guide_max=bands)
  c['correction_reason']='Replace unsafe color-cycling background; preserve first take unchanged. Death also receives an intermediate side-fall guide for grounded collapse.'
  p.write(out/'config.json',c)
