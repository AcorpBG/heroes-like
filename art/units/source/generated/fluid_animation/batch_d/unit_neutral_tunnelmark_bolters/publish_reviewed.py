"""Publish seven visually reviewed original actions and retain accepted idle."""
import json,sys
import produce as p
sys.path.insert(0,str(p.ROOT/'tools'))
from publish_fluid_creature_animation import publish
NOTE=('Solo reviewed all124 chronological original frames in each of eleven H3 takes, enlarged boots/near-far hands/stock/string/fist/collapse, and every selected native128px pose in original and actual reflected rendering. '
 'Accepted grounded reciprocal heel/toe travel with two-hand lowered carry; near RIGHT fist melee anticipation/extension/contact/recovery while LEFT cradles original crossbow; dedicated recoil/low guard/physical fist encouragement; original aim/trigger-string release/empty lowering/stock reload; descent and grounded head-right corpse. '
 'Initial movement fired unwanted fragments and held knee lifts, rejected. One new built-in original forward-contact/downward-carry guide and fewer H3 guides improve travel; two attempted opposed contact keys did not swap leg roles and are not used. Initial punch snapped26->27; corrected take retains original active elbow extension and recovery. Initial support fired fragments and snapped to ready; corrected dedicated salute has no projectile and returns smoothly. '
 'Dry-fire correction emits repeated volleys and is rejected. Reviewed first ranged take retains actual release; only fully detached source34/35 projectile layers separated atx725 across empty665-789 gap, preserving all character/held equipment pixels throughx664. Original unmodified matte/video preserved; runtime owns flight. '
 'Selected334 original new poses run42ms per observed source frame; shorten unchanged holds only. No interpolation, reversal, duplicate padding, whole-sprite warping or per-pose normalization. '
 '1100 candidate and1100 reflected focused checks pass: Normal/Fast/reduced motion, ranged projectile/audio arrival timing, actual shell clock showing all48 melee poses including recovery, simulation/RNG/occupancy/save invariance. Preserve eight accepted articulated idle frames and all232 overworld pixels/timing. '
 'Review used complete chronological stills, enlarged details, every native phase and actual clock-driven captures; no claim of continuous manual movie playback or manual game playtest. Focused Windows checks only; no full suite.')
if __name__=='__main__':
 d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());d['visual_review']=dict(status='accepted',notes=NOTE);p.write(p.SOURCE_DIR/'delivery.json',d);p.assemble()
 print(json.dumps(publish(p.SOURCE_DIR/'handoff.json',['move','attack','hit','defend','cast','death','ranged'],NOTE,['idle'])))
