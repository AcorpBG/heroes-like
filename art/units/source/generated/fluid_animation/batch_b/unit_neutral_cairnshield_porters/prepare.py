"""Cairnshield Porter original guides at one consistent anatomical scale."""
import json
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_erosion
import produce as p

UID='unit_neutral_cairnshield_porters'
BASE=p.ROOT/'art/animation/source/poses'/UID
PACK=json.loads((BASE/'packing.json').read_bytes())
IDENTITY=('One original Cairnshield Porter, an adult human traveler with dark tied-back hair, a blue scarf, yellow and blue tabard, gray padded trousers, blue metal forearm guards and brown boots. '
 'Exactly two arms and two legs. One hand holds the vertical grip of ONE tall rectangular pale stone-faced wooden shield with black iron bands and crossed rope. '
 'A large wooden backpack frame holds beige sacks, coiled rope and one rolled blue blanket. Preserve the pack, shield pattern, face and stocky adult proportions. '
 'Original elevated three-quarter painted fantasy camera, same view as the reference. The shield stays one rigid object, attached to the gripping hand. ')
PLATE=(' Locked orthographic camera and fixed anatomical scale, centered body root, entire shield, backpack and boots in frame. '
 'The background remains uniform pure saturated MAGENTA in every frame. Only the body and carried equipment move. '
 'Maintain the original materials and costume colors, clear limb joints, physical weight and stable ground contacts. ')
TAKES={
 'move_h3_v1':([13],[],0,'Walk in place through three continuous reciprocal gait cycles under the heavy backpack. Alternate the two boots through contact, weight support, passing and lift. The free arm counter-swings gently and the shield arm steadies the upright shield. Keep the torso centered at the same camera angle. End in the initial ready stance.'),
 'attack_h3_v1':([13,4,5],[[28,1],[55,2]],0,'Perform one forceful shield bash. Wind the shoulder back, step forward and extend the shield arm to drive the broad shield outward into the supplied contact pose. Then retract the shield, recover the step and return smoothly to the starting ready posture. Keep the same shield hand, one rigid shield and the backpack strapped to the body throughout.'),
 'hit_h3_v1':([13,9],[[42,1]],0,'A solitary actor performs one startled backward flinch. Shoulders recoil, the torso leans back and knees yield; the free hand opens briefly for balance. Keep the shield secured in its proper hand. Regain balance and return to the initial ready posture. The complete scene consists only of the porter and the uniform color plate.'),
 'defend_h3_v1':([13,8],[[48,1],[90,1]],1,'Lower into a protective shield brace. Bend both knees and lean the shoulders behind the tall upright shield, bringing the free forearm inward for support. Finish holding the supplied low guarded pose with both boots grounded and the backpack still strapped on.'),
 'cast_h3_v1':([13,16],[[44,1],[75,1]],0,'Give a clear physical support signal to an ally: keep the shield steady in its original hand, bring the free gloved hand up to the chest strap, tighten the strap with a firm elbow movement and nod once. Hold briefly, then lower the free hand and return to the starting stance. This porter is a nonmagical shield bearer.'),
 'death_h3_v1':([13,10,12],[[35,1]],2,'Perform one continuous collapse under the load. Knees buckle, lower onto one knee, then tip sideways and descend onto the shield as it settles flat on the ground. Finish lying motionless with head at screen left, boots at screen right, the shield beneath the near forearm, and the backpack still attached. Show the entire fall without a cut or sudden change of pose.'),
}

def ref(i):
 f=dict(PACK['frames'][i]);name=f['source'];f['source']=(BASE/name).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
 if name=='alpha/poses.png':f['scale']=.55
 return f

if __name__=='__main__':
 thumbs=[]
 for n,(name,(indices,guides,last,action)) in enumerate(TAKES.items()):
  out=p.SOURCE_DIR/name;out.mkdir(exist_ok=False)
  c=dict(unit_id=UID,clip=name.split('_')[0],canvas=[960,640],anchor=[450,560],scale=.5,key_rgb=[255,0,255],seed=2026093000+n,references=[ref(i) for i in indices],guides=guides,last=last,prompt=(IDENTITY+action+PLATE).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.prepare(out,c);bands=[]
  for i in range(len(indices)):
   im=Image.open(out/f'guide_{i}_rgba.png');a=np.asarray(im).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
   bands.append(float((np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1])[mask].max()));thumbs.append((name+':'+str(i),im.copy()))
  c['protected_foreground_chroma']=max(0,int(max(bands))+2);c['foreground_measurement']=dict(rule='Eroded opaque min(red,blue)-green maximum plus two across original guides.',per_guide_max=bands)
  p.write(out/'config.json',c)
 p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=list(TAKES),preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Review original chronology, shield grips, alternating gait, backpack continuity, alpha, source scale and native phases before acceptance.')))
 sheet=Image.new('RGB',(1440,((len(thumbs)+3)//4)*260),(42,48,43));draw=ImageDraw.Draw(sheet)
 for j,(name,im) in enumerate(thumbs):
  im.thumbnail((356,237));x,y=j%4*360,j//4*260;sheet.paste(im,(x,y+23),im);draw.text((x+4,y+4),name)
 sheet.save(p.ROOT/'.artifacts/cairnshield_h3/guides.png')
