"""Measured exact-owned cleanup; original source/provenance/cache retention is mandatory."""
import argparse,hashlib,json,os,subprocess,urllib.request
from pathlib import Path
from PIL import Image
import produce as p
UID='unit_brasshollow_tallyspring_throwers'
REVIEW=p.ROOT/'.artifacts/parallel_animation_20261002'/UID
COMFY=Path('H:/ai/minimax-h3/ComfyUI')
def read(x):return json.loads(x.read_bytes())
def within(path,parent):
 assert not path.is_symlink();path=path.resolve();parent=parent.resolve();assert path.is_relative_to(parent),(path,parent);return path
def idle():
 cmd="$ErrorActionPreference='Stop'; @((Get-CimInstance Win32_Process | Where-Object {($_.CommandLine -like '*unit_brasshollow_tallyspring_throwers*') -and ($_.CommandLine -notlike '*cleanup_generated.py*')}) | Select-Object ProcessId,Name,CommandLine) | ConvertTo-Json -Compress"
 r=subprocess.run(['powershell','-NoProfile','-Command',cmd],capture_output=True,text=True);assert r.returncode==0,r.stderr;active=json.loads(r.stdout or '[]');assert not active,active
 q=p.request(p.URL,'/queue');assert 'tallyspring_thrower' not in json.dumps(q), 'Own GPU job remains queued/running'
def plan():
 delivery=read(p.SOURCE_DIR/'delivery.json');handoff=read(p.SOURCE_DIR/'handoff.json')['units'][0];keep={p.ROOT/f['source'] for f in handoff['frames']};keep.update(p.ROOT/r['path'] for r in handoff['provenance'].values() if r['path'].lower().endswith('.png'));removals=[]
 for take in delivery['takes']+delivery.get('failed_takes',[]):
  d=p.SOURCE_DIR/take;original=read(d/'original.json');assert p.sha(d/'original_lossless.mkv')==original['sha256']
  recipes={}
  for recipe in ['matte.json','matte_initial.json']:
   if (d/recipe).exists():
    r=read(d/recipe);recipes[r.get('matte_directory','matte')]=r['rgba_sha256']
  if (d/'extraction_failure.json').exists():
   r=read(d/'extraction_failure.json');partial={str(int(k.split('_')[1].split('.')[0])):v for k,v in r.get('failed_partial_matte_sha256',{}).items()}
   if partial:recipes[r.get('failed_partial_matte_directory','matte_plate_v2')]=partial
  for folder in ['matte','matte_plate_v2','matte_plate_v3']:
   target=d/folder
   if not target.exists():continue
   for file in target.glob('rgba_*.png'):
    index=int(file.stem.split('_')[1]);expected=recipes.get(folder)
    # Unknown retained intermediates need human ownership clarification; never sweep them.
    if expected is None:continue
    digest=expected.get(str(index)) if isinstance(expected,dict) else expected[index]
    assert p.sha(file)==digest,(file,digest)
    if file not in keep:removals.append((within(file,p.SOURCE_DIR),'unused_rebuildable_matte'))
  history=read(d/'generation_history.json')
  for i,item in enumerate(history['outputs']['15']['images']):
   assert item['type']=='output';file=COMFY/'output'/item['subfolder']/item['filename'];within(file,COMFY/'output'/'tallyspring_thrower_h3'/take)
   if file.exists():
    assert hashlib.sha256(Image.open(file).convert('RGB').tobytes()).hexdigest()==original['decoded_rgb_sha256'][i];removals.append((file,'duplicate_decoded_rgb'))
  for item in history['outputs'].get('14',{}).values():
   if isinstance(item,list):
    for entry in item:
     if isinstance(entry,dict) and entry.get('filename','').endswith('.mp4'):
      file=COMFY/'output'/entry['subfolder']/entry['filename'];within(file,COMFY/'output'/'tallyspring_thrower_h3'/take)
      if file.exists():assert p.sha(file)==p.sha(d/'original.mp4');removals.append((file,'duplicate_mp4'))
  loc=read(d/'sampling_history.json')['outputs']['16']['latents'][0];file=COMFY/'output'/loc['subfolder']/loc['filename'];within(file,COMFY/'output'/'tallyspring_thrower_h3'/take)
  if file.exists():assert p.sha(file)==p.sha(d/'original.latent');removals.append((file,'duplicate_latent'))
  refs=read(d/'reference.json')['guides'];uploaded=read(d/'sampling_submission.json')['uploaded']
  for i,ref in enumerate(refs):
   item=uploaded[str(30+i)];assert not item.get('subfolder') and item['name'].startswith('tallyspring_thrower_'+take+'_guide_');file=COMFY/'input'/item['name'];within(file,COMFY/'input')
   if file.exists():assert p.sha(file)==ref['input_sha256'];removals.append((file,'duplicate_uploaded_guide'))
 for file in REVIEW.rglob('*'):
  if file.is_file() and '__pycache__' not in file.parts:removals.append((within(file,REVIEW),'temporary_review'))
 seen=set();unique=[]
 for file,kind in removals:
  key=str(file.resolve()).lower()
  if key not in seen:seen.add(key);unique.append((file,kind))
 return unique
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('--apply',action='store_true');args=a.parse_args();idle();items=plan();result={};total=0
 for file,kind in items:
  size=file.stat().st_size;result.setdefault(kind,dict(files=0,bytes=0));result[kind]['files']+=1;result[kind]['bytes']+=size;total+=size
 if args.apply:
  for file,kind in items:
   with file.open('rb+') as h:pass
   file.unlink()
  # Empty task-owned directories only; keep bytecode and all unknown/cached/source files.
  for folder in sorted([x for x in REVIEW.rglob('*') if x.is_dir()],key=lambda x:len(x.parts),reverse=True):
   within(folder,REVIEW)
   if not any(folder.iterdir()):folder.rmdir()
  if REVIEW.exists() and not any(REVIEW.iterdir()):REVIEW.rmdir()
 print(json.dumps(dict(applied=args.apply,removed_files=len(items),recovered_bytes=total,categories=result,original_videos_latents_guides_prompts_provenance_and_caches_preserved=True,rebuildable=True),indent=2),flush=True)
