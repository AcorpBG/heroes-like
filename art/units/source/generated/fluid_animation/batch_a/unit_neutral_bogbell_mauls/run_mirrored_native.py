"""Render submitted native phases with the game's actual reflected draw transform."""
from pathlib import Path
import sys
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
raise SystemExit(fixture.main())
