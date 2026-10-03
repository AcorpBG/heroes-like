"""Remove only byte-proven duplicates and this unit's disposable intermediates."""
import argparse,hashlib,json,shutil,sys,urllib.request
from pathlib import Path
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
OUT=Path(__file__).resolve().parent
UID='unit_brasshollow_whitegauge_datum_breach_cannons'
COMFY=Path('H:/ai/minimax-h3/ComfyUI')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def contained(p,root):
 p=p.resolve();root=root.resolve();assert p.is_relative_to(root) and p!=root,(p,root);return p
def read(p):return json.loads(p.read_bytes())
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--external',action='store_true');args=parser.parse_args()
 completion=read(OUT/'completion.json');assert completion['validation']['failures']==[]
 handoff=read(OUT/'handoff.json')['units'][0]
 selected={contained(ROOT/f['source'],OUT) for f in handoff['frames']}
 files=[];trees=[];recipes=[]
 if args.external:
  queue=json.load(urllib.request.urlopen('http://127.0.0.1:8189/queue'))
  for jobs in queue.values():
   for j in jobs:
    assert not any('whitegauge_breach_cannon_h3' in str(n['inputs'].get('filename_prefix','')) for n in j[2].values()),'Own output currently active'
  for take in OUT.glob('*_h3_v*'):
   if not (take/'original.json').exists():continue
   original=read(take/'original.json');assert sha(take/'original_lossless.mkv')==original['sha256']
   hist=read(take/'generation_history.json');sample=read(take/'sampling_history.json')
   import av
   with av.open(str(take/'original_lossless.mkv')) as v:hashes=[hashlib.sha256(f.to_image().convert('RGB').tobytes()).hexdigest() for f in v.decode(video=0)]
   assert hashes==original['decoded_rgb_sha256']
   from PIL import Image
   for i,loc in enumerate(hist['outputs']['15']['images']):
    path=contained(COMFY/'output'/loc['subfolder']/loc['filename'],COMFY/'output'/'whitegauge_breach_cannon_h3'/take.name)
    if path.exists():
     assert hashlib.sha256(Image.open(path).convert('RGB').tobytes()).hexdigest()==hashes[i];files.append(path)
   for loc in sample['outputs']['16']['latents']:
    path=contained(COMFY/'output'/loc['subfolder']/loc['filename'],COMFY/'output'/'whitegauge_breach_cannon_h3'/take.name)
    if path.exists():assert sha(path)==sha(take/'original.latent');files.append(path)
   for values in hist['outputs']['14'].values():
    if isinstance(values,list):
     for loc in values:
      if isinstance(loc,dict) and loc.get('filename','').endswith('.mp4'):
       path=contained(COMFY/'output'/loc['subfolder']/loc['filename'],COMFY/'output'/'whitegauge_breach_cannon_h3'/take.name)
       if path.exists():assert sha(path)==sha(take/'original.mp4');files.append(path)
   submission=read(take/'sampling_submission.json')
   for node,loc in submission['uploaded'].items():
    name=loc['name'];assert name.startswith('whitegauge_breach_cannon_') and '/' not in name and '\\' not in name
    path=contained(COMFY/'input'/name,COMFY/'input');index=int(node)-30
    if path.exists():assert sha(path)==sha(take/f'guide_{index}_chroma.png');files.append(path)
 else:
  artifacts=ROOT/'.artifacts/parallel_animation_20261002'/UID
  if artifacts.exists():trees.append(contained(artifacts,ROOT/'.artifacts/parallel_animation_20261002'))
  for cache in OUT.rglob('__pycache__'):trees.append(contained(cache,OUT))
  for take in OUT.glob('*_h3_v*'):
   for name in ['matte','matte_v2','matte_v3']:
    matte=take/name
    if matte.exists():
     record=read(take/(name+'.json'))
     for file in matte.glob('rgba_*.png'):
      if file.resolve() not in selected:
       i=int(file.stem.split('_')[-1]);assert sha(file)==record['rgba_sha256'][i];files.append(contained(file,OUT))
   partial=take/'matte_initial_partial'
   if partial.exists():
    record=read(take/'initial_partial_matte.json')
    for file in partial.glob('rgba_*.png'):
     assert sha(file)==record['files'][file.name];files.append(contained(file,OUT))
 # The caller waits for this unit's generation/render processes to exit before
 # invoking cleanup. No deletion includes other units, shared caches or saves.
 files=list(dict.fromkeys(files))
 sizes={str(p):p.stat().st_size for p in files}
 for tree in trees:
  for p in tree.rglob('*'):
   if p.is_file():sizes[str(p)]=p.stat().st_size
 removed=sum(sizes.values())
 for file in files:file.unlink()
 for tree in trees:shutil.rmtree(tree)
 # Empty task-owned directory shells can be removed without touching any
 # unknown file. rmdir deliberately fails for a directory with retained data.
 directory_root=COMFY/'output'/'whitegauge_breach_cannon_h3' if args.external else OUT
 if directory_root.exists():
  for directory in sorted((p for p in directory_root.rglob('*') if p.is_dir()),key=lambda p:len(p.parts),reverse=True):
   contained(directory,directory_root)
   if not any(directory.iterdir()):directory.rmdir()
  if args.external and not any(directory_root.iterdir()):
   assert directory_root.resolve()==(COMFY/'output'/'whitegauge_breach_cannon_h3').resolve()
   directory_root.rmdir()
 key='external_comfy_duplicates' if args.external else 'temporary_reviews_profiles_and_unselected_mattes'
 completion.setdefault('cleanup',{})[key]=dict(files=len(sizes),bytes_removed=removed,rebuildable=True)
 (OUT/'completion.json').write_text(json.dumps(completion,indent=2)+'\n',encoding='utf-8')
 print('CLEANED',key,len(sizes),removed,flush=True)
