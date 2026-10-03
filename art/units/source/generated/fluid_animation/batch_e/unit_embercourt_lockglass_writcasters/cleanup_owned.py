"""Remove only verified inactive, rebuildable outputs of this unit's production."""
import argparse,hashlib,json
from pathlib import Path
from PIL import Image
import produce as p

def digest(path):
 with path.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()

def under(path,root):
 path=path.resolve();assert path.is_relative_to(root.resolve()) and path!=root.resolve();return path

def planned():
 queue=p.request(p.URL,'/queue')
 for job in queue.get('queue_running',[])+queue.get('queue_pending',[]):
  assert 'lockglass_writcaster' not in json.dumps(job),'Own Comfy job still uses sources'
 candidates={};preserved=[]
 leaf=p.ROOT/'.artifacts/parallel_animation_20261002'/p.SOURCE_DIR.name
 output=Path('H:/ai/minimax-h3/ComfyUI/output');inputs=Path('H:/ai/minimax-h3/ComfyUI/input')
 def add(path,kind):
  if path.exists():
   assert path.is_file();resolved=path.resolve()
   assert resolved.is_relative_to(p.SOURCE_DIR.resolve()) or resolved.is_relative_to(leaf.resolve()) or resolved.is_relative_to((output/'lockglass_writcaster_h3').resolve()) or (resolved.parent==inputs.resolve() and resolved.name.startswith('lockglass_writcaster_')),resolved
   candidates[resolved]=kind
 rejected={r['take'] for r in json.loads((p.SOURCE_DIR/'rejected_takes.json').read_bytes())['takes']}
 for take in sorted(p.SOURCE_DIR.glob('*_h3_v*')):
  if not (take/'original.json').exists():continue
  rec=json.loads((take/'original.json').read_bytes());assert digest(take/'original_lossless.mkv')==rec['sha256']
  history=json.loads((take/'generation_history.json').read_bytes());images=history['outputs']['15']['images'];assert len(images)==124
  for index,item in enumerate(images):
   path=under(output/item['subfolder'].replace('\\','/')/item['filename'],output/'lockglass_writcaster_h3'/take.name)
   if path.exists():
    assert hashlib.sha256(Image.open(path).convert('RGB').tobytes()).hexdigest()==rec['decoded_rgb_sha256'][index]
    add(path,'Comfy decoded duplicate proven against FFV1 RGB hash')
  for items in history['outputs'].get('14',{}).values():
   if not isinstance(items,list):continue
   for item in items:
    if not isinstance(item,dict) or not item.get('filename','').endswith('.mp4'):continue
    path=under(output/item['subfolder'].replace('\\','/')/item['filename'],output/'lockglass_writcaster_h3'/take.name)
    if path.exists():assert digest(path)==digest(take/'original.mp4');add(path,'byte-identical retained MP4 duplicate')
  staged=json.loads((take/'staged_generation.json').read_bytes());item=staged['latent_output']
  path=under(output/item['subfolder'].replace('\\','/')/item['filename'],output/'lockglass_writcaster_h3'/take.name)
  if path.exists():assert digest(path)==digest(take/'original.latent')==staged['latent_sha256'];add(path,'byte-identical retained latent duplicate')
  for index,reference in enumerate(json.loads((take/'reference.json').read_bytes())['guides']):
   path=under(inputs/f'lockglass_writcaster_{take.name}_guide_{index}.png',inputs)
   if path.exists():assert digest(path)==reference['input_sha256']==digest(take/reference['input_file']);add(path,'byte-identical retained guide duplicate')
  if ((take/'selection.json').exists() or take.name in rejected) and (take/'matte.json').exists():
   selected=set(json.loads((take/'selection.json').read_bytes())['source_frames']) if (take/'selection.json').exists() else set();matte=json.loads((take/'matte.json').read_bytes())
   for path in (take/'matte').glob('rgba_*.png'):
    index=int(path.stem.split('_')[-1]);assert digest(path)==matte['rgba_sha256'][index]
    if index not in selected:
     add(path,'unselected matte rebuildable from retained RGB/model recipe')
     sidecar=path.with_suffix('.png.import')
     if sidecar.exists():
      assert 'source_file="res://'+path.relative_to(p.ROOT).as_posix()+'"' in sidecar.read_text()
      add(sidecar,'obsolete import sidecar for rebuildable unselected matte; cache retained')
   preserved.append(dict(take=take.name,selected_mattes=len(selected),original_frames=rec['frames'],rejected_source=take.name in rejected))
   pending=take/'extraction_pending.json'
   if pending.exists():
    assert json.loads(pending.read_bytes())['status']=='awaiting_semantic_soft_matte'
    add(pending,'obsolete pending status for completed selected matte')
  prior=take/'matte_semantic_initial.json'
  if prior.exists() and (take/'selection.json').exists():
   initial=json.loads(prior.read_bytes());assert initial['tool_sha256']==digest(p.SOURCE_DIR/'segment_initial.py')
   for path in (take/'matte_semantic_initial').glob('rgba_*.png'):
    index=int(path.stem.split('_')[-1]);assert digest(path)==initial['rgba_sha256'][index]
    add(path,'initial fringe extraction rebuildable from original RGB and retained initial semantic recipe')
    sidecar=path.with_suffix('.png.import')
    if sidecar.exists():
     current=path.relative_to(p.ROOT).as_posix();before=(take/'matte'/path.name).relative_to(p.ROOT).as_posix()
     assert any('source_file="res://'+name+'"' in sidecar.read_text() for name in [current,before])
     add(sidecar,'obsolete import sidecar for initial fringe extraction; cache retained')
 leaf=p.ROOT/'.artifacts/parallel_animation_20261002'/p.SOURCE_DIR.name
 if leaf.exists():
  for path in leaf.rglob('*'):
   if path.is_file():add(under(path,leaf),'task-owned disposable review or focused validation output')
 reconstruction=p.SOURCE_DIR/'preserve_uniform_tool.py'
 if reconstruction.exists():
  assert digest(p.SOURCE_DIR/'segment_uniform.py')=='5ce22fd6633573a3b0288805e98b161cb9535ccb5892709998325a4fc6b3ae84'
  add(reconstruction,'completed temporary reconstruction helper; exact uniform recipe retained')
 for name in ['source_verification.json','publication.json']:
  add(p.SOURCE_DIR/name,'results summarized in durable completion.json')
 return candidates,preserved

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--apply',action='store_true');args=parser.parse_args()
 candidates,preserved=planned();before={path:(path.stat().st_size,digest(path),kind) for path,kind in candidates.items()}
 print(json.dumps(dict(files=len(before),bytes=sum(v[0] for v in before.values()),categories=sorted(set(v[2] for v in before.values())),preserved=preserved)))
 if args.apply:
  # Caller must first prove this unit's driver exited and no process uses the
  # leaf. Every exact file remains byte verified immediately before unlink.
  for path,(size,sha,kind) in before.items():
   assert path.stat().st_size==size and digest(path)==sha;path.unlink();assert not path.exists()
  leaf=p.ROOT/'.artifacts/parallel_animation_20261002'/p.SOURCE_DIR.name
  if leaf.exists():
   for directory in sorted([f for f in leaf.rglob('*') if f.is_dir()],key=lambda f:len(f.parts),reverse=True):
    assert directory.resolve().is_relative_to(leaf.resolve())
    if not any(directory.iterdir()):directory.rmdir()
   if not any(leaf.iterdir()):leaf.rmdir()
  result=dict(removed_files=len(before),removed_bytes=sum(v[0] for v in before.values()),all_deleted_paths_rechecked_absent=all(not path.exists() for path in before),preserved=preserved)
  completion=json.loads((p.SOURCE_DIR/'completion.json').read_bytes());completion['cleanup']=result;p.write(p.SOURCE_DIR/'completion.json',completion)
  print('CLEANUP_COMPLETE',json.dumps(result))
