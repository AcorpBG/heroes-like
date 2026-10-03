"""Run a bounded own-unit native/action review stage through terminal completion."""
import argparse, subprocess, sys
import produce as p
from creature_animation_lock import exclusive

GODOT='D:/Games/godot/Godot_v4.6.2-stable_win64_console.exe'
UID=p.SOURCE_DIR.name
OUT=p.ROOT/'.artifacts/parallel_animation_20261002'/UID

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('stage',choices=['candidate_pair','candidate_ranged','live_ranged']);args=parser.parse_args()
 scripts=['run_native_review.py','run_mirrored_native.py'] if args.stage=='candidate_pair' else ['run_ranged_native.py']
 with exclusive('gpu'):
  for name in scripts:
   label={'run_native_review.py':'native','run_mirrored_native.py':'mirrored','run_ranged_native.py':'ranged'}[name]
   source=['--live'] if args.stage=='live_ranged' else ['--handoff',str(p.SOURCE_DIR/'handoff.json')]
   subprocess.run([sys.executable,str(p.SOURCE_DIR/name),'--godot',GODOT,*source,'--unit',UID,'--render','--overview-only','--output',str(OUT/(args.stage+'_'+label))],cwd=p.ROOT,check=True)
 print('BOUNDED_REVIEW_COMPLETED',args.stage,flush=True)
