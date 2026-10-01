"""Native mirrored phase rendering only; unchanged candidate and runtime code."""
from pathlib import Path
import sys

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').exists())
sys.path.insert(0, str(ROOT / 'tests'))
import fluid_creature_animation_regression as fixture

needle = 'var rect:Rect2=Pose.grounded_rect(ground,128,region,row)'
assert fixture.SCRIPT.count(needle) == 1
fixture.SCRIPT = fixture.SCRIPT.replace(needle,
    'var rect:Rect2=Pose.grounded_rect(ground,128,region,row,true)\n'
    '\t\t\t\trect.size.x=-rect.size.x')
raise SystemExit(fixture.main())
