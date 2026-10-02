"""Actual shell-clock captures across the selected original seed-spear thrust."""
from pathlib import Path
import sys,json
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
sys.path.insert(0,str(ROOT/'tests'))
import fluid_creature_animation_regression as fixture
h=json.loads((Path(__file__).parent/'handoff.json').read_bytes())['units'][0]
n=len(h['clips']['attack']['indices']);contact=h['clips']['attack']['contact_frame']
phases=set([0,contact-1,contact,contact+1,n-1])
for index in [n//6,n//3,2*n//3,*range(n)]:
 if len(phases)==8:break
 if 0<=index<n:phases.add(index)
phases=sorted(phases)
assert len(phases)==8 and 0<=min(phases)<=max(phases)<n
needle='capture_count<3 and pose_index in [0,2,4]';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,'capture_count<8 and pose_index in '+str(phases))
raise SystemExit(fixture.main())
