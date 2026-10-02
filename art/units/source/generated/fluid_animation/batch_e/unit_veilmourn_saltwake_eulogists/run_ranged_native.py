"""Observe every ranged pose through an actual committed BattleShell shot."""
from pathlib import Path
import sys,json
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
sys.path.insert(0,str(ROOT/'tests'))
import fluid_creature_animation_regression as fixture
h=json.loads((Path(__file__).parent/'handoff.json').read_bytes())['units'][0]
n=len(h['clips']['ranged']['indices']);contact=h['clips']['ranged']['contact_frame']
phases=set([0,contact-1,contact,contact+1,n-1])
for index in [n//6,n//3,2*n//3,*range(n)]:
 if len(phases)==8:break
 if 0<=index<n:phases.add(index)
assert len(phases)==8
start=fixture.SCRIPT.index('\t\tvar rendered=SessionState.set_active_session(fixture())')
end=fixture.SCRIPT.index('\t\tvar guard_session=fixture()',start)
block=fixture.SCRIPT[start:end]
# The fixture supplies separated stacks (q2/q5), so the ranged order is legal.
needle='rendered.battle.stacks[0].unit_id=attack_id'
assert block.count(needle)==1
block=block.replace(needle,needle+'\n\t\trendered.battle.stacks[0].ranged=true;rendered.battle.stacks[0].shots_remaining=7')
for old,new in [('shell._perform_action("strike")','shell._perform_action("shoot")'),('battle_unit_melee_attack','battle_unit_ranged_attack'),('pose_clips.attack','pose_clips.ranged'),('capture_count<3 and pose_index in [0,2,4]','capture_count<8 and pose_index in '+str(sorted(phases))),('authored attack pose','authored ranged pose')]:
 assert old in block,old
 block=block.replace(old,new)
block=block.replace('\t\tvar action:Dictionary=shell._perform_action("shoot")','\t\tprint("SALTWAKE_EULOGIST_RANGED_SHELL_BEFORE")\n\t\tvar action:Dictionary=shell._perform_action("shoot")\n\t\tprint("SALTWAKE_EULOGIST_RANGED_SHELL_STARTED "+str(action.get("ok",false))+" "+str(shell._action_playback_in_progress))')
block=block.replace('\t\t# PNG encoding/disk IO','\t\tprint("SALTWAKE_EULOGIST_RANGED_SHELL_FINISHED "+str(seen_attack_frames))\n\t\t# PNG encoding/disk IO')
fixture.SCRIPT=fixture.SCRIPT[:start]+block+fixture.SCRIPT[end:]
needle='func cell_width()->int:return maxi(155,';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,'func cell_width()->int:return maxi(220,')
from capture_clock import observe_after_draw
observe_after_draw(fixture)
raise SystemExit(fixture.main())
