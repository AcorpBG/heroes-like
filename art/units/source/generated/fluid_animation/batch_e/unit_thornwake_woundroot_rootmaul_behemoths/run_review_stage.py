"""Bounded native review for one melee-only unit; caller holds GPU mutex."""
import argparse,json,subprocess,sys,os
import produce as p
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('mode',choices=['candidate','live']);args=a.parse_args()
 uid='unit_thornwake_woundroot_rootmaul_behemoths';root=p.ROOT/'.artifacts/parallel_animation_20261002'/uid
 scripts=['run_native_review.py','run_mirrored_native.py'] if args.mode=='candidate' else ['run_native_review.py']
 for script in scripts:
  label=args.mode+('_mirrored' if script=='run_mirrored_native.py' else '');out=root/label
  cmd=[sys.executable,str(p.SOURCE_DIR/script),'--godot','D:/Games/godot/Godot_v4.6.2-stable_win64_console.exe','--unit',uid,'--render','--overview-only','--output',str(out)]
  cmd+=['--live'] if args.mode=='live' else ['--handoff',str(p.SOURCE_DIR/'handoff.json')]
  subprocess.run(cmd,check=True,stdout=sys.stdout,stderr=sys.stderr,creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
  text=(out/'console.log').read_text(encoding='utf-8');rows=[json.loads(x.split('FLUID_ANIMATION_REPORT ',1)[1]) for x in text.splitlines() if x.startswith('FLUID_ANIMATION_REPORT ')];assert len(rows)==1 and not rows[0]['failures'];p.write(out/'result.json',rows[0]);print('VERIFIED',label,rows[0]['checks'],flush=True)
