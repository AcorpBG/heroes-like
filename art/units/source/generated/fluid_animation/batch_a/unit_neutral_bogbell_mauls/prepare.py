"""Prepare original Bogbell Maul guides; retain the articulated idle family."""
import copy,json
import numpy as np
from scipy.ndimage import binary_erosion
import produce as p
from PIL import Image

UID='unit_neutral_bogbell_mauls'
LEGACY=p.ROOT/'art/animation/source/poses'/UID

def ref(index):
 f=copy.deepcopy(json.loads((LEGACY/'packing.json').read_bytes())['frames'][index])
 f['source']=(LEGACY/f['source']).relative_to(p.ROOT).as_posix()
 if index<13:f['scale']*=.94
 f['alpha_noise_cutoff']=8
 return f

def prepare():
 identity='One original Bogbell Maul: stocky broad bearded human with mossy brown hood, muddy layered hide armor, olive trousers, wrapped heavy boots, bronze chest bell and small dangling bronze bells on belt and maul. Exactly two arms, two hands and two legs. One thick long wooden-shaft maul with ONE barrel-shaped dark wooden head and bronze bands, retained in a two-handed grip. Right hand grips the rear/lower shaft near screen left; left hand grips forward near barrel head at screen right in ready. Keep the same hands on the same shaft positions as the weapon rotates. '
 plate=' Locked elevated three-quarter orthographic camera facing screen right. Full creature and full maul stay within 960x544, same body/equipment size throughout, anatomical root centered. Uniform pure magenta RGB255,0,255 background throughout; no floor, cast shadow, text, particles, external light, magic, additional people or objects. Articulated physical joints and stable grips, no prop/anatomy morphing. '
 definitions={
 'attack':([ref(13),ref(4),ref(5)],[[36,1],[58,2]],0,'Perform one heavy maul strike. Bend elbows and shoulders to raise the maul over the hood into supplied windup; barrel head travels in one arc. Swing forward/down toward screen right into supplied strike contact; both hands remain around the same shaft. Recover with bent elbows, draw maul up to original waist-height ready grip. Boots stay planted at impact, torso twists locally. No second attack or released maul.'),
 'hit':([ref(13),ref(9)],[[32,1]],0,'One sharp physical backward torso/shoulder recoil, knees flex, hooded head tilts back briefly. Keep both hands on the same maul and maintain its complete barrel and shaft. Regain balance and return smoothly to ready; no fall, travel or unrelated attack.'),
 'defend':([ref(13),ref(8)],[],1,'Transition into supplied deep defensive crouch. Flex both knees, tuck chin, raise elbows so the two-handed maul shaft protects the chest while the same barrel head stays at screen right. Settle into the low guard and HOLD the supplied grounded brace through the last frame; do not return to ready.'),
 'cast':([ref(13)],[],0,'One physical support signal to companions. Stand firmly on both boots, lift the SAME two-handed maul horizontally from waist to shoulder height while elbows bend outward, hooded head nods once to companions, then lower it smoothly to original ready. Keep both original hands gripping the same shaft and the same barrel head at screen right. This is a deliberate rally gesture, no spellcasting, magic, glowing bell or strike.'),
 'death':([ref(13),ref(12)],[],1,'One continuous heavy collapse from supplied standing ready to supplied head-left horizontal corpse. Knees gradually buckle, hips sink, torso tilts and falls sideways toward screen left. Left elbow and hip contact ground before shoulder and hood settle. Maul lowers WITH the hands and may slip out only when it lands in front of the fallen body; one complete shaft and barrel rest on ground. Boots and head remain attached, final body fully still. No jump between standing/kneeling/lying poses, no new props, no repeated fall or stand-up.'),
 'move':([ref(2)],[],0,'Walk IN PLACE through three complete reciprocal cycles, beginning and ending at supplied forward-contact pose. The near/right leg under the lower-shaft hand swings forward toward screen right from its own hip, takes weight, moves back as far/left leg passes it and then comes forward in turn. Both legs alternate contact, loading, knee passing and toe-off with clearly opposed boot steps. Maul stays carried across waist in both original hands with passive elbow motion and small physical bell swings. No root travel, no repeated single-leg march or extra action.')}
 measurements={}
 for order,(clip,(refs,guides,last,action)) in enumerate(definitions.items()):
  out=p.SOURCE_DIR/(clip+'_h3_v1');out.mkdir(exist_ok=True)
  assert not (out/'submission.json').exists(),'Submitted take is immutable'
  c=dict(unit_id=UID,clip=clip,canvas=[960,544],anchor=[470,480],scale=.5,key_rgb=[255,0,255],seed=2026100500+order,references=refs,guides=guides,last=last,prompt=(identity+action+plate).strip(),protected_foreground_chroma=26,tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
  p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
  maxima=[]
  for i in range(len(refs)):
   a=np.asarray(Image.open(out/f'guide_{i}_rgba.png').convert('RGBA')).astype(float);mask=binary_erosion(a[:,:,3]>=240,iterations=3)
   maxima.append(float((np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1])[mask].max()))
  assert max(maxima)<26,(clip,maxima)
  measurements[clip]=dict(opaque_eroded_interior_magenta_chroma_max=maxima,protected_band=26,background_chroma=255)
 p.write(p.SOURCE_DIR/'foreground_measurement.json',dict(unit_id=UID,method='alpha>=240, three-pixel interior erosion; min(red,blue)-green',guides=measurements))
 p.write(p.SOURCE_DIR/'runtime_registration.json',dict(unit_id=UID,reference_height=256,output_scale=.5,ground_anchor=[470,480],legacy_action_family_scale=.94,reason='Legacy action family has about206px standing body versus195px retained articulated idle. One family conversion preserves relative crouch/fall geometry, while idle-ready guides retain original scale. No per-frame normalization.'))
 p.write(p.SOURCE_DIR/'delivery.json',dict(takes=[clip+'_h3_v1' for clip in definitions],preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Solo Bogbell Maul six-action production; preserve reviewed eight-frame idle. Source and native review pending.')))
 print('Prepared six original H3 actions with measured safe foreground palette')

if __name__=='__main__':prepare()
