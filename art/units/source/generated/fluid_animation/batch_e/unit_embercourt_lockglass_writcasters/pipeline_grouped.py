"""Two-action bounded leases; preserve every sampler/decode before releasing."""
import json,subprocess,sys,time
from pathlib import Path
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists());SOURCE=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools'))
from creature_animation_lock import exclusive
import stage_video

if __name__=='__main__':
 takes=json.loads((SOURCE/'delivery.json').read_bytes())['takes']
 decoded=[take for take in takes if (SOURCE/take/'original.json').exists() and not (SOURCE/take/'matte.json').exists()]
 for start in range(0,len(decoded),2):
  with exclusive('gpu'):subprocess.run([sys.executable,str(SOURCE/'segment.py'),*decoded[start:start+2]],check=True,cwd=ROOT)
  time.sleep(15)
 pending=[take for take in takes if not (SOURCE/take/'original.json').exists()]
 for start in range(0,len(pending),2):
  group=pending[start:start+2];assert 1<=len(group)<=2
  with exclusive('gpu'):
   for i,take in enumerate(group):stage_video.run(take,phase='sample',release=i==0)
   for i,take in enumerate(group):stage_video.run(take,phase='decode',release=i==0)
  for take in group:
   subprocess.run([sys.executable,str(SOURCE/'review_originals.py'),'raw',take],check=True,cwd=ROOT)
   print('RAW_CHRONOLOGICAL_READY',take,flush=True)
  time.sleep(15)
  matte=[take for take in group if not (SOURCE/take/'matte.json').exists()]
  if matte:
   with exclusive('gpu'):subprocess.run([sys.executable,str(SOURCE/'segment.py'),*matte],check=True,cwd=ROOT)
  print('COMPLETE_BOUNDED_TWO_ACTION_GROUP',group,flush=True);time.sleep(15)
 # Resumed decoded-but-unmatted takes are also bounded to at most two.
 remaining=[take for take in takes if not (SOURCE/take/'matte.json').exists()]
 for start in range(0,len(remaining),2):
  with exclusive('gpu'):subprocess.run([sys.executable,str(SOURCE/'segment.py'),*remaining[start:start+2]],check=True,cwd=ROOT)
  time.sleep(15)
 print('ALL_ORIGINAL_ACTION_STAGES_COMPLETED',flush=True)
