"""Verify original pixels, registration, model guides and unchanged other units."""
import argparse,hashlib,json
from pathlib import Path
import av
from PIL import Image
import produce as p
from integrate_fluid_creature_animation import old_pose,source_pose,clip_indices,resolve
from pack_overworld_creature_idle import extract
UID='unit_neutral_rootcrown_knotstags'
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
  for idx,packed in zip(spec['indices'],live):equal_pose(source_pose(handoff['frames'][idx],0),old_pose(sheet,new,packed));published+=1
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
 hashes_total=0
 for take_name in read(p.SOURCE_DIR/'delivery.json')['takes']:
  take=p.SOURCE_DIR/take_name;record=read(take/'original.json');assert p.sha(take/'original_lossless.mkv')==record['sha256']
  with av.open(str(take/'original_lossless.mkv')) as video:hashes=[hashlib.sha256(f.to_image().convert('RGB').tobytes()).hexdigest() for f in video.decode(video=0)]
  assert hashes==record['decoded_rgb_sha256'];hashes_total+=len(hashes)
  for guide in read(take/'reference.json')['guides']:
   assert p.sha(take/guide['input_file'])==guide['input_sha256'];assert p.sha(p.ROOT/guide['source_frame']['source'])==guide['source_sha256']
 print('Original RGB frames:',hashes_total,'published action poses:',published)
 print('Other231 battle/map rows preserved; new map idle equals selected original idle pixels/timing.')
 print('Atlas:',sheet.size,'RGBA bytes:',sheet.width*sheet.height*4)
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--baseline-dir',type=Path,required=True);args=parser.parse_args();verify(args.baseline_dir)
