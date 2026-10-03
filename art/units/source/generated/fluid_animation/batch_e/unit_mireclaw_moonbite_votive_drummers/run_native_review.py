"""Actual shell-clock captures across Moonbite Votive crescent-mallet contact."""
from pathlib import Path
import sys,json
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
sys.path.insert(0,str(ROOT/'tests'))
import fluid_creature_animation_regression as fixture
# Dense phase pages leave room for the original crescent mallet and shield.
# This changes only preview spacing; native sprite scale/anchors are untouched.
needle='func cell_width()->int:return maxi(155,';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,'func cell_width()->int:return maxi(220,')
# Capture the existing articulated-mallet idle phase three in the live map check.
needle='float(material.get_shader_parameter("frame_seconds"))*1.1';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,'float(material.get_shader_parameter("frame_seconds"))*3.1')
needle='change.unit_id+"-map-idle-1.png"';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,'change.unit_id+"-map-idle-3.png"')
# Capture each retained original idle pose through the actual map material.
needle='\t\t\t\t\tbatch.set_motion_enabled(false)';assert fixture.SCRIPT.count(needle)==1
fixture.SCRIPT=fixture.SCRIPT.replace(needle,'''
\t\t\t\t\tfor idle_phase in range(int(material.get_shader_parameter("frame_count"))):
\t\t\t\t\t\tmaterial.set_shader_parameter("clock_override",float(material.get_shader_parameter("frame_seconds"))*(float(idle_phase)+0.1))
\t\t\t\t\t\tvar phase_image:Image=await capture()
\t\t\t\t\t\tphase_image.save_png(OS.get_environment("FLUID_OUTPUT").path_join(change.unit_id+"-map-idle-"+str(idle_phase)+".png"))
''' +needle)
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
from capture_clock import observe_after_draw
observe_after_draw(fixture)
raise SystemExit(fixture.main())
