"""Select personally reviewed chronological original frames, never synthesize motion."""
import json
import numpy as np
from PIL import Image
import produce as p

def select(take,indices,note,contact=None,msec=42,hold=None):
 out=p.SOURCE_DIR/take
 s=dict(source_frames=indices,frame_msec=msec,review_note=note)
 refinements={}
 for i in indices:
  region=np.asarray(Image.open(out/'matte'/f'rgba_{i:03}.png'))[125:147,528:580,3]
  if region.max()<64 and 500<=int((region>=8).sum())<=1100:
   refinements[str(i)]=dict(kind='reviewed_translucent_backdrop_rectangle',background_rect=[528,125,580,147],reason='Personally reviewed faint rectangular background patch beside head; fixed source region has no alpha>=64 character pixels. Preserve every solid character pixel and complete original matte/video.')
 if refinements:s['original_pixel_exclusions']=refinements
 if contact is not None:s['contact_frame']=indices.index(contact)
 if hold:s['frame_durations_msec']=[hold.get(i,msec) for i in indices]
 p.write(out/'selection.json',s);p.build(out,json.loads((out/'config.json').read_bytes()))

# Action selections are added only after original chronological visual review.


def original_actions():
 select('move_h3_v1',[0,4,6]+list(range(8,23,2))+[24,32]+list(range(34,51,2))+[54,62,70]+list(range(72,85,2))+[90,96]+list(range(98,121,2))+[123],
  'All124 chronological original frames, enlarged opposed support/feet/grips and ready endpoints reviewed. Screen-left rear-leg swing8-22; screen-right leg passes44-56, plants72 and opposite swing78-96; both feet return through98-123. Two arms, two legs and two original short hooks retained, with coat/rope motion. Ready123-to0 loop reviewed at shared root. Shorten unchanged holds only, retain original transition phases. No duplicate/reversed/interpolated frames or per-frame normalization. Native review required.',msec=35)
 select('defend_h3_v1',[0,8,14,16]+list(range(18,33))+[36,40,44,70,96,123],
  'All124 chronological originals and enlarged two-handed crossed-blades grips, knees, planted boots and held final guard reviewed. Both hooks rise18-24, knees bend26-32, held crossed guard34-123. Both short hooked tips and two original hands retained, no additional equipment. Shorten unchanged holds only, no duplicates/interpolation/normalization. Native review required.',26)
 select('cast_h3_v1',[0,8,16,18]+list(range(19,29))+[36,48,56,64,66]+list(range(67,74))+[80,96,123],
  'All124 chronological originals and enlarged wrist/forearm/blade grips and endpoints reviewed. Screen-right hook salute rises20-26, brief upright hold28-66, lowers67-73 and returns ready. Screen-left hook remains held across torso; two arms/two legs and original coat/charms retained. Physical support gesture, no magic. Original unmodified pixels and fixed anchor/scale, no duplicate/reversal/interpolation. Native review required.',24,hold={66:168})
 select('death_h3_v1',[0,8,16]+list(range(17,29))+[32,40,48,50]+list(range(51,83))+[90,110,123],
  'All124 chronological originals and enlarged knees/hands/side fall/terminal corpse reviewed. Knees buckle17-24 and kneel26-50; side fall51-56, folded legs and arms settle57-74, head lowers74-82 into grounded corpse through123. Keep dense original fall phases, two original hooked blades rest with hands on ground. Head screen left, boots screen right, no stand-up or missing limbs. Shorten unchanged holds only, no duplicate/reversed/interpolated poses or per-frame normalization. Native review required.',msec=35,hold={48:105})

def corrected_actions():
 select('attack_h3_v2',[0,4,6,8,9,10,12,16,20,24,26,27,28,29,30,32,34,38,48,62,64,66]+list(range(67,79))+[84,90,92,94,95,96,98,102,104,105,106,107,108,110,123],
  'All124 chronological originals and enlarged wrists/steel hooks/knees/strike/recovery reviewed. Raise screen-left hook8-26, physical downstroke27-30, forward guard30-66, two-arm recovery67-108 and original ready through123. Keep both finite original steel hooks and both original hands; first-take cyan arc rejected. Fixed reviewed faint head-side background rectangle cropped only where alpha<64 throughout and500-1100 weak pixels, preserve all solid character pixels and complete originals. No synthesized motion, duplicates/reversal/interpolation or per-frame normalization. Playback42ms follows original24fps; authored windup/contact holds126ms. Native review required.',30,msec=42,hold={26:126,34:126})
 select('hit_h3_v2',[0,8,12]+list(range(13,29))+[34,44,56,62]+list(range(63,75))+[80,96,123],
  'All124 chronological originals and enlarged lean/recoil/knees/grips and complete63-74 recovery reviewed. Plain shoulder/chest recoil13-28, backward lean briefly held, waist/knees regain upright63-74, ready through123. Two held original hooks, two arms and two legs retained; first-take incoming projectile/impact effects rejected. Fixed faint backdrop patch crop only when fully alpha<64 and500-1100 weak pixels; every solid subject pixel and original retained. No erasing effects over character, duplicates/reversal/interpolation or normalization. Native review required.',msec=35,hold={28:105})
 d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());d['takes']=['move_h3_v1','attack_h3_v2','hit_h3_v2','defend_h3_v1','cast_h3_v1','death_h3_v1'];p.write(p.SOURCE_DIR/'delivery.json',d);p.assemble()

if __name__=='__main__':
 import sys
 original_actions()
 if '--corrected' in sys.argv:corrected_actions()
