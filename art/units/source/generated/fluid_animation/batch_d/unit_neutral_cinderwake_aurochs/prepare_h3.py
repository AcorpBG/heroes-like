"""Prepare source-backed fixed-scale Cinderwake Aurochs H3 guides."""
import json
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import binary_erosion
import produce as p
UID='unit_neutral_cinderwake_aurochs'
BASE=p.ROOT/'art/animation/source/poses'/UID
PACK=json.loads((BASE/'packing.json').read_bytes())
IDENTITY=('One original Cinderwake Aurochs: massive dark charcoal lava-armored bull, exactly FOUR separate short muscular legs ending in split cloven hooves, exactly TWO curled bronze-edged horns, broad black muzzle, orange beard, overlapping angular dark back plates, molten orange seams, bronze-gold flecks and one long flexible tail with a stone tuft. Preserve the original four-legged anatomy, two horn curves, plate pattern and painterly surface. Only existing attached lava seams and small back flame accents; no new effects. ')
PLATE=(' Locked elevated three-quarter orthographic camera facing screen right, unchanged torso scale and centered body root. Entire tail, horns, all hooves and body remain inside frame. Perfectly flat pure green RGB0,255,0 background, no scenery, floor, horizon, shadow, smoke, other figure, text, props, projectile, magic or fire blast. ')
TAKES={
'move_h3_v1':([12,2,4,3],[[24,1],[44,2],[66,3],[92,0]],0,'Perform one deliberate complete reciprocal four-legged walking cycle in place. The near foreground front leg and opposite far hind leg extend forward and bear weight, while the other diagonal pair trails; then pass the hooves under the body and exchange support, advancing the far front leg and near hind leg. Each of the FOUR hooves separately lifts, travels, plants and loads through the cycle. Distinct opposite front-leg contacts must appear; do not repeat the same leading leg, hop, skate or slide the body. Keep planted hooves supporting the heavy body and torso centered. Head and tail respond subtly; return to the starting ready stance.'),
'attack_h3_v1':([12,5,6],[[27,1],[52,2],[64,2],[94,0]],0,'One physical horn and headbutt attack. Lower head and flex the neck into the supplied anticipation, plant rear hooves, drive shoulders and curled horns forward toward screen right as in the supplied contact pose, then retract the neck and shoulders and recover the original ready stance. Four hooves support the body; no leap, fire breath, spell, projectile or added object.'),
'hit_h3_v1':([12,8],[[24,1],[40,1]],0,'One physical backward chest and neck recoil, front knees flex and head tilts back briefly in the supplied recoil. All FOUR legs and both horns remain attached and unchanged. Rear hooves support weight; lower front hooves and recover the original ready stance. No incoming object or effect.'),
'defend_h3_v1':([12,7],[[50,1]],1,'Lower the head and both curled horns into the supplied compact low guard, flex all four supporting legs and brace shoulders forward. Keep all four hooves grounded and finish holding this defensive horn brace. No attack, projectile, magic or fire blast.'),
'cast_h3_v1':([12,8],[[46,1],[66,1]],0,'A nonmagical physical rally gesture: plant all four hooves, lift the muzzle and head deliberately, open the mouth briefly as if snorting, tighten shoulders and lift the existing tail, then lower head and tail smoothly and return to original ready. Both curled horns remain unchanged. No vapor, smoke, magic, blast or projectile.'),
'death_h3_v1':([12,9,10,11],[[32,1],[65,2],[98,3]],3,'One continuous grounded defeat collapse. Front knees buckle, lower the chest, bend rear legs and ease the heavy torso down onto its side, then settle the head, curled horns, four folded legs and tail along the ground into the supplied corpse. No rolling upright, disappearing legs, detached horn or new effect. Finish fully grounded and motionless in the supplied corpse pose.')}
def ref(index):
 f=dict(PACK['frames'][index]);f['source']=(BASE/f['source']).relative_to(p.ROOT).as_posix();f['alpha_noise_cutoff']=8
 offsets={0:22,2:20,3:23,4:39,5:43,6:45,7:47,8:77,9:80,10:64,11:68}
 if index in offsets:f['guide_offset']=[0,offsets[index]]
 return f
if __name__=='__main__':
 import argparse
 parser=argparse.ArgumentParser();parser.add_argument('takes',nargs='*',default=list(TAKES));args=parser.parse_args()
 for number,name in enumerate(TAKES):
  if name not in args.takes:continue
  indices,guides,last,action=TAKES[name];out=p.SOURCE_DIR/name;out.mkdir(exist_ok=False)
  c=dict(unit_id=UID,clip=name.split('_')[0],canvas=[960,640],anchor=[430,560],scale=.5,key_rgb=[0,255,0],seed=2026100200+number,references=[ref(i) for i in indices],guides=guides,last=last,prompt=(IDENTITY+action+PLATE).strip(),tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.prepare(out,c);bands=[]
  for i in range(len(indices)):
   a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3);bands.append(float((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[mask].max()))
  c['protected_foreground_chroma']=max(0,int(max(bands))+2);c['foreground_measurement']=dict(rule='Eroded opaque original guide green-minus-max(red,blue) maximum plus two.',per_guide_max=bands);p.write(out/'config.json',c)
  print(name,'prepared',bands,flush=True)
 if not (p.SOURCE_DIR/'delivery.json').exists():p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=UID,takes=[],planned_takes=list(TAKES),preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Four hooves, two horns, original lava plates and tail. Move-first review; complete coherent six-action set required. Idle8 preserved.')))
