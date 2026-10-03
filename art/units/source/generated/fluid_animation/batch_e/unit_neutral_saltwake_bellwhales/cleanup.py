"""Delete only byte-proven duplicate outputs and this unit's disposable reviews."""
import json,hashlib,os,contextlib
from pathlib import Path
from PIL import Image
import produce as p
from creature_animation_lock import exclusive
UID='unit_neutral_saltwake_bellwhales'
PREFIX='saltwake_bellwhale_h3'
BASE=Path('H:/ai/minimax-h3/ComfyUI')

def verify_inactive():
 import psutil
 own=psutil.Process();parents={own.pid,*[a.pid for a in own.parents()]};active=[]
 for process in psutil.process_iter(['pid','name','cmdline']):
  if process.info['pid'] in parents:continue
  if UID in ' '.join(process.info.get('cmdline') or []):active.append(process.info['pid'])
 assert not active,('Own targets may still be in use',active)
def checked(path,root):
 path=path.resolve();root=root.resolve();assert path.is_relative_to(root) and path!=root;assert path.is_file() and not path.is_symlink();return path

def remove(path,root,record):
 path=checked(path,root);size=path.stat().st_size;path.unlink();record['files']+=1;record['bytes']+=size

def cleanup_duplicates(cpu_only=False):
 record=dict(files=0,bytes=0)
 with (contextlib.nullcontext() if cpu_only else exclusive('gpu')):
  q=p.request(p.URL,'/queue')
  if cpu_only:
   # Coordinator-authorized file-only cleanup: foreign GPU graphs can run,
   # but no graph or process may reference these exact owned prefixes.
   graphs=q['queue_running']+q['queue_pending']
   assert all('saltwake_bellwhale' not in json.dumps(item[2]).casefold() for item in graphs),'An active graph references owned Saltwake targets'
   import psutil
   own_output=str((BASE/'output'/PREFIX).resolve()).casefold()+os.sep
   own_input=str((BASE/'input').resolve()).casefold()+os.sep+'saltwake_bellwhale_'
   handles=[]
   for process in psutil.process_iter(['pid','name']):
    if process.pid==os.getpid():continue
    try:
     for file in process.open_files():
      path=str(Path(file.path).resolve()).casefold()
      if path.startswith(own_output) or path.startswith(own_input):handles.append((process.pid,path))
    except (psutil.AccessDenied,psutil.NoSuchProcess):continue
   assert not handles,('Owned external targets have active handles',handles)
   print('CPU_DUPLICATE_SCOPE_PROVED no active graph or accessible own-file handle; source hashes checked before each deletion',flush=True)
  else:assert not q['queue_running'] and not q['queue_pending'],'Do not touch active Comfy outputs'
  for take in p.SOURCE_DIR.glob('*_h3_v*'):
   if not (take/'original.json').exists():continue
   c=json.loads((take/'original.json').read_bytes());h=json.loads((take/'generation_history.json').read_bytes())
   for index,item in enumerate(h['outputs']['15']['images']):
    f=checked(BASE/'output'/item['subfolder']/item['filename'],BASE/'output'/PREFIX/take.name)
    assert hashlib.sha256(Image.open(f).convert('RGB').tobytes()).hexdigest()==c['decoded_rgb_sha256'][index]
    remove(f,BASE/'output'/PREFIX/take.name,record)
   hist=json.loads((take/'sampling_history.json').read_bytes());item=hist['outputs']['16']['latents'][0]
   f=checked(BASE/'output'/item['subfolder']/item['filename'],BASE/'output'/PREFIX/take.name);assert p.sha(f)==p.sha(take/'original.latent');remove(f,BASE/'output'/PREFIX/take.name,record)
   for items in h['outputs'].get('14',{}).values():
    if isinstance(items,list):
     for item in items:
      if isinstance(item,dict) and item.get('filename','').endswith('.mp4'):
       f=checked(BASE/'output'/item['subfolder']/item['filename'],BASE/'output'/PREFIX/take.name);assert p.sha(f)==p.sha(take/'original.mp4');remove(f,BASE/'output'/PREFIX/take.name,record)
   s=json.loads((take/'sampling_submission.json').read_bytes())
   for key,item in s['uploaded'].items():
    assert item['name'].startswith('saltwake_bellwhale_') and not item.get('subfolder')
    f=checked(BASE/'input'/item['name'],BASE/'input');assert p.sha(f)==p.sha(take/f'guide_{int(key)-30}_chroma.png');remove(f,BASE/'input',record)
 return record

def cleanup_unselected():
 record=dict(files=0,bytes=0)
 handoff=json.loads((p.SOURCE_DIR/'handoff.json').read_bytes())['units'][0]
 required={str((p.ROOT/f['source']).resolve()) for f in handoff['frames']}
 for f in p.SOURCE_DIR.glob('*_h3_v*/matte/*.png'):
  if str(f.resolve()) not in required:remove(f,p.SOURCE_DIR,record)
 return record

if __name__=='__main__':
 import argparse
 a=argparse.ArgumentParser();a.add_argument('mode',choices=['duplicates','duplicates_cpu','unselected','reviews']);args=a.parse_args();verify_inactive()
 if args.mode in ['duplicates','duplicates_cpu']:rec=cleanup_duplicates(cpu_only=args.mode=='duplicates_cpu')
 elif args.mode=='unselected':rec=cleanup_unselected()

 else:
  root=p.ROOT/'.artifacts/parallel_animation_20261002'/UID;assert root.resolve().is_relative_to((p.ROOT/'.artifacts/parallel_animation_20261002').resolve());rec=dict(files=0,bytes=0)
  # Only this new, owned review directory. Never touch sibling evidence.
  for f in sorted(root.rglob('*')):
   if f.is_file():remove(f,root,rec)
  for d in sorted((d for d in root.rglob('*') if d.is_dir()),key=lambda x:len(x.parts),reverse=True):d.rmdir()
  root.rmdir()
 print(json.dumps(rec));name='duplicates' if args.mode=='duplicates_cpu' else args.mode;dest=p.SOURCE_DIR/f'cleanup_{name}.json';p.write(dest,rec)
