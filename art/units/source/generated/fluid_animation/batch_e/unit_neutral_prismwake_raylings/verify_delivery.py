"""Verify selected original RGB, published alpha pixels, anchors and idle lineage."""
import argparse,json,hashlib
import av
from PIL import Image
import produce as p
from integrate_fluid_creature_animation import resolve,old_pose,source_pose,clip_indices
from pack_overworld_creature_idle import extract
UID='unit_neutral_prismwake_raylings'
def read(path):return json.loads(path.read_bytes())
def equal(a,b):
 assert a[1]==b[1] and a[0].size==b[0].size and a[0].tobytes()==b[0].tobytes()
def run(base):
 row=next(r for r in read(p.ROOT/'content/unit_animation_manifest.json')['items'] if r['unit_id']==UID)
 sheet=Image.open(resolve(row['pose_sheet'])).convert('RGBA');assert max(sheet.size)<=4096
 assert sheet.width*sheet.height*4<=64*1024*1024,'Runtime atlas exceeds the decoded RGBA budget'
 packet=read(p.SOURCE_DIR/'handoff.json')['units'][0];poses=0;originals=0
 for clip,spec in packet['clips'].items():
  packed=clip_indices(row['pose_clips'][clip],row['pose_columns']);assert len(packed)==len(spec['indices'])
  for i,j in zip(spec['indices'],packed):equal(source_pose(packet['frames'][i],0),old_pose(sheet,row,j));poses+=1
 for record in packet['provenance'].values():assert p.sha(p.ROOT/record['path'])==record['sha256'],record['path']
 assert set(row['pose_accepted_clips'])=={'idle','move','attack','ranged','cast','hit','defend','death'}
 assert row['pose_clips']['dead']['indices']==[row['pose_clips']['death']['indices'][-1]]
 assert not any(k in row.get('pose_aliases',{}) for k in ['hit','cast','ranged'])
 assert 0 <= row['pose_clips']['ranged']['contact_frame'] < row['pose_clips']['ranged']['frames']
 maprow=read(p.ROOT/'art/overworld/creature_idle.json')['units'][UID];actual=Image.open(resolve(maprow['path'])).convert('RGBA');rebuilt,meta=extract(row)
 assert actual.size==rebuilt.size and actual.tobytes()==rebuilt.tobytes();assert p.sha(resolve(maprow['path']))==maprow['sha256']
 baseline_idle=Image.open(base/'baseline_map_idle.png').convert('RGBA');assert baseline_idle.size==actual.size and baseline_idle.tobytes()==actual.tobytes()
 old=next(r for r in read(base/'baseline_manifest.json')['items'] if r['unit_id']==UID);before=Image.open(base/'baseline_atlas.png').convert('RGBA')
 assert row['pose_clips']['idle']['frame_msec']==old['pose_clips']['idle']['frame_msec']==200
 for i,j in zip(clip_indices(old['pose_clips']['idle'],old['pose_columns']),clip_indices(row['pose_clips']['idle'],row['pose_columns'])):equal(old_pose(before,old,i),old_pose(sheet,row,j))
 selected_takes=set(read(p.SOURCE_DIR/'delivery.json')['takes']);selected_originals=0
 tools={p.sha(path) for path in p.SOURCE_DIR.glob('*.py')}
 for files in read(p.SOURCE_DIR/'original_source_inventory.json')['takes'].values():
  for item in files.values():assert (p.ROOT/item['path']).stat().st_size==item['bytes'] and p.sha(p.ROOT/item['path'])==item['sha256']
 for item in read(p.SOURCE_DIR/'original_source_inventory.json').get('guide_art',{}).values():
  assert (p.ROOT/item['path']).stat().st_size==item['bytes'] and p.sha(p.ROOT/item['path'])==item['sha256']
 for out in sorted(path for path in p.SOURCE_DIR.iterdir() if path.is_dir() and (path/'original.json').exists()):
  record=read(out/'original.json');assert p.sha(out/'original_lossless.mkv')==record['sha256']
  staged=read(out/'staged_generation.json')
  assert p.sha(out/'original.latent')==staged['latent_sha256']
  assert p.sha(out/'sampling_workflow_api.json')==staged['sampling_workflow_sha256']
  assert p.sha(out/'workflow_api.json')==staged['decode_workflow_sha256']==record['workflow_sha256']
  assert (out/'original.mp4').stat().st_size>0
  with av.open(str(out/'original_lossless.mkv')) as stream:hashes=[hashlib.sha256(f.to_image().convert('RGB').tobytes()).hexdigest() for f in stream.decode(video=0)]
  assert hashes==record['decoded_rgb_sha256'];originals+=len(hashes)
  if out.name in selected_takes:selected_originals+=len(hashes)
  if out.name in selected_takes:
   assert read(out/'segmentation_recipe.json')['tool_sha256'] in tools
   assert read(out/'matte.json')['edge_despill_tool_sha256'] in tools
  else:
   assert read(p.SOURCE_DIR/'rejected_takes.json')[out.name]['status']=='rejected'
   if (out/'segmentation_recipe.json').exists():assert read(out/'segmentation_recipe.json')['tool_sha256'] in tools
   if (out/'matte.json').exists():assert read(out/'matte.json')['edge_despill_tool_sha256'] in tools
   if (out/'failed_matte.json').exists():
    failed=read(out/'failed_matte.json');assert failed['tool_sha256'] in tools
    for i,expected in enumerate(failed['rgba_sha256']):
     file=out/'matte'/f'rgba_{i:03}.png'
     if file.exists():assert expected and p.sha(file)==expected
  for guide in read(out/'reference.json')['guides']:
   assert p.sha(out/guide['input_file'])==guide['input_sha256'];assert p.sha(p.ROOT/guide['source_frame']['source'])==guide['source_sha256']
 print('SOURCE_VERIFIED',json.dumps(dict(original_rgb_frames=originals,selected_take_original_rgb_frames=selected_originals,selected_published_poses=poses,atlas_size=sheet.size,rgba_bytes=sheet.width*sheet.height*4,preserved_idle=8,exact_map_pixels=True,exact_original_source_pixels_and_anchors=True)))
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('--baseline-dir',type=p.Path,required=True);args=a.parse_args();run(args.baseline_dir)
