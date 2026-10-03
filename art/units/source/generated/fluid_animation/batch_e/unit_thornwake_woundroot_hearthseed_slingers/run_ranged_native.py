"""Actual ranged shell playback using original sling windup/release/reload frames."""
from pathlib import Path
import sys,json
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
sys.path.insert(0,str(ROOT/'tests'))
import fluid_creature_animation_regression as fixture
# A 960px source canvas renders at .25 native scale. Allow the complete
# asymmetric sling swing plus ten pixels on each side, in every review.
needle='func cell_width()->int:return maxi(155,';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,'func cell_width()->int:return maxi(260,')
# Keep broad per-clip state checks unchanged; specialize only actual shell action.
needle='stacks[index].ranged = false';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,'stacks[index].ranged = index==0\n\t\tstacks[index].shots_remaining = 7')
needle='var action:Dictionary=shell._perform_action("strike")';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,needle.replace('"strike"','"shoot"'))
needle='record.get("event_id","")=="battle_unit_melee_attack"';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,needle.replace('battle_unit_melee_attack','battle_unit_ranged_attack'))
needle='var pose_index:int=Pose.timed_frame(ContentService.get_unit_animation(attack_id).pose_clips.attack,';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,needle.replace('pose_clips.attack','pose_clips.ranged'))
needle='int(ContentService.get_unit_animation(attack_id).pose_clips.attack.frames)';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,needle.replace('pose_clips.attack','pose_clips.ranged'))
h=json.loads((Path(__file__).parent/'handoff.json').read_bytes())['units'][0];n=len(h['clips']['ranged']['indices']);contact=h['clips']['ranged']['contact_frame']
phases=set([0,contact-1,contact,contact+1,n-1])
for index in [n//6,n//3,2*n//3,*range(n)]:
 if len(phases)==8:break
 if 0<=index<n:phases.add(index)
needle='capture_count<3 and pose_index in [0,2,4]';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,'capture_count<8 and pose_index in '+str(sorted(phases)))
from capture_clock import observe_after_draw
observe_after_draw(fixture)
raise SystemExit(fixture.main())
