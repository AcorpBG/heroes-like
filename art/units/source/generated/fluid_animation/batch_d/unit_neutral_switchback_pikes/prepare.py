"""Original Switchback Pikes guides, with consistent anatomy and a rigid pike."""
import json
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import binary_erosion
import produce as p

UID='unit_neutral_switchback_pikes'
BASE=p.ROOT/'art/animation/source/poses'/UID
PACK=json.loads((BASE/'packing.json').read_bytes())
IDENTITY=('ONE original adult male Switchback Pike mountain guide, elevated three-quarter view facing screen right. '
 'He has a short dark beard, olive broad-brimmed hat with a red-orange feather, green scarf and green-edged gray poncho, gray trousers, brown leather gloves and bracers, brown heavy spiked hiking boots. '
 'Preserve the brown backpack, rolled blanket, rope coil, belt pouches and small hanging metal cup. '
 'Exactly two arms, two hands and two legs. He carries ONE long rigid orange-brown wooden pike: one large silver leaf spearhead with two small backward hooks, metal shaft collars, and one small silver butt spike at the opposite end. '
 'Keep the shaft straight and continuous, both ends distinct and visible, and each glove connected to its proper arm. No shield, second spear, flag, sword, shortening, stretching or rubber shaft. '
 'Preserve original face, adult proportions, painted fantasy texture, camera and equipment. ')
PLATE=(' Locked orthographic camera, fixed anatomical scale and centered root. Entire figure, both pike ends, hat and boots stay within the frame. '
 'Uniform pure saturated BLUE background for every frame; no scene, floor, shadow, gradient, color changes, camera motion, glow, projectile or magic. '
 'Move joints naturally while maintaining stable grips and coherent ground support. ')

def ref(i):
 f=dict(PACK['frames'][i]);name=f['source'];f['source']=(BASE/name).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
 # Match the accepted idle's head-to-boot anatomy, using one scale per painting.
 # Legacy action paintings are taller than the later accepted idle painting.
 if name=='alpha/poses.png':f['scale']=.52
 elif name.startswith('continuity-alpha/'):f['scale']=.39
 return f

TAKES={
 'move_h3_v1':([13],[],0,'Walk in place through THREE continuous reciprocal gait cycles. Alternate both boots through heel contact, support, passing and toe lift. Keep the pike in its original diagonal carry position with both hands gripping it; small natural shoulder and elbow motion follows the steps. Keep the body root centered and facing right, not turning or drifting. Do not stop mid-cycle. Return to the starting ready pose only at the very end.'),
 'attack_h3_v1':([13,4,5,6],[[28,1],[55,2],[86,3]],0,'Perform ONE controlled two-handed pike thrust toward screen right. First raise and reorient the rigid pike over the shoulders into a horizontal forward guard, sliding the gloves along the shaft only as needed to obtain the original windup grips. Then step forward, extend the arms and thrust the large spearhead right. Retract the pike and recover the step; smoothly return to the original diagonal ready carry. Both hands remain attached to the same continuous wooden shaft. The large spearhead must rotate with the pike, never turn into the butt spike. No spinning flourish, throwing, repeated strike or shaft teleportation.'),
 'hit_h3_v1':([13,9],[[40,1]],0,'React once with a visible backward shoulder and torso recoil, knees yielding to maintain balance. Keep the pike secure with the supporting hand; the other glove briefly opens as in the original recoil reference, then regrips. Return naturally to the original ready stance. There is NO visible incoming object, flash, impact beam, blood or particle effect. No fall or attack.'),
 'defend_h3_v1':([13,8],[[45,1],[90,1]],1,'Immediately lower into the original protective crouch while maintaining the diagonal pike with both hands. Knees bend, hips descend and elbows brace the rigid shaft. Hold the final low crouched guard. No attack, full kneeling collapse, weapon flip or return to standing.'),
 'cast_h3_v1':([13],[],0,'Perform one clear nonmagical readiness signal: keep both boots planted, lift the diagonally held pike upward a handspan using the shoulders and elbows, tighten both grips and nod once to an ally. Pause briefly with the raised pike, then lower it and relax into the original ready stance. Keep the same large spearhead at the upper left and small butt spike at lower right throughout. This is a physical support salute, not an attack, spell or whole-body bounce.'),
 'death_h3_v1':([13,10,11,12],[[32,1],[74,2]],3,'Collapse continuously with the original equipment. Knees buckle, lower onto a knee, then tip sideways toward screen right. The pike lowers with the body, rotating naturally onto the ground, never changing ends or passing through the torso. Finish lying with the head at screen right and feet at screen left, one hand resting on the grounded pike in front. Backpack and hat stay attached. No recovery, floating limbs, extra weapon or scene cut.'),
}

if __name__=='__main__':
 thumbs=[]
 for n,(name,(indices,guides,last,action)) in enumerate(TAKES.items()):
  out=p.SOURCE_DIR/name;out.mkdir(exist_ok=False)
  c=dict(unit_id=UID,clip=name.split('_')[0],canvas=[960,640],anchor=[420,560],scale=.5,key_rgb=[0,0,255],blue_chroma_axis='blue_minus_max_red_green',seed=2026092970+n,references=[ref(i) for i in indices],guides=guides,last=last,prompt=(IDENTITY+action+PLATE).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.prepare(out,c);bands=[]
  for i in range(len(indices)):
   im=Image.open(out/f'guide_{i}_rgba.png');a=np.asarray(im).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
   bands.append(float((a[:,:,2]-np.maximum(a[:,:,0],a[:,:,1]))[mask].max()));thumbs.append((name+':'+str(i),im.copy()))
  c['protected_foreground_chroma']=max(0,int(max(bands))+2);c['foreground_measurement']=dict(rule='Eroded opaque blue minus max(red,green) maximum plus two across original guides.',per_guide_max=bands)
  p.write(out/'config.json',c)
 p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=list(TAKES),preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Inspect rigid pike and grip continuity, full original chronology, gait seam, anatomy/scale, alpha and native battle phases. Preserve eight reviewed articulated idle poses/map.')))
 sheet=Image.new('RGB',(1440,((len(thumbs)+3)//4)*260),(42,48,43));draw=ImageDraw.Draw(sheet)
 for j,(name,im) in enumerate(thumbs):
  im.thumbnail((356,237));x,y=j%4*360,j//4*260;sheet.paste(im,(x,y+23),im);draw.text((x+4,y+4),name)
 sheet.save(p.ROOT/'.artifacts/switchback_h3/guides.png')
