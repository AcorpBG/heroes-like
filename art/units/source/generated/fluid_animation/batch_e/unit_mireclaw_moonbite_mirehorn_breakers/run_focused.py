"""Bounded actual native/reflected fixture pair, called under the shared GPU lock."""
import argparse,subprocess,sys
import produce as p
import stage_video
UID='unit_mireclaw_moonbite_mirehorn_breakers'
B=p.ROOT/'.artifacts/parallel_animation_20261002'/UID
a=argparse.ArgumentParser();a.add_argument('mode',choices=['candidate','import','live']);args=a.parse_args()
stage_video.release_models()
if args.mode=='import':
 subprocess.run([sys.executable,str(p.SOURCE_DIR/'run_import_check.py')],check=True);print('OWN_IMPORT_TERMINAL',flush=True)
else:
 for label,script in [('native','run_native_review.py'),('mirror','run_mirrored_native.py')]:
  cmd=[sys.executable,str(p.SOURCE_DIR/script),'--godot','D:/Games/godot/Godot_v4.6.2-stable_win64_console.exe','--overview-only','--render','--output',str(B/args.mode/label),'--unit',UID]
  cmd+=(['--handoff',str(p.SOURCE_DIR/'handoff.json')] if args.mode=='candidate' else ['--live'])
  subprocess.run(cmd,check=True)
 print('OWN_NATIVE_MIRROR_TERMINAL',args.mode,flush=True)
