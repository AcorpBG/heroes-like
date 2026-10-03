"""Bounded shared GPU stages, each released before the next worker stage."""
import argparse,subprocess,sys
import produce as p
from creature_animation_lock import exclusive
def run(phase,takes):
 for start in range(0,len(takes),2):
  group=takes[start:start+2]
  with exclusive('gpu'):
   command=[sys.executable,str(p.SOURCE_DIR/('segment.py' if phase=='matte' else 'run_generation.py'))]
   if phase!='matte':command.append(phase)
   command.extend(group)
   print('STAGE',phase,group,flush=True)
   subprocess.run(command,check=True,creationflags=subprocess.CREATE_NO_WINDOW if sys.platform=='win32' else 0)
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('phase',choices=['sample','decode','matte']);a.add_argument('takes',nargs='+');args=a.parse_args();run(args.phase,args.takes)
