"""Complete bounded stages under separate GPU acquisitions, retaining originals."""
import argparse,subprocess,sys,time
from pathlib import Path
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools'))
from creature_animation_lock import exclusive
def run(script,*args):subprocess.run([sys.executable,str(OUT/script),*args],cwd=ROOT,check=True)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--one-lease',action='store_true');a=p.parse_args()
 for takes in [['move_h3_v1'],['ranged_h3_v1'],['hit_h3_v1','defend_h3_v1'],['cast_h3_v1','death_h3_v1'],['attack_h3_v2','hit_h3_v2']]:
  if all((OUT/t/'matte.json').exists() for t in takes):continue
  with exclusive('gpu'):
   needed=[t for t in takes if not (OUT/t/'sampling_history.json').exists()]
   if needed:run('run_generation.py','sample',*needed)
   needed=[t for t in takes if not (OUT/t/'original.json').exists()]
   if needed:run('run_generation.py','decode',*needed)
   needed=[t for t in takes if not (OUT/t/'matte.json').exists()]
   if needed:run('segment.py',*needed)
  time.sleep(1)
  print('ACTION_READY',takes,flush=True)
  if a.one_lease:break
