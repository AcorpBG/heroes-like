"""Bounded two-fixture native lease; release before personal visual inspection."""
import argparse,os,subprocess,sys
import produce as p
from creature_animation_lock import exclusive

def run(godot,stage):
 scripts=['run_native_review.py','run_mirrored_native.py'] if stage=='candidate' else ['run_native_review.py','run_ranged_review.py']
 with exclusive('gpu'):
  if stage=='live':
   # The ordinary import already ran in its own lease. Verify the real cached
   # atlas before the two live fixtures, without acquiring a nested mutex.
   verification=[godot,'--headless','--path',str(p.ROOT),'--script','res://'+(p.SOURCE_DIR/'verify_imported_atlas.gd').relative_to(p.ROOT).as_posix()]
   profile=p.ROOT/'.artifacts/parallel_animation_20261002'/p.SOURCE_DIR.name/'import_verification_profile'
   profile.mkdir(parents=True,exist_ok=True)
   environment=dict(os.environ,APPDATA=str(profile),XDG_DATA_HOME=str(profile))
   result=subprocess.run(verification,env=environment,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,creationflags=subprocess.CREATE_NO_WINDOW if sys.platform=='win32' else 0)
   (profile/'verification.log').write_text(result.stdout,encoding='utf-8')
   result.check_returncode()
   assert 'PRISMWAKE_RAYLING_IMPORTED_ATLAS_OK' in result.stdout,result.stdout
   assert not any(line.startswith(('ERROR:','SCRIPT ERROR:')) for line in result.stdout.splitlines()),result.stdout
   print(result.stdout,flush=True)
  for script in scripts:
   name={'run_native_review.py':stage,'run_mirrored_native.py':'mirror','run_ranged_review.py':'live_ranged'}[script]
   output=p.ROOT/'.artifacts/parallel_animation_20261002'/p.SOURCE_DIR.name/name
   command=[sys.executable,str(p.SOURCE_DIR/script),'--godot',godot,'--unit',p.SOURCE_DIR.name,'--output',str(output),'--render','--overview-only']
   command.extend(['--handoff',str(p.SOURCE_DIR/'handoff.json')] if stage=='candidate' else ['--live'])
   result=subprocess.run(command,creationflags=subprocess.CREATE_NO_WINDOW if sys.platform=='win32' else 0)
   result.check_returncode()
 print('BOUNDED_NATIVE_PAIR_COMPLETE',stage,flush=True)

if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('--godot',required=True);a.add_argument('stage',choices=['candidate','live']);args=a.parse_args();run(args.godot,args.stage)
