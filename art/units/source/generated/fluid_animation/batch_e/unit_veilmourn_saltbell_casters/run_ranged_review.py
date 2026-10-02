"""Observe original Saltbell ranged release in the actual offscreen battle shell."""
import json,sys
from pathlib import Path
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
sys.path.insert(0,str(ROOT/'tests'))
import fluid_creature_animation_regression as fixture
needle='rendered.battle.stacks[0].name=ContentService.get_unit(attack_id).name';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,needle+'\n\t\trendered.battle.stacks[0].ranged=true\n\t\trendered.battle.stacks[0].shots=6\n\t\trendered.battle.stacks[0].shots_remaining=6')
needle='var action:Dictionary=shell._perform_action("strike")';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,'var action:Dictionary=shell._perform_action("shoot")')
needle='record.get("event_id","")=="battle_unit_melee_attack"';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,'record.get("event_id","")=="battle_unit_ranged_attack"')
needle='ContentService.get_unit_animation(attack_id).pose_clips.attack,Pose.elapsed_msec';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,'ContentService.get_unit_animation(attack_id).pose_clips.ranged,Pose.elapsed_msec')
needle='int(ContentService.get_unit_animation(attack_id).pose_clips.attack.frames)';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,'int(ContentService.get_unit_animation(attack_id).pose_clips.ranged.frames)')
packet=json.loads((Path(__file__).parent/'handoff.json').read_bytes())['units'][0];spec=packet['clips']['ranged'];n=len(spec['indices']);contact=spec['contact_frame']
phases=set([0,contact-1,contact,contact+1,n-1])
for i in [n//6,n//3,2*n//3,*range(n)]:
 if len(phases)==8:break
 if 0<=i<n:phases.add(i)
needle='capture_count<3 and pose_index in [0,2,4]';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,'capture_count<8 and pose_index in '+str(sorted(phases)))
needle='func cell_width()->int:return maxi(155,';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,'func cell_width()->int:return maxi(220,')
from capture_clock import observe_after_draw
observe_after_draw(fixture)
raise SystemExit(fixture.main())
