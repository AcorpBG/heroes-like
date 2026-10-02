"""At most two focused native fixtures inside an external shared GPU lease."""
import argparse,subprocess,sys
from pathlib import Path
import produce as p
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('mode',choices=['candidate','live']);args=a.parse_args()
 uid='unit_veilmourn_saltwake_eulogists';root=p.ROOT/'.artifacts/parallel_animation_20261002'/uid
 runs=[('run_native_review.py','native'),('run_mirrored_native.py','mirror')] if args.mode=='candidate' else [('run_native_review.py','native'),('run_ranged_native.py','ranged')]
 for script,part in runs:
  flags=['--handoff',str(p.SOURCE_DIR/'handoff.json')] if args.mode=='candidate' else ['--live']
  command=[sys.executable,str(p.SOURCE_DIR/script),*flags,'--unit',uid,'--godot','D:/Games/godot/Godot_v4.6.2-stable_win64_console.exe','--output',str(root/args.mode/part),'--render']
  print('FOCUSED_NATIVE_START',args.mode,part,flush=True);subprocess.run(command,cwd=p.ROOT,check=True);print('FOCUSED_NATIVE_DONE',args.mode,part,flush=True)
 print('BOUNDED_NATIVE_PAIR_COMPLETED',args.mode,flush=True)
