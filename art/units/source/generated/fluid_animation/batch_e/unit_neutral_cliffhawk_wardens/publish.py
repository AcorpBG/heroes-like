"""Publish personally accepted death-only extraction against current live rows."""
from pathlib import Path
import copy,hashlib,json,sys
import numpy as np
from PIL import Image
R=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists());S=Path(__file__).parent;UID='unit_neutral_cliffhawk_wardens'
sys.path.insert(0,str(R/'tools'))
from creature_animation_lock import exclusive
from integrate_fluid_creature_animation import old_pose,source_pose,resolve
from publish_fluid_creature_animation import publish
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_bytes())
def same(a,b):assert a[1]==b[1] and a[0].size==b[0].size and a[0].tobytes()==b[0].tobytes()
if __name__=='__main__':
 acceptance=read(S/'completion.json');assert acceptance['status']=='accepted_candidate_death' and not acceptance['failures']
 with exclusive('content'):
  before=read(R/'content/unit_animation_manifest.json');maps=read(R/'art/overworld/creature_idle.json');old=next(r for r in before['items'] if r['unit_id']==UID);atlas=Image.open(resolve(old['pose_sheet'])).convert('RGBA');map_image=Image.open(resolve(maps['units'][UID]['path'])).convert('RGBA')
  assert old==read(S/'original_row.json'),'Selected current row changed during correction'
  record=read(S/'composite_recipe.json')
  for f in record['records']:
   assert sha(R/f['body'])==f['body_sha256'];assert sha(R/f['companion'])==f['companion_sha256'];assert sha(R/f['composite'])==f['composite_sha256']
  result=publish(S/'handoff.json',['death'],acceptance['personal_review'],preserved=['idle'])
  after=read(R/'content/unit_animation_manifest.json');newmaps=read(R/'art/overworld/creature_idle.json');new=next(r for r in after['items'] if r['unit_id']==UID);newatlas=Image.open(resolve(new['pose_sheet'])).convert('RGBA')
  assert [r for r in before['items'] if r['unit_id']!=UID]==[r for r in after['items'] if r['unit_id']!=UID]
  assert {k:v for k,v in maps['units'].items() if k!=UID}=={k:v for k,v in newmaps['units'].items() if k!=UID}
  unchanged=0
  for name,spec in old['pose_clips'].items():
   if name in ['death','dead']:continue
   other=new['pose_clips'][name];assert len(spec['indices'])==len(other['indices'])
   for a,b in zip(spec['indices'],other['indices']):same(old_pose(atlas,old,a),old_pose(newatlas,new,b));unchanged+=1
   for key in ['frame_msec','frame_durations_msec','loop','static_frame','contact_frame']:assert spec.get(key)==other.get(key),(name,key)
  handoff=read(R/'art/animation/source/fluid'/UID/'reviewed_handoff.json')['units'][0];verified=0
  for name,spec in handoff['clips'].items():
   for fi,pi in zip(spec['indices'],new['pose_clips'][name]['indices']):same(source_pose(handoff['frames'][fi],0),old_pose(newatlas,new,pi));verified+=1
  assert new['pose_clips']['dead']['indices']==[new['pose_clips']['death']['indices'][-1]]
  newmap=Image.open(resolve(newmaps['units'][UID]['path'])).convert('RGBA');assert map_image.size==newmap.size and map_image.tobytes()==newmap.tobytes()
  assert {k:v for k,v in maps['units'][UID].items() if k!='source_sha256'}=={k:v for k,v in newmaps['units'][UID].items() if k!='source_sha256'}
  assert newmaps['units'][UID]['source_sha256']==sha(resolve(new['pose_sheet']))
  acceptance.update(status='published_pending_live',publication=dict(unchanged_non_death_poses=unchanged,selected_original_or_derived_poses=verified,preserved_other_rows=231,preserved_idle_map_exact=True,atlas_sha256=sha(resolve(new['pose_sheet']))))
  (S/'completion.json').write_text(json.dumps(acceptance,indent=2)+'\n');print('CLIFFHAWK_DEATH_ONLY_PUBLISHED',result,acceptance['publication'],flush=True)
