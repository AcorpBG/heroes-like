"""Bounded failed mirror observation retry and dedicated actual ranged fixture."""
import subprocess,sys
import produce as p
uid='unit_veilmourn_saltwake_eulogists';root=p.ROOT/'.artifacts/parallel_animation_20261002'/uid/'candidate'
for script,part in [('run_mirrored_native.py','mirror_retry'),('run_ranged_native.py','ranged')]:
 print('FOCUSED_FOLLOWUP_START',part,flush=True)
 subprocess.run([sys.executable,str(p.SOURCE_DIR/script),'--handoff',str(p.SOURCE_DIR/'handoff.json'),'--unit',uid,'--godot','D:/Games/godot/Godot_v4.6.2-stable_win64_console.exe','--output',str(root/part),'--render'],cwd=p.ROOT,check=True)
 print('FOCUSED_FOLLOWUP_DONE',part,flush=True)
