"""Prepare original Icehook guides at one anatomical scale on a green plate."""
import json
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_erosion
import produce as p

UID='unit_neutral_icehook_trappers'
BASE=p.ROOT/'art/animation/source/poses'/UID
PACK=json.loads((BASE/'packing.json').read_bytes())
IDENTITY=('One original Icehook Trapper, an athletic adult human man with short tousled brown hair and stubble. '
 'Ivory fur-trimmed winter leather coat, vivid blue scarf, blue-grey trousers, crossed brown leather straps, '
 'brown bracers and wrapped leather boots. Rope coils remain attached at his belt. Exactly two arms and two legs. '
 'His right hand at screen left grips ONE short icehook by its brown handle, with one curved silver-blue hooked blade. '
 'His left hand at screen right is free. Preserve the same compact hooked tool, grip, face, fur and clothing throughout. ')
PLATE=(' Locked elevated three-quarter orthographic camera at the reference angle, fixed anatomical scale and centered root. '
 'Full body and equipment remain visible. Uniform pure saturated green RGB0,255,0 fills the entire background throughout. '
 'The only subject is this trapper, physical joints, stable foot contacts and continuous equipment geometry. ')
TAKES={
 'move_h3_v1':([13],[],0,'Walk steadily in place for three full reciprocal gait cycles. Alternate both boots through contact, weight-bearing, passing and lift. The free arm counter-swings naturally while the tool hand carries the short icehook pointed down away from the legs. Scarf and coat tails follow the stride subtly. Finish in the starting stance.'),
 'attack_h3_v1':([13,4,5],[[28,1],[54,2]],0,'Perform ONE hooked-tool strike. Bend the right elbow to lift the icehook over the right shoulder, then step and swing the hooked blade down and forward across the body into the supplied extended contact pose. The left open hand balances the body. Retract the same tool and recover smoothly to the starting ready stance.'),
 'hit_h3_v1':([13,9],[[42,1]],0,'Perform one startled backward recoil. The shoulders and head lean back, knees flex and the open left arm extends for balance. Keep the icehook in the right hand. Regain balance and return to the starting stance. A solitary physical flinch, with only the trapper against the green background.'),
 'defend_h3_v1':([13,7],[[49,1],[90,1]],1,'Brace for danger. Bend both knees and bring the icehook in front of the chest in a compact protective grip. Lift the open left palm in front of the face. End holding this guarded crouch, both boots planted and the short hook still held by the right hand.'),
 'cast_h3_v1':([13,16],[[44,1],[75,1]],0,'Perform a practical readiness signal. The free left hand takes a loose loop from the belt rope and raises it to chest height for inspection, briefly holds the small loop, then returns it to the belt. The right hand continuously carries the short icehook low at the side. Finish in the starting ready stance. A nonmagical trapper preparing equipment to support allies.'),
 'death_h3_v1':([13,10,12],[[35,1]],2,'Perform one continuous collapse. Knees buckle and descend onto the knees, then tip onto the right side with head toward screen right and boots toward screen left. The free hand briefly reaches toward the ground and the icehook lowers with the right hand. Finish lying motionless in the supplied side-rest pose, body and hooked tool resting on the ground.'),
}

def ref(i):
 f=dict(PACK['frames'][i]);f['source']=(BASE/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
 return f

if __name__=='__main__':
 thumbs=[]
 for n,(name,(indices,guides,last,action)) in enumerate(TAKES.items()):
  out=p.SOURCE_DIR/name;out.mkdir(exist_ok=False)
  c=dict(unit_id=UID,clip=name.split('_')[0],canvas=[960,640],anchor=[470,560],scale=.5,key_rgb=[0,255,0],seed=2026093030+n,
   references=[ref(i) for i in indices],guides=guides,last=last,prompt=(IDENTITY+action+PLATE).strip(),
   tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.prepare(out,c);bands=[]
  for i in range(len(indices)):
   im=Image.open(out/f'guide_{i}_rgba.png');a=np.asarray(im).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
   bands.append(float((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[mask].max()));thumbs.append((name+':'+str(i),im.copy()))
  c['protected_foreground_chroma']=max(0,int(max(bands))+2)
  c['foreground_measurement']=dict(rule='Eroded opaque green-minus-max(red,blue) maximum plus two across original guides.',per_guide_max=bands)
  p.write(out/'config.json',c)
 p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=list(TAKES),preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Review reciprocal gait, continuous hook grip, rope-hand support, collapse, alpha and native scale. Preserve reviewed eight-pose idle.')))
 sheet=Image.new('RGB',(1440,((len(thumbs)+3)//4)*260),(42,48,43));draw=ImageDraw.Draw(sheet)
 for j,(name,im) in enumerate(thumbs):
  im.thumbnail((356,237));x,y=j%4*360,j//4*260;sheet.paste(im,(x,y+23),im);draw.text((x+4,y+4),name)
 sheet.save(p.ROOT/'.artifacts/icehook_h3/guides.png')
