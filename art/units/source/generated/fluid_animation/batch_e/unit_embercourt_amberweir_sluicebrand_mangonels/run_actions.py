"""Finish at most two original actions in one bounded shared GPU lease."""
import argparse,json,subprocess,sys
from pathlib import Path
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools'))
from creature_animation_lock import exclusive
import stage_video

def run(script,*args):subprocess.run([sys.executable,str(OUT/script),*args],cwd=ROOT,check=True)
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('takes',nargs='+');args=parser.parse_args();assert 1<=len(args.takes)<=2
 for t in args.takes:assert (OUT/t/'config.json').is_file() and json.loads((OUT/t/'config.json').read_bytes())['unit_id']==OUT.name
 with exclusive('gpu'):
  sample=[t for t in args.takes if not (OUT/t/'sampling_history.json').exists()]
  if sample:run('run_generation.py','sample',*sample)
  decode=[t for t in args.takes if not (OUT/t/'original.json').exists()]
  if decode:run('run_generation.py','decode',*decode)
  matte=[t for t in args.takes if not (OUT/t/'matte.json').exists()]
  if matte:run('segment.py',*matte)
  stage_video.release_models()
 for t in args.takes:
  if not (OUT/t/'matte_v3.json').exists():run('refine_matte.py',t)
 print('BOUNDED_ACTIONS_COMPLETE',args.takes,flush=True)
