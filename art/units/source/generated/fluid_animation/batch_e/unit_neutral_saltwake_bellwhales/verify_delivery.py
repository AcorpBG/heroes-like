"""Verify original pixels, registration, model guides and unchanged other units."""
import argparse,hashlib,json
from pathlib import Path
import av
from PIL import Image
import produce as p
from integrate_fluid_creature_animation import old_pose,source_pose,clip_indices,resolve
from pack_overworld_creature_idle import extract
UID='unit_neutral_saltwake_bellwhales'
def read(path):return json.loads(Path(path).read_bytes())
def equal_pose(a,b):
 assert a[1]==b[1],(a[1],b[1]);assert a[0].size==b[0].size;assert a[0].tobytes()==b[0].tobytes()
def verify(baseline):
 oldrows=read(baseline/'baseline_manifest.json')['items'];rows=read(p.ROOT/'content/unit_animation_manifest.json')['items']
 publication=read(p.SOURCE_DIR/'publication.json');assert publication['other_rows_preserved']
 assert publication['before_other_battle_sha256']==publication['after_other_battle_sha256']
 assert publication['before_other_map_sha256']==publication['after_other_map_sha256']
 digest=lambda obj:hashlib.sha256(json.dumps(obj,sort_keys=True,separators=(',',':')).encode()).hexdigest()
 new=next(r for r in rows if r['unit_id']==UID);assert digest(new)==publication['published_own_battle_sha256'];sheet=Image.open(resolve(new['pose_sheet'])).convert('RGBA');assert max(sheet.size)<=4096
 handoff=read(p.SOURCE_DIR/'handoff.json')['units'][0];published=0
 for name,spec in handoff['clips'].items():
  live=clip_indices(new['pose_clips'][name],new['pose_columns']);assert len(live)==len(spec['indices'])
  for idx,packed in zip(spec['indices'],live):
   frame=handoff['frames'][idx];original=Image.open(p.ROOT/frame['source']).convert('RGBA')
   bounds=original.getchannel('A').point(lambda a:255 if a>=128 else 0).getbbox()
   assert bounds and bounds[0]>0 and bounds[1]>0 and bounds[2]<original.width and bounds[3]<original.height,('Clipped original fin/fluke/bell',frame['source'],bounds)
   equal_pose(source_pose(frame,0),old_pose(sheet,new,packed));published+=1
 for rec in handoff['provenance'].values():assert p.sha(p.ROOT/rec['path'])==rec['sha256'],rec['path']
 assert new['pose_clips']['dead']['indices']==[new['pose_clips']['death']['indices'][-1]]
 assert set(new['pose_accepted_clips'])=={'idle','move','attack','ranged','hit','defend','cast','death'}
 assert not ({'move','attack','ranged','hit','defend','cast','death'} & set(new.get('pose_aliases',{})))
 oldmap=read(baseline/'baseline_map.json')['units'];newmap=read(p.ROOT/'art/overworld/creature_idle.json')['units']
 assert digest(newmap[UID])==publication['published_own_map_sha256']
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
 initial=read(p.SOURCE_DIR/'original_baseline.json')
 assert old==initial['row'],'Original accepted row changed before publication'
 assert p.sha(baseline/'baseline_atlas.png')==initial['original_pose_atlas_sha256']
 assert p.sha(baseline/'baseline_map_idle.png')==initial['map_png_sha256']
 assert p.sha(resolve(initial['row']['curated_source']))==initial['curated_sha256']
 assert oldmap[UID]==initial['map_row']
 w,h=[old['pose_frame_size'][key] for key in ['width','height']];columns=old['pose_columns']
 fingerprints=[hashlib.sha256(baseline_sheet.crop((i%columns*w,i//columns*h,(i%columns+1)*w,(i//columns+1)*h)).tobytes()).hexdigest() for i in clip_indices(old['pose_clips']['idle'],columns)]
 assert fingerprints==initial['idle_rgba_sha256']
 for before,after in zip(clip_indices(old['pose_clips']['idle'],old['pose_columns']),clip_indices(new['pose_clips']['idle'],new['pose_columns'])):
  equal_pose(old_pose(baseline_sheet,old,before),old_pose(sheet,new,after))
 assert len(clip_indices(new['pose_clips']['idle'],new['pose_columns']))==8
 hashes_total=0
 for take_name in sorted(d.name for d in p.SOURCE_DIR.glob('*_h3_v*') if (d/'original.json').exists()):
  take=p.SOURCE_DIR/take_name;record=read(take/'original.json');assert p.sha(take/'original_lossless.mkv')==record['sha256']
  staged=read(take/'staged_generation.json');assert p.sha(take/'original.latent')==staged['latent_sha256']
  assert p.sha(take/'sampling_workflow_api.json')==staged['sampling_workflow_sha256']
  assert p.sha(take/'workflow_api.json')==staged['decode_workflow_sha256']
  with av.open(str(take/'original_lossless.mkv')) as video:hashes=[hashlib.sha256(f.to_image().convert('RGB').tobytes()).hexdigest() for f in video.decode(video=0)]
  assert hashes==record['decoded_rgb_sha256'];hashes_total+=len(hashes)
  for guide in read(take/'reference.json')['guides']:
   assert p.sha(take/guide['input_file'])==guide['input_sha256'];assert p.sha(p.ROOT/guide['source_frame']['source'])==guide['source_sha256']
 print('Original RGB frames:',hashes_total,'published action poses:',published)
 print('Other',publication['other_row_count'],'battle/map rows preserved at mutex-held publication; original8 battle/map idle pixels and200ms timing preserved exactly.')
 print('Atlas:',sheet.size,'RGBA bytes:',sheet.width*sheet.height*4)
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--baseline-dir',type=Path,required=True);args=parser.parse_args();verify(args.baseline_dir)
