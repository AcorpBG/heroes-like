"""Select reviewed chronological original actions, without synthesizing motion."""
import json
import numpy as np
from PIL import Image
import produce as p

def select(take,indices,note,contact=None,msec=42,hold=None,projectiles=None,plate=False):
 out=p.SOURCE_DIR/take
 s=dict(source_frames=indices,frame_msec=msec,review_note=note)
 if contact is not None:s['contact_frame']=indices.index(contact)
 if hold:
  s['frame_durations_msec']=[hold.get(i,msec) for i in indices]
 if projectiles:s['runtime_projectile_separation']=projectiles
 if plate:
  refinements={}
  for i in indices:
   region=np.asarray(Image.open(out/'matte'/f'rgba_{i:03}.png'))[119:146,525:578,3]
   if np.any(region>=8) and region.max()<64:
    refinements[str(i)]=dict(kind='reviewed_translucent_background_plate',background_rect=[525,119,578,146],reason='Faint generated rectangular background fragment beside cap. This reviewed background region has no alpha>=64 subject pixels; preserve cap/scarf/hands and original matte/video.')
  if refinements:s['original_pixel_exclusions']=refinements
 p.write(out/'selection.json',s)
 p.build(out,json.loads((out/'config.json').read_bytes()))

def original_actions():
 select('attack_h3_v1',[0,8]+list(range(10,31,2))+list(range(31,43))+[46,50,56,62]+list(range(64,89,2)),
  'All124 chronological original phases and enlarged anticipation/shove/recovery reviewed. Single physical loaded-cart shove: lean back16-28, arms/chassis push32-56, recover64-80, ready80-88. Both arms and legs, exactly two wheels and loaded bow retained. End at88 after complete recovery; reject later unsolicited shot89-101. Dense original shove phases, shorten unchanged holds only; no duplicates/reversal/interpolation or per-frame normalization. Native review required.',56,hold={56:126})
 select('defend_h3_v1',[0,6]+list(range(8,29))+[34,50,70,90,110,123],
  'All124 chronological originals and enlarged hands/knees/feet/terminal guard reviewed. Two knees crouch8-22, both hands tighten on loaded cart, held behind bow24-123. Both original boots and two cart wheels remain, no firing or invented props. Keep complete original crouch and held guard; shorten unchanged holds only, no duplicates/interpolation or geometry normalization. Native review required.',22)
 select('cast_h3_v1',[0,8]+list(range(10,19))+[24,36,48,56]+list(range(57,67))+[74,96,123],
  'All124 chronological originals plus enlarged empty palm/fingers/regrip reviewed. Far hand releases11-13, raises14-18, holds clear empty rally palm18-56, lowers57-64 and grips65-66. Near hand maintains crank; two arms/two legs and loaded two-wheel cart unchanged. Fixed guarded matte crop removes only personally reviewed translucent background rectangle beside cap, preserves every opaque subject pixel and complete originals. No magic/firing, duplicates/interpolation or frame normalization. Native review required.',18,hold={56:168},plate=True)
 select('death_h3_v1',[0,8,16]+list(range(20,49,2))+[52,56,60]+list(range(62,103,2))+[110,123],
  'All124 chronological originals and enlarged knees/arms/collapse/terminal corpse reviewed. Knees buckle22-30, kneel32-44, hand drops44-64, sit65-78, roll80-96, two legs settle97-102 into grounded head-left corpse through123. Loaded cart remains intact on two wheels. Reject brief unintended bow flash49-51 during otherwise held kneel; adjacent48/52 preserve continuous same kneeling posture. Guarded matte crop removes translucent background rectangle beside cap only. No painted repair, duplicate/reversed/interpolated poses or per-frame normalization. Native review required.',plate=True)
 select('ranged_h3_v1',[0,8,16]+list(range(18,35,2))+list(range(36,41))+[42,44,46]+list(range(48,69,2))+[72,76,80,84]+list(range(86,99))+[104,110,116,123],
  'All124 chronological originals and enlarged bow/string/hand/reload phases reviewed. Aim18-40, release42, visible recoil48-56, followthrough58-68, crank/reload72-94 and ready96-123. Keep two hands/two legs/two wheels and reserve bolts; held reload bolt86-94 retained. Runtime owns projectile: separate only fully detached flying bolt42/44 across verified empty gaps; discard blurred release41, original flight/video fully retained. Fixed guarded matte crop removes only translucent cap-side plate, no subject pixels. No duplicates/reversal/interpolation or normalization. Native review required.',42,msec=35,hold={40:105},projectiles={'42':dict(axis='x',split_x=660,reason='Body ends640, fully detached flying bolt starts682; empty gap, game renders projectile.'),'44':dict(axis='x',split_x=700,reason='Body ends586, fully detached bolt starts832; empty gap, game renders projectile.')},plate=True)

def corrected_actions():
 select('move_h3_v2',list(range(30,75))+[78],
  'All124 chronological originals and enlarged30-84 opposed legs/grips/two-wheel axle reviewed. Retain complete middle reciprocal cycle30-78: near knee/boot swings forward34-46, near contact50-54 with far leg lifted behind, opposed support/swing58-70 and original ready74-78. Both arms retain handles and two wheels rotate. Loop ready78 to30 at fixed original anchor and anatomical scale. Reject unwanted shots10-18 and89-93 outside this interval. Keep dense original transition phases, shorten terminal ready only. No duplicate/reversed/interpolated poses or per-frame normalization. Native review required.',msec=35,plate=True)
 select('hit_h3_v2',[0,8,16]+list(range(18,35)),
  'All124 chronological originals and enlarged0-42 recoil reviewed. Retain only original plain torso/knee recoil0-34 before unwanted extra attached bolt44-64. Clean supplied backward lean34 matches first take36 in face/arms/boots/cart/anchor; use that separately reviewed clean recovery. No erased equipment, interpolation or geometry normalization. Native seam review required.',msec=35,plate=True)
 select('hit_h3_v1',[36,40,44,48]+list(range(50,73,2))+[78,96,123],
  'All124 chronological originals and enlarged clean36-123 recovery reviewed. Reject incoming arrow/flash/particles15-28; clean held lean36 matches corrected take34. Continuous original recovery40-72 returns chest/knees/arms to ready, preserve two boots/two cart wheels and loaded original bow. Native shared-anchor seam34(v2) to36(v1) reviewed enlarged without blending/warping. Guarded matte crop removes translucent background rectangle only. No duplicates/reversal/interpolation or per-frame normalization. Native review required.',msec=35,plate=True)
 d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
 d['takes']=['move_h3_v2','attack_h3_v1','defend_h3_v1','cast_h3_v1','death_h3_v1','ranged_h3_v1']
 d['clip_sequences']={'hit':dict(frames=[dict(take=take,video_frame=i) for take in ['hit_h3_v2','hit_h3_v1'] for i in json.loads((p.SOURCE_DIR/take/'selection.json').read_bytes())['source_frames']],timing=dict(frame_msec=35))}
 p.write(p.SOURCE_DIR/'delivery.json',d);p.assemble()

if __name__=='__main__':
 import sys
 if '--corrected' in sys.argv:corrected_actions()
 else:original_actions()
