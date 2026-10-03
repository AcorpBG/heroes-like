"""Verify original pixels, registration, model guides and unchanged other units."""
import argparse,hashlib,json
from pathlib import Path
import av
import numpy as np
from PIL import Image
import produce as p
from integrate_fluid_creature_animation import old_pose,source_pose,clip_indices,resolve
from pack_overworld_creature_idle import extract
UID='unit_thornwake_woundroot_rootmaul_behemoths'
def read(path):return json.loads(Path(path).read_bytes())
def equal_pose(a,b):
 assert a[1]==b[1],(a[1],b[1]);assert a[0].size==b[0].size;assert a[0].tobytes()==b[0].tobytes()
def verify(baseline):
 oldrows=read(baseline/'baseline_manifest.json')['items'];rows=read(p.ROOT/'content/unit_animation_manifest.json')['items']
 assert [r for r in oldrows if r['unit_id']!=UID]==[r for r in rows if r['unit_id']!=UID]
 new=next(r for r in rows if r['unit_id']==UID);sheet=Image.open(resolve(new['pose_sheet'])).convert('RGBA');assert max(sheet.size)<=4096
 handoff=read(p.SOURCE_DIR/'handoff.json')['units'][0];published=0
 for name,spec in handoff['clips'].items():
  live=clip_indices(new['pose_clips'][name],new['pose_columns']);assert len(live)==len(spec['indices'])
  for key in ['frame_msec','frame_durations_msec','contact_frame','loop','static_frame']:
   if key in spec:assert new['pose_clips'][name][key]==spec[key],(name,key)
  for idx,packed in zip(spec['indices'],live):
   frame=handoff['frames'][idx];original=Image.open(p.ROOT/frame['source']).convert('RGBA')
   bounds=original.getchannel('A').point(lambda a:255 if a>=128 else 0).getbbox()
   assert bounds and bounds[0]>0 and bounds[1]>0 and bounds[2]<original.width and bounds[3]<original.height,('Clipped original root claw/body/body',frame['source'],bounds)
   equal_pose(source_pose(frame,0),old_pose(sheet,new,packed));published+=1
 for rec in handoff['provenance'].values():assert p.sha(p.ROOT/rec['path'])==rec['sha256'],rec['path']
 assert new['pose_clips']['dead']['indices']==[new['pose_clips']['death']['indices'][-1]]
 assert set(new['pose_accepted_clips'])=={'idle','move','attack','hit','defend','cast','death'}
 assert 'cast' not in new.get('pose_aliases',{})
 oldmap=read(baseline/'baseline_map.json')['units'];newmap=read(p.ROOT/'art/overworld/creature_idle.json')['units']
 assert {k:v for k,v in oldmap.items() if k!=UID}=={k:v for k,v in newmap.items() if k!=UID}
 rebuilt,meta=extract(new);actual=Image.open(resolve(newmap[UID]['path'])).convert('RGBA')
 assert max(actual.size)<=4096,actual.size
 assert rebuilt.size==actual.size and rebuilt.tobytes()==actual.tobytes()
 assert {k:v for k,v in newmap[UID].items() if k!='sha256'}==meta
 assert newmap[UID]['sha256']==p.sha(resolve(newmap[UID]['path']))
 assert newmap[UID]['source_sheet']==new['pose_sheet'] and newmap[UID]['source_sha256']==p.sha(resolve(new['pose_sheet']))
 assert newmap[UID]['source_indices']==clip_indices(new['pose_clips']['idle'],new['pose_columns'])
 baseline_idle=Image.open(baseline/'baseline_map_idle.png').convert('RGBA')
 assert actual.size==baseline_idle.size and actual.tobytes()==baseline_idle.tobytes()
 assert newmap[UID]['frame_msec']==oldmap[UID]['frame_msec']
 old=next(r for r in oldrows if r['unit_id']==UID)
 baseline_sheet=Image.open(baseline/'baseline_atlas.png').convert('RGBA')
 for before,after in zip(clip_indices(old['pose_clips']['idle'],old['pose_columns']),clip_indices(new['pose_clips']['idle'],new['pose_columns'])):
  equal_pose(old_pose(baseline_sheet,old,before),old_pose(sheet,new,after))
 assert len(clip_indices(new['pose_clips']['idle'],new['pose_columns']))==8
 hashes_total=0;opaque_source_poses=0
 delivery=read(p.SOURCE_DIR/'delivery.json')
 for take_name in delivery['takes']+delivery.get('failed_takes',[]):
  take=p.SOURCE_DIR/take_name;record=read(take/'original.json');assert p.sha(take/'original_lossless.mkv')==record['sha256']
  config=read(take/'config.json');sample=read(take/'sampling_workflow_api.json');decode=read(take/'workflow_api.json');staged=read(take/'staged_generation.json')
  assert config['canvas']==record['size']==[960,640] and record['frames']==124 and record['fps']==24
  assert sample['5']['inputs']['prompt']==config['prompt']==(take/'prompt.txt').read_text(encoding='utf-8').strip()
  assert sample['7']['inputs']['noise_seed']==config['seed']
  assert sample['9']['inputs']['steps']==20 and sample['9']['inputs']['scheduler']=='simple' and sample['8']['inputs']['sampler_name']=='res_multistep'
  assert sample['1']['inputs']['unet_name']=='minimax_h3_fl2va_pruned_int8_convrot.safetensors'
  assert sample['2']['inputs']['clip_name']=='qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors'
  assert decode['11']['inputs']==dict(samples=['10',0],vae=['3',0],**config['tiled_decode'])
  assert p.sha(take/'original.latent')==staged['latent_sha256']
  assert p.sha(take/'sampling_workflow_api.json')==staged['sampling_workflow_sha256'] and p.sha(take/'workflow_api.json')==staged['decode_workflow_sha256']==record['workflow_sha256']
  for history in ['sampling_history.json','generation_history.json']:assert read(take/history)['status']['status_str']=='success'

  selected=set(read(take/'selection.json')['source_frames']) if take_name in delivery['takes'] else set()
  matte=read(take/'matte.json') if selected else None
  hashes=[]
  with av.open(str(take/'original_lossless.mkv')) as video:
   for index,decoded in enumerate(video.decode(video=0)):
    rgb=decoded.to_image().convert('RGB');hashes.append(hashlib.sha256(rgb.tobytes()).hexdigest())
    if index in selected:
     file=take/matte['matte_directory']/f'rgba_{index:03}.png'
     assert p.sha(file)==matte['rgba_sha256'][index]
     rgba=np.asarray(Image.open(file).convert('RGBA'));opaque=rgba[:,:,3]>=250
     assert opaque.any() and np.array_equal(rgba[:,:,:3][opaque],np.asarray(rgb)[opaque]),('Opaque original subject RGB changed',take_name,index)
     opaque_source_poses+=1
  assert hashes==record['decoded_rgb_sha256'];hashes_total+=len(hashes)
  for guide in read(take/'reference.json')['guides']:
   assert p.sha(take/guide['input_file'])==guide['input_sha256'];assert p.sha(p.ROOT/guide['source_frame']['source'])==guide['source_sha256']
 print('Original RGB frames:',hashes_total,'published action poses:',published)
 assert opaque_source_poses==published,(opaque_source_poses,published)
 print('Selected opaque original RGB exact:',opaque_source_poses)
 print('Other231 battle/map rows preserved; accepted map idle pixels/timing preserved exactly.')
 print('Atlas:',sheet.size,'RGBA bytes:',sheet.width*sheet.height*4)
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--baseline-dir',type=Path,required=True);args=parser.parse_args();verify(args.baseline_dir)
