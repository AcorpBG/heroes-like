"""Remove only verified task-owned, rebuildable outputs after terminal review."""
import hashlib,json,shutil,subprocess
from pathlib import Path
import av
from PIL import Image
import produce as p

UID='unit_mireclaw_moonbite_votive_drummers'
COMFY=Path('H:/ai/minimax-h3/ComfyUI').resolve()

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_bytes())

def run():
 record=dict(files_removed=0,recovered_bytes=0,duplicate_files_removed=0,duplicate_bytes_removed=0,unused_matte_files_removed=0,unused_matte_bytes_removed=0,temporary_files_removed=0,temporary_bytes_removed=0)
 removed=set()
 def delete(path,kind):
  path=path.resolve();assert path not in removed and path.is_file()
  assert path.is_relative_to(p.SOURCE_DIR) or path.is_relative_to(p.ROOT/'.artifacts/parallel_animation_20261002'/UID) or path.is_relative_to(COMFY/'input') or path.is_relative_to(COMFY/'output/moonbite_votive_h3')
  size=path.stat().st_size;path.unlink();removed.add(path)
  record['files_removed']+=1;record['recovered_bytes']+=size
  record[kind+'_files_removed']+=1;record[kind+'_bytes_removed']+=size
 queue=p.request(p.URL,'/queue')
 own_jobs=set()
 takes=sorted(path for path in p.SOURCE_DIR.iterdir() if path.is_dir() and (path/'original.json').exists())
 delivery=read(p.SOURCE_DIR/'delivery.json');selected_takes=set(delivery['takes'])
 selected_takes.update(delivery.get('attack_segments',[]))
 for sequence in delivery.get('clip_sequences',{}).values():selected_takes.update(frame['take'] for frame in sequence['frames'])
 for out in takes:
  for name in ['sampling_submission.json','decode_submission.json']:
   own_jobs.add(read(out/name)['prompt_id'])
 assert not any(any(job==item for item in entry if isinstance(item,str)) for entry in queue['queue_running']+queue['queue_pending'] for job in own_jobs),'Task job still active; cleanup refused'
 for out in takes:
  original=read(out/'original.json');assert sha(out/'original_lossless.mkv')==original['sha256']
  assert sha(out/'original.latent')==read(out/'staged_generation.json')['latent_sha256']
  with av.open(str(out/'original_lossless.mkv')) as video:
   decoded=[hashlib.sha256(f.to_image().convert('RGB').tobytes()).hexdigest() for f in video.decode(video=0)]
  assert decoded==original['decoded_rgb_sha256'] and len(decoded)==124
  history=read(out/'generation_history.json');images=history['outputs']['15']['images'];assert len(images)==124
  for i,item in enumerate(images):
   path=(COMFY/'output'/item['subfolder']/item['filename']).resolve()
   assert path.is_relative_to(COMFY/'output/moonbite_votive_h3'/out.name)
   if path.exists():
    assert hashlib.sha256(Image.open(path).convert('RGB').tobytes()).hexdigest()==decoded[i]
    delete(path,'duplicate')
  latent=read(out/'sampling_history.json')['outputs']['16']['latents'][0]
  path=(COMFY/'output'/latent['subfolder']/latent['filename']).resolve()
  assert path.is_relative_to(COMFY/'output/moonbite_votive_h3'/out.name)
  if path.exists():assert sha(path)==sha(out/'original.latent');delete(path,'duplicate')
  for items in history['outputs'].get('14',{}).values():
   if not isinstance(items,list):continue
   for item in items:
    if not isinstance(item,dict) or not str(item.get('filename','')).endswith('.mp4'):continue
    path=(COMFY/'output'/item.get('subfolder','')/item['filename']).resolve()
    assert path.is_relative_to(COMFY/'output/moonbite_votive_h3'/out.name)
    if path.exists():assert sha(path)==sha(out/'original.mp4');delete(path,'duplicate')
  guides=read(out/'reference.json')['guides'];uploaded=read(out/'sampling_submission.json')['uploaded']
  for i,guide in enumerate(guides):
   item=uploaded[str(30+i)];assert not item.get('subfolder')
   assert item['name'].startswith('moonbite_votive_'+out.name+'_guide_')
   path=(COMFY/'input'/item['name']).resolve();assert path.parent==COMFY/'input'
   if path.exists():assert sha(path)==guide['input_sha256'];delete(path,'duplicate')
  selected=set(read(out/'selection.json')['source_frames']) if out.name in selected_takes and (out/'selection.json').exists() else set()
  matte_file=out/'matte.json' if (out/'matte.json').exists() else out/'failed_matte.json'
  matte=read(matte_file)['rgba_sha256'] if matte_file.exists() else []
  for i,expected in enumerate(matte):
   path=out/'matte'/f'rgba_{i:03}.png'
   if path.exists() and i not in selected:assert sha(path)==expected;delete(path,'unused_matte')
  pending=out/'extraction_pending.json'
  if pending.exists():
   assert (out/'matte.json').exists() or read(p.SOURCE_DIR/'rejected_takes.json')[out.name]['status']=='rejected'
   delete(pending,'temporary')
 temporary=(p.ROOT/'.artifacts/parallel_animation_20261002'/UID).resolve()
 assert temporary==p.ROOT/'.artifacts/parallel_animation_20261002'/UID
 tracked=subprocess.check_output(['git','ls-files','--',str(temporary.relative_to(p.ROOT))],cwd=p.ROOT)
 assert not tracked.strip(),'Refuse tracked evidence removal'
 if temporary.exists():
  for path in sorted(temporary.rglob('*')):
   if path.is_file():delete(path,'temporary')
  shutil.rmtree(temporary)
 record.update(retained_original_rgb_frames=len(takes)*124,original_videos_latents_guides_prompts_and_provenance_preserved=True,caches_preserved=True,rebuildable=True)
 p.write(p.SOURCE_DIR/'cleanup_result.json',record);print(json.dumps(record))

if __name__=='__main__':run()
