"""Bounded fair GPU stages; never leave an enqueued job without its lock."""
import sys,subprocess,json,time
from pathlib import Path
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
SOURCE=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools'))
from creature_animation_lock import exclusive
import stage_video
T=json.loads((SOURCE/'delivery.json').read_bytes())['takes']
if '--one' in sys.argv:T=T[:1]
for take in T:
 if not (SOURCE/take/'original.json').exists():
  with exclusive('gpu'):
   stage_video.run(take,phase='decode')
  subprocess.run([sys.executable,str(SOURCE/'review_originals.py'),'raw',take],check=True,cwd=ROOT)
  print('RAW_CHRONOLOGICAL_READY',take,flush=True)
  time.sleep(15)  # Outside lock: existing waiters receive the next lease.
 if not (SOURCE/take/'matte.json').exists():
  with exclusive('gpu'):
   subprocess.run([sys.executable,str(SOURCE/'segment.py'),take],check=True,cwd=ROOT)
 print('COMPLETE_ACTION_SOURCE',take,flush=True)
 time.sleep(15)  # Outside lock: personal CPU review may run concurrently.
print('ALL_ORIGINAL_STAGES_COMPLETED',flush=True)
