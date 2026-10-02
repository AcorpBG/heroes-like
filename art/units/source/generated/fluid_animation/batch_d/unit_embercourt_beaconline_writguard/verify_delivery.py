"""Verify six original action recipes and retained idle/catalog/map pixels."""
import argparse,hashlib,json
from pathlib import Path
import av
from PIL import Image
import produce as p
from integrate_fluid_creature_animation import old_pose,source_pose,clip_indices,resolve
UID='unit_embercourt_beaconline_writguard'
def read(path):return json.loads(Path(path).read_bytes())
def equal_pose(a,b):
 assert a[1]==b[1],(a[1],b[1]);assert a[0].size==b[0].size;assert a[0].tobytes()==b[0].tobytes()
def verify(baseline):
 oldrows=read(baseline/'baseline_manifest.json')['items'];newrows=read(p.ROOT/'content/unit_animation_manifest.json')['items']
 assert [r for r in oldrows if r['unit_id']!=UID]==[r for r in newrows if r['unit_id']!=UID]
 old=next(r for r in oldrows if r['unit_id']==UID);new=next(r for r in newrows if r['unit_id']==UID)
 oldsheet=Image.open(baseline/'baseline_atlas.png').convert('RGBA');sheet=Image.open(resolve(new['pose_sheet'])).convert('RGBA');assert max(sheet.size)<=4096
 preserved=0
 for name in ['idle']:
  a,b=old['pose_clips'][name],new['pose_clips'][name]
  assert {k:v for k,v in a.items() if k!='indices'}=={k:v for k,v in b.items() if k!='indices'},name
  ia,ib=clip_indices(a,old['pose_columns']),clip_indices(b,new['pose_columns']);assert len(ia)==len(ib)
  for x,y in zip(ia,ib):equal_pose(old_pose(oldsheet,old,x),old_pose(sheet,new,y));preserved+=1
 handoff=read(p.SOURCE_DIR/'handoff.json')['units'][0];published=0
 for name in ['move','attack','hit','defend','cast','death']:
  spec=handoff['clips'][name];live=clip_indices(new['pose_clips'][name],new['pose_columns']);assert len(live)==len(spec['indices'])
  for idx,packed in zip(spec['indices'],live):equal_pose(source_pose(handoff['frames'][idx],0),old_pose(sheet,new,packed));published+=1
 for rec in handoff['provenance'].values():assert p.sha(p.ROOT/rec['path'])==rec['sha256'],rec['path']
 assert new['pose_clips']['dead']['indices']==[new['pose_clips']['death']['indices'][-1]]
 assert set(new['pose_accepted_clips'])=={'idle','move','attack','hit','defend','cast','death'}
 assert 'cast' not in new.get('pose_aliases',{})
 oldmap=read(baseline/'baseline_map.json')['units'];newmap=read(p.ROOT/'art/overworld/creature_idle.json')['units']
 assert {k:v for k,v in oldmap.items() if k!=UID}=={k:v for k,v in newmap.items() if k!=UID}
 lineage={'source_sha256','source_crop','source_sheet','source_indices','source_provenance'}
 assert {k:v for k,v in oldmap[UID].items() if k not in lineage}=={k:v for k,v in newmap[UID].items() if k not in lineage}
 delta=(new['pose_frame_size']['height']-new['pose_ground_margin'])-(old['pose_frame_size']['height']-old['pose_ground_margin'])
 dx=new.get('pose_anchor_x',new['pose_frame_size']['width']//2)-old.get('pose_anchor_x',old['pose_frame_size']['width']//2)
 x0,y0,x1,y1=oldmap[UID]['source_crop'];assert newmap[UID]['source_crop']==[x0+dx,y0+delta,x1+dx,y1+delta]
 assert oldmap[UID]['source_indices']==clip_indices(old['pose_clips']['idle'],old['pose_columns'])
 assert newmap[UID]['source_indices']==clip_indices(new['pose_clips']['idle'],new['pose_columns'])
 assert newmap[UID]['source_sheet']==new['pose_sheet']
 assert newmap[UID]['source_provenance']=='res://art/animation/source/fluid/'+UID+'/provenance.json'
 assert oldmap[UID]['source_sha256']==p.sha(baseline/'baseline_atlas.png')
 assert newmap[UID]['source_sha256']==p.sha(resolve(new['pose_sheet']))
 a=Image.open(baseline/'baseline_map_idle.png').convert('RGBA');b=Image.open(resolve(newmap[UID]['path'])).convert('RGBA');assert a.size==b.size and a.tobytes()==b.tobytes()
 hashes_total=0
 delivery=read(p.SOURCE_DIR/'delivery.json')
 takes=list(dict.fromkeys(delivery['takes']+[f['take'] for seq in delivery.get('clip_sequences',{}).values() for f in seq['frames']]))
 for take_name in takes:
  take=p.SOURCE_DIR/take_name;record=read(take/'original.json');assert p.sha(take/'original_lossless.mkv')==record['sha256']
  with av.open(str(take/'original_lossless.mkv')) as video:hashes=[hashlib.sha256(f.to_image().convert('RGB').tobytes()).hexdigest() for f in video.decode(video=0)]
  assert hashes==record['decoded_rgb_sha256'];hashes_total+=len(hashes)
  for guide in read(take/'reference.json')['guides']:
   assert p.sha(take/guide['input_file'])==guide['input_sha256'];assert p.sha(p.ROOT/guide['source_frame']['source'])==guide['source_sha256']
 print('Original RGB frames:',hashes_total,'published new action poses:',published,'preserved idle poses:',preserved)
 print('All232 map visuals/timing and other231 battle rows preserved; selected map hash/crop lineage matches new battle atlas.')
 print('Atlas:',sheet.size,'RGBA bytes:',sheet.width*sheet.height*4)
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--baseline-dir',type=Path,required=True);args=parser.parse_args();verify(args.baseline_dir)
