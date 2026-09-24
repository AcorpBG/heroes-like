"""Join reviewed clean recoil/recovery originals at their matching buckler pose."""
import copy,json
from pathlib import Path
from produce import write,sha,ROOT
S=Path(__file__).resolve().parent
parts=['hit_v2','hit_v1'];entry=None;frames=[];provenance={}
for name in parts:
 d=json.loads((S/name/'handoff.json').read_bytes())['units'][0]
 if entry is None:entry=copy.deepcopy(d)
 for f in d['frames']:
  f['name']=name+'_'+f['name'];frames.append(f)
 provenance[name]=dict(path=(S/name/'handoff.json').relative_to(ROOT).as_posix(),sha256=sha(S/name/'handoff.json'))
entry['frames']=frames;entry['clips']={'hit':dict(indices=list(range(len(frames))),frame_msec=50,loop=False,static_frame=0)};entry['provenance']=provenance;entry['visual_review']=dict(status='pending',notes='Recoil hit_v2 source22-32, recovery hit_v1 source40-48. Both exact original intervals share the same buckler-at-cheek pose, scale and ground. Original v1 external effects and v2 colored tail excluded. No reversal/interpolation or geometry edits. Full chronological originals and enlarged transition reviewed; native review pending, continuous playback not claimed.')
(S/'hit_joined').mkdir(exist_ok=True)
write(S/'hit_joined/handoff.json',dict(schema_version=1,units=[entry]))
