"""Run bounded stages, releasing the shared GPU mutex after each process."""
import json,subprocess,sys,time
from pathlib import Path
import produce as p
from creature_animation_lock import exclusive

def stage(command):
 with exclusive('gpu'):
  subprocess.run([sys.executable,*command],check=True,creationflags=subprocess.CREATE_NO_WINDOW if sys.platform=='win32' else 0)
 # Give other already-waiting workers a scheduling opportunity before reacquiring.
 time.sleep(2)
if __name__=='__main__':
 takes=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())['takes']
 for offset in range(0,len(takes),2):
  group=takes[offset:offset+2]
  missing=[t for t in group if not (p.SOURCE_DIR/t/'original.latent').exists()]
  if missing:stage([str(p.SOURCE_DIR/'run_generation.py'),'sample',*missing])
  missing=[t for t in group if not (p.SOURCE_DIR/t/'original.json').exists()]
  if missing:stage([str(p.SOURCE_DIR/'run_generation.py'),'decode',*missing])
  missing=[t for t in group if not (p.SOURCE_DIR/t/'matte.json').exists()]
  if missing:stage([str(p.SOURCE_DIR/'segment.py'),*missing])
  for take in group:print('ACTION_REVIEW_READY',take,flush=True)
