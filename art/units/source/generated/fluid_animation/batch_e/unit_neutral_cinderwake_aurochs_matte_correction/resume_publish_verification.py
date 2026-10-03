"""Close the already-published verification after atlas source-hash-only metadata change."""
from pathlib import Path
import hashlib,json,subprocess,sys
from PIL import Image
import publish as p
R=p.R;S=p.S;UID=p.UID
from integrate_fluid_creature_animation import pack_unit,old_pose,source_pose,resolve
from creature_animation_lock import exclusive
with exclusive('content'):
 old=p.read(S/'original_row.json');old_entry=p.read(S/'original_handoff.json')['units'][0]
 head=json.loads(subprocess.check_output(['git','show','HEAD:content/unit_animation_manifest.json']));assert old==next(x for x in head['items'] if x['unit_id']==UID)
 old_map=json.loads(subprocess.check_output(['git','show','HEAD:art/overworld/creature_idle.json']))['units'][UID]
 baseline=p.read(R/'art/animation/source/fluid'/UID/'baseline.json');proof=R/'.artifacts/parallel_animation_20261002/middle53_completion_audit/cinderwake-correction/original-rebuilt';patch=pack_unit(old_entry,baseline,proof);assert patch['atlas_sha256']==old_map['source_sha256'],'Exact pre-correction atlas reconstruction failed'
 old_atlas=Image.open(resolve(patch['animation']['pose_sheet'])).convert('RGBA');row=next(x for x in p.read(R/'content/unit_animation_manifest.json')['items'] if x['unit_id']==UID);atlas=Image.open(resolve(row['pose_sheet'])).convert('RGBA');unchanged=0
 for name,spec in old['pose_clips'].items():
  if name in ['death','dead']:continue
  other=row['pose_clips'][name];assert len(spec['indices'])==len(other['indices'])
  for a,b in zip(spec['indices'],other['indices']):p.same(old_pose(old_atlas,old,a),old_pose(atlas,row,b));unchanged+=1
  for key in ['frame_msec','frame_durations_msec','loop','static_frame','contact_frame']:assert spec.get(key)==other.get(key)
 entry=p.read(R/'art/animation/source/fluid'/UID/'reviewed_handoff.json')['units'][0];verified=0
 for name,spec in entry['clips'].items():
  for a,b in zip(spec['indices'],row['pose_clips'][name]['indices']):p.same(source_pose(entry['frames'][a],0),old_pose(atlas,row,b));verified+=1
 new_map=p.read(R/'art/overworld/creature_idle.json')['units'][UID]
 assert {k:v for k,v in old_map.items() if k!='source_sha256'}=={k:v for k,v in new_map.items() if k!='source_sha256'}
 assert p.sha(resolve(new_map['path']))==old_map['sha256'];assert new_map['source_sha256']==p.sha(resolve(row['pose_sheet']))
 assert row['pose_clips']['dead']['indices']==[row['pose_clips']['death']['indices'][-1]]
 j=p.read(S/'completion.json');assert j['status']=='accepted_candidate_death'
 j.update(status='published_pending_live',publication=dict(unchanged_non_death_poses=unchanged,selected_original_or_derived_poses=verified,preserved_other_rows=231,preserved_idle_map_exact=True,atlas_sha256=p.sha(resolve(row['pose_sheet'])),recovery='First publication passed other231 row/source/pose/map pixel checks, then rejected expected full-atlas source_sha256 update. Read-only exact original atlas reconstruction and all pose/map proofs now close verification without republishing.'))
 (S/'completion.json').write_text(json.dumps(j,indent=2)+'\n');print('PUBLICATION_VERIFICATION_RESUMED',j['publication'],flush=True)
