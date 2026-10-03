"""Render submitted native phases with the game's actual reflected draw transform."""
from pathlib import Path
import sys,json
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
sys.path.insert(0,str(ROOT/'tests'))
import fluid_creature_animation_regression as fixture
needle='var rect:Rect2=Pose.grounded_rect(ground,128,region,row)'
assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,needle[:-1]+',true)')
needle='\t\t\t\tdraw_texture_rect_region(sheet,rect,region)'
assert fixture.SCRIPT.count(needle)==2
fixture.SCRIPT=fixture.SCRIPT.replace(needle,'\t\t\t\tdraw_set_transform(Vector2(rect.end.x,0.0),0.0,Vector2(-1.0,1.0))\n\t\t\t\tdraw_texture_rect_region(sheet,Rect2(Vector2(0.0,rect.position.y),rect.size),region)\n\t\t\t\tdraw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)')
fixture.SCRIPT=fixture.SCRIPT.replace('actual 128px reference height','actual mirrored 128px reference height')
h=json.loads((Path(__file__).parent/'handoff.json').read_bytes())['units'][0]
n=len(h['clips']['attack']['indices']);contact=h['clips']['attack']['contact_frame']
phases=set([0,contact-1,contact,contact+1,n-1])
for index in [n//6,n//3,2*n//3,*range(n)]:
 if len(phases)==8:break
 if 0<=index<n:phases.add(index)
needle='capture_count<3 and pose_index in [0,2,4]';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,'capture_count<8 and pose_index in '+str(sorted(phases)))
needle='func cell_width()->int:return maxi(155,';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,'func cell_width()->int:return maxi(260,')
from capture_clock import observe_after_draw
observe_after_draw(fixture)
raise SystemExit(fixture.main())
