"""Verify task-owned duplicate outputs before emitting an exact cleanup manifest.

Does not delete anything. Preserve originals, all guide sources and published mattes.
"""
import hashlib
import json
from pathlib import Path
from PIL import Image
import produce as p

if __name__=='__main__':
 q=p.request(p.URL,'/queue');assert not q['queue_running'] and not q['queue_pending']
 entry=json.loads((p.SOURCE_DIR/'handoff.json').read_bytes())['units'][0]
 keep={(p.ROOT/f['source']).resolve() for f in entry['frames']}
 for f in p.SOURCE_DIR.glob('*_h3_v*/config.json'):
  keep.update((p.ROOT/r['source']).resolve() for r in json.loads(f.read_bytes())['references'])
 comfy=Path('H:/ai/minimax-h3/ComfyUI');records={}
 def record(path):
  path=path.resolve();assert path.is_file() and path not in keep
  assert path.is_relative_to(p.SOURCE_DIR) or path.is_relative_to(comfy/'input') or path.is_relative_to(comfy/'output/sapwhistle_h3')
  records[str(path)]=dict(path=str(path),bytes=path.stat().st_size,sha256=p.sha(path))
 for take in sorted(p.SOURCE_DIR.glob('*_h3_v*')):
  if not (take/'original.json').exists():continue
  original=json.loads((take/'original.json').read_bytes());assert p.sha(take/'original_lossless.mkv')==original['sha256']
  history=json.loads((take/'generation_history.json').read_bytes())
  for i,item in enumerate(history['outputs']['15']['images']):
   path=comfy/'output'/item['subfolder']/item['filename']
   if path.exists():
    assert hashlib.sha256(Image.open(path).convert('RGB').tobytes()).hexdigest()==original['decoded_rgb_sha256'][i];record(path)
  for values in history['outputs'].get('14',{}).values():
   if not isinstance(values,list):continue
   for item in values:
    if isinstance(item,dict) and str(item.get('filename','')).endswith('.mp4'):
     path=comfy/'output'/item['subfolder']/item['filename']
     if path.exists():assert p.sha(path)==p.sha(take/'original.mp4');record(path)
  sampling=json.loads((take/'sampling_history.json').read_bytes())['outputs']['16']['latents'][0]
  path=comfy/'output'/sampling['subfolder']/sampling['filename']
  if path.exists():assert p.sha(path)==p.sha(take/'original.latent');record(path)
  submitted=json.loads((take/'sampling_submission.json').read_bytes())
  for key,item in submitted['uploaded'].items():
   path=comfy/'input'/item.get('subfolder','')/item['name']
   if path.exists():assert p.sha(path)==p.sha(take/f'guide_{int(key)-30}_chroma.png');record(path)
  for path in (take/'matte').glob('*.png'):
   if path.resolve() not in keep:record(path)
 target=p.ROOT/'.artifacts/sapwhistle_h3/cleanup_manifest.json'
 p.write(target,dict(files=list(records.values()),count=len(records),bytes=sum(r['bytes'] for r in records.values()),preserved_guide_and_published_paths=len(keep)))
 print(json.dumps(dict(files=len(records),bytes=sum(r['bytes'] for r in records.values()),manifest=str(target))))
