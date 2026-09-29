"""Original Saltpan Buckler guides with fixed anatomical scale and green plate."""
import json
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_erosion
import produce as p

UID = 'unit_neutral_saltpan_bucklers'
BASE = p.ROOT / 'art/animation/source/poses' / UID
PACK = json.loads((BASE / 'packing.json').read_bytes())
IDENTITY = ('One original Saltpan Buckler, a stocky adult bearded human soldier. '
 'Red headband over a trailing ivory headwrap, ivory scarf, red cloth sleeves and skirt strips, '
 'crossed brown chest straps, patchwork ivory leg wrappings, brown leather boots and metal kneecaps. '
 'Exactly two arms and two legs. His right hand at screen left firmly holds ONE short brown wooden club by its handle. '
 'His left forearm at screen right carries ONE round pale salt-stained wooden buckler with a dark central boss and radial leather straps. '
 'Preserve the round shield, club length, beard, face, outfit and original adult proportions. ')
PLATE = (' Locked elevated three-quarter orthographic camera at the reference angle, fixed anatomical scale and centered root. '
 'The entire actor and equipment stay visible. Uniform pure saturated green RGB0,255,0 fills all surrounding pixels throughout. '
 'Keep clothing and equipment attached, physical joints and stable foot contacts. ')
TAKES = {
 'move_h3_v1': ([13], [], 0, 'Walk steadily in place for three reciprocal gait cycles. Alternate both boots through heel contact, weight-bearing, passing and lift. Carry the club loosely pointed down, with a small natural arm counter-swing, and carry the shield upright. The scarf and skirt respond subtly to the steps. Finish in the starting stance.'),
 'attack_h3_v1': ([13,4,5], [[28,1],[54,2]], 0, 'Perform one forceful club strike. Raise the club above the right shoulder with the elbow bent, then step and swing the same club down and forward across the body. Keep the shield protecting the left side. Recover the arm and step smoothly back to the starting ready stance. Maintain one continuous grip on the handle.'),
 'hit_h3_v1': ([13,9], [[42,1]], 0, 'Perform one startled backward flinch as a solitary actor. Shoulders recoil, the torso leans back and both knees yield while each hand keeps its equipment. Then regain balance, straighten and return to the starting ready stance. The full scene contains only this soldier against the uniform green plate.'),
 'defend_h3_v1': ([13,8], [[49,1],[90,1]], 1, 'Brace behind the round shield. Bend both knees, raise the shield over the chest and bring the club forearm inward alongside it. End holding the low protective guard with both boots grounded. Keep the two objects separate and in their original hands.'),
 'cast_h3_v1': ([13,16], [[44,1],[75,1]], 0, 'Give a physical readiness signal: draw the club hand across the belt toward the shield edge, bring the elbow inward and nod firmly. Briefly hold the guarded gesture, then lower the club hand back to the original ready stance. This is a nonmagical soldier signaling support to allies.'),
 'death_h3_v1': ([13,10,12], [[35,1]], 2, 'Perform one continuous collapse. Knees buckle, descend onto both knees, then tip onto the left side with head moving toward screen left and boots toward screen right. The club and shield lower with their hands to the ground. Finish lying still in the supplied grounded side-rest pose. Maintain continuous body motion through the fall.'),
}

def ref(i):
 f = dict(PACK['frames'][i])
 f['source'] = (BASE / f['source']).relative_to(p.ROOT).as_posix()
 f['alpha_noise_cutoff'] = 8
 return f

if __name__ == '__main__':
 thumbs = []
 for n,(name,(indices,guides,last,action)) in enumerate(TAKES.items()):
  out = p.SOURCE_DIR / name
  out.mkdir(exist_ok=False)
  c = dict(unit_id=UID,clip=name.split('_')[0],canvas=[960,640],anchor=[470,560],scale=.5,
   key_rgb=[0,255,0],seed=2026093010+n,references=[ref(i) for i in indices],guides=guides,last=last,
   prompt=(IDENTITY+action+PLATE).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.prepare(out,c)
  bands=[]
  for i in range(len(indices)):
   im=Image.open(out/f'guide_{i}_rgba.png');a=np.asarray(im).astype(float)
   mask=binary_erosion(a[:,:,3]>240,iterations=3)
   bands.append(float((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[mask].max()))
   thumbs.append((name+':'+str(i),im.copy()))
  c['protected_foreground_chroma']=max(0,int(max(bands))+2)
  c['foreground_measurement']=dict(rule='Eroded opaque green-minus-max(red,blue) maximum plus two across original guides.',per_guide_max=bands)
  p.write(out/'config.json',c)
 p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=list(TAKES),preserved_accepted_clips=['idle'],
  visual_review=dict(status='pending',notes='Review club/shield grips, reciprocal gait, recovery, physical support, continuous fall, alpha and native scale. Preserve reviewed eight-pose idle.')))
 sheet=Image.new('RGB',(1440,((len(thumbs)+3)//4)*260),(42,48,43));draw=ImageDraw.Draw(sheet)
 for j,(name,im) in enumerate(thumbs):
  im.thumbnail((356,237));x,y=j%4*360,j//4*260;sheet.paste(im,(x,y+23),im);draw.text((x+4,y+4),name)
 sheet.save(p.ROOT/'.artifacts/saltpan_h3/guides.png')
