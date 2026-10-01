"""Verify original gait pixels and preservation of all six published actions."""
import argparse,hashlib,json
from pathlib import Path
import av
from PIL import Image
import produce as p
from integrate_fluid_creature_animation import old_pose,source_pose,clip_indices,resolve
UID='unit_neutral_kitehook_runners'
def read(path):return json.loads(Path(path).read_bytes())
def equal_pose(a,b):
 assert a[1]==b[1],(a[1],b[1]);assert a[0].size==b[0].size;assert a[0].tobytes()==b[0].tobytes()
def verify(baseline):
 oldrows=read(baseline/'baseline_manifest.json')['items'];newrows=read(p.ROOT/'content/unit_animation_manifest.json')['items']
 assert [r for r in oldrows if r['unit_id']!=UID]==[r for r in newrows if r['unit_id']!=UID]
 old=next(r for r in oldrows if r['unit_id']==UID);new=next(r for r in newrows if r['unit_id']==UID)
 oldsheet=Image.open(baseline/'baseline_atlas.png').convert('RGBA');sheet=Image.open(resolve(new['pose_sheet'])).convert('RGBA');assert max(sheet.size)<=4096
 preserved=0
 for name in ['idle','attack','hit','defend','cast','death','dead']:
  a,b=old['pose_clips'][name],new['pose_clips'][name]
  assert {k:v for k,v in a.items() if k not in ['indices']}=={k:v for k,v in b.items() if k not in ['indices']},name
  ia,ib=clip_indices(a,old['pose_columns']),clip_indices(b,new['pose_columns']);assert len(ia)==len(ib)
  for x,y in zip(ia,ib):equal_pose(old_pose(oldsheet,old,x),old_pose(sheet,new,y));preserved+=1
 handoff=read(p.SOURCE_DIR/'handoff_solo_move.json')['units'][0];spec=handoff['clips']['move'];live=clip_indices(new['pose_clips']['move'],new['pose_columns']);assert len(live)==len(spec['indices'])
 for idx,packed in zip(spec['indices'],live):equal_pose(source_pose(handoff['frames'][idx],0),old_pose(sheet,new,packed))
 for rec in handoff['provenance'].values():assert p.sha(p.ROOT/rec['path'])==rec['sha256'],rec['path']
 assert new['pose_clips']['dead']['indices']==[new['pose_clips']['death']['indices'][-1]]
 assert set(new['pose_accepted_clips'])=={'idle','move','attack','hit','defend','cast','death'}
 assert old.get('pose_aliases',{})==new.get('pose_aliases',{})
 oldmap=read(baseline/'baseline_map.json')['units'];newmap=read(p.ROOT/'art/overworld/creature_idle.json')['units']
 assert {k:v for k,v in oldmap.items() if k!=UID}=={k:v for k,v in newmap.items() if k!=UID}
 # Idle pixels/geometry stay exact; lineage must name the newly packed atlas.
 assert {k:v for k,v in oldmap[UID].items() if k!='source_sha256'}=={k:v for k,v in newmap[UID].items() if k!='source_sha256'}
 assert oldmap[UID]['source_sha256']==p.sha(baseline/'baseline_atlas.png')
 assert newmap[UID]['source_sha256']==p.sha(resolve(new['pose_sheet']))
 a=Image.open(baseline/'baseline_map_idle.png').convert('RGBA');b=Image.open(resolve(newmap[UID]['path'])).convert('RGBA');assert a.size==b.size and a.tobytes()==b.tobytes()
 take=p.SOURCE_DIR/'move_h3_v3';record=read(take/'original.json');assert p.sha(take/'original_lossless.mkv')==record['sha256']
 with av.open(str(take/'original_lossless.mkv')) as video: hashes=[hashlib.sha256(f.to_image().convert('RGB').tobytes()).hexdigest() for f in video.decode(video=0)]
 assert hashes==record['decoded_rgb_sha256']
 for guide in read(take/'reference.json')['guides']:
  assert p.sha(take/guide['input_file'])==guide['input_sha256'];assert p.sha(p.ROOT/guide['source_frame']['source'])==guide['source_sha256']
 print('New original RGB frames verified:',len(hashes));print('Published source gait frames:',len(live));print('Preserved published action/dead poses:',preserved);print('All232 map visuals/timing and other231 battle rows preserved; selected map lineage hash matches new battle atlas.')
 print('Atlas:',sheet.size,'RGBA bytes:',sheet.width*sheet.height*4)
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--baseline-dir',type=Path,required=True);args=parser.parse_args();verify(args.baseline_dir)
