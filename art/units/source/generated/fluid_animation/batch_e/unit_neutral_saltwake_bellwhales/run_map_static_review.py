"""Capture the existing reduced-motion map frame, retaining map assertions."""
from pathlib import Path
import sys

root = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').exists())
sys.path.insert(0, str(root / 'tests'))
import fluid_creature_animation_regression as fixture

start = fixture.SCRIPT.index('\t\tfor change in patch.units:\n\t\t\tvar overview:=')
end = fixture.SCRIPT.index('\t\tif OS.get_environment("FLUID_LIVE")=="1":', start)
fixture.SCRIPT = fixture.SCRIPT[:start] + fixture.SCRIPT[end:]
needle = 'float(material.get_shader_parameter("frame_seconds"))*1.1'
assert fixture.SCRIPT.count(needle) == 1
fixture.SCRIPT = fixture.SCRIPT.replace(needle, 'float(material.get_shader_parameter("frame_seconds"))*3.1')
needle = '\t\t\t\t\tvar still:Image=await capture()'
assert fixture.SCRIPT.count(needle) == 1
fixture.SCRIPT = fixture.SCRIPT.replace(needle, needle + '\n\t\t\t\t\tstill.save_png(OS.get_environment("FLUID_OUTPUT").path_join(change.unit_id+"-map-reduced.png"))')
end = fixture.SCRIPT.index('\tvar board=Board.new();')
fixture.SCRIPT = fixture.SCRIPT[:end] + '\tprint("FLUID_ANIMATION_REPORT "+JSON.stringify({"checks":checks,"failures":failures}))\n\tget_tree().quit(0 if failures.is_empty() else 1)\n'
raise SystemExit(fixture.main())
