"""Focused live fixture with visible windup, release, contact and recovery."""
from pathlib import Path
import sys
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
sys.path.insert(0,str(ROOT/'tests'))
import fluid_creature_animation_regression as fixture
needle='capture_count<3 and pose_index in [0,2,4]'
assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,'capture_count<8 and pose_index in [0,10,17,20,23,37,42,50]')
raise SystemExit(fixture.main())
