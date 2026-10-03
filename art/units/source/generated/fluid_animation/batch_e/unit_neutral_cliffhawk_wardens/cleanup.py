"""Exact inactive own evidence and byte/pixel-proven Comfy duplicate cleanup."""
from pathlib import Path
import json,os,shutil,subprocess,hashlib,urllib.request
from PIL import Image
S=Path(__file__).parent;R=next(p for p in S.parents if (p/'project.godot').exists());A=R/'.artifacts/parallel_animation_20261002/middle53_completion_audit';H=Path('H:/ai/minimax-h3/ComfyUI')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_bytes())
c=read(S/'completion.json');assert c['status']=='complete_selected_unit' and not c['validation']['failures']
process=subprocess.run(['powershell','-NoProfile','-Command',"Get-CimInstance Win32_Process | Where-Object {$_.Name -match 'python|godot'} | Select-Object ProcessId,CommandLine | ConvertTo-Json -Compress"],capture_output=True,text=True,check=True)
rows=json.loads(process.stdout or '[]');rows=rows if isinstance(rows,list) else [rows]
for row in rows:
 if row['ProcessId']==os.getpid():continue
 command=(row.get('CommandLine') or '').replace('\\','/').lower();assert 'middle53_completion_audit' not in command and 'unit_neutral_cliffhawk_wardens/' not in command,(row['ProcessId'],command)
queue=json.load(urllib.request.urlopen('http://127.0.0.1:8189/queue'));assert not queue['queue_running'] and not queue['queue_pending'],'Do not remove active original-output duplicates'
allowed={f'batch{i:02}' for i in range(9)}|{'cliffhawk-correction','compact_native.py','prepare_cliffhawk_diagnosis.py','review_middle53.py','source_landmark_review.json','__pycache__'}
assert A.resolve().is_relative_to(R/'.artifacts/parallel_animation_20261002') and A.name=='middle53_completion_audit'
assert {p.name for p in A.iterdir()}<=allowed,'Unowned audit entry; retain all'
assert not subprocess.check_output(['git','ls-files','--',A.relative_to(R).as_posix()]).strip(),'Tracked material; refuse cleanup'
paths=list(A.rglob('*'));assert not A.is_symlink() and not any(p.is_symlink() for p in paths)
# Preserve caches, including any Python cache in the task evidence directory.
targets=[p for p in A.iterdir() if p.name!='__pycache__'];records=[]
for p in targets:
 files=[x for x in p.rglob('*') if x.is_file()] if p.is_dir() else [p]
 assert not any('__pycache__' in x.parts for x in files),'Cache present; retain directory and reassess'
 records.append(dict(path=p.relative_to(R).as_posix(),files=len(files),bytes=sum(x.stat().st_size for x in files),reason='Own cancelled audit or completed changed-death review; source/tooling retained outside evidence'))
original_outputs=[];input_outputs=[]
for take in ['companion_h3_v1','companion_clearance_h3_v2']:
 T=S/take;history=read(T/'generation_history.json');expected={};directory=(H/'output/cliffhawk_companion_fix_h3'/take).resolve();assert directory.is_relative_to(H/'output/cliffhawk_companion_fix_h3')
 def location(item):
  p=(H/'output'/item['subfolder'].replace('\\','/')/item['filename']).resolve();assert p.is_relative_to(directory) and item['type']=='output';return p
 info=read(T/'original.json');images=history['outputs']['15']['images'];assert len(images)==124
 for i,item in enumerate(images):
  p=location(item);assert hashlib.sha256(Image.open(p).convert('RGB').tobytes()).hexdigest()==info['decoded_rgb_sha256'][i],'Original RGB duplicate differs';expected[p]='124 original RGB retained losslessly, each decoded pixel hash verified'
 for items in history['outputs']['14'].values():
  if isinstance(items,list):
   for item in items:
    if isinstance(item,dict) and str(item.get('filename','')).endswith('.mp4'):
     p=location(item);assert sha(p)==sha(T/'original.mp4');expected[p]='Exact original MP4 byte duplicate retained in source'
 item=read(T/'sampling_history.json')['outputs']['16']['latents'][0];p=location(item);assert sha(p)==sha(T/'original.latent');expected[p]='Exact original latent byte duplicate retained in source'
 actual={p.resolve() for p in directory.rglob('*') if p.is_file()};assert actual==set(expected),'Unexpected Comfy files; refuse directory removal';assert not directory.is_symlink() and not any(p.is_symlink() for p in directory.rglob('*'))
 original_outputs.append((directory,dict(path=str(directory),files=len(expected),bytes=sum(p.stat().st_size for p in expected),proof='Exact MP4/latent SHA and all124 decoded RGB hashes match retained original sources')))
 uploaded=read(T/'sampling_submission.json')['uploaded']
 for key,item in uploaded.items():
  assert not item.get('subfolder') and item['name'].startswith('cliffhawk_companion_fix_'+take+'_guide_')
  p=(H/'input'/item['name']).resolve();assert p.is_relative_to(H/'input');i=int(key)-30;assert sha(p)==sha(T/f'guide_{i}_chroma.png');input_outputs.append((p,dict(path=str(p),files=1,bytes=p.stat().st_size,proof='Exact PNG guide bytes retained in own source')))
# Every ownership/path/process/source check above passes before any deletion.
for p in targets:
 if p.is_dir():shutil.rmtree(p)
 else:p.unlink()
 assert not p.exists()
if not any(A.iterdir()):A.rmdir()
for directory,record in original_outputs:shutil.rmtree(directory);assert not directory.exists();records.append(record)
for p,record in input_outputs:p.unlink();assert not p.exists();records.append(record)
parent=H/'output/cliffhawk_companion_fix_h3'
if parent.exists() and not any(parent.iterdir()):parent.rmdir()
c['cleanup']=dict(records=records,files=sum(r['files'] for r in records),bytes=sum(r['bytes'] for r in records),rebuildable=True,preserved='All original/generated guide/art/RGB video/MP4/latent/failed sources, original and derived mattes/composites, provenance and rebuild tooling retained; all caches/saves/backups/RMG and unrelated work preserved.',audit='Exact own middle53 cancelled audit evidence removed after no active path users; no broader workspace cleanup.')
(S/'completion.json').write_text(json.dumps(c,indent=2)+'\n');print('CLIFFHAWK_MEASURED_CLEANUP',c['cleanup']['files'],c['cleanup']['bytes'],flush=True)
