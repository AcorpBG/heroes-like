"""Record actual selected-unit results after personal runtime acceptance."""
import json,re,subprocess,sys
from PIL import Image
import produce as p
from creature_animation_lock import exclusive

if __name__=='__main__':
 base=p.ROOT/'.artifacts/parallel_animation_20261002'/p.SOURCE_DIR.name
 personal=json.loads((p.SOURCE_DIR/'personal_acceptance.json').read_bytes())
 assert personal['accepted'] and personal['remaining_defects']==[]
 for key in ['all_original_rgb_rgba_chronology','enlarged_original_alpha','all_native_reflected_poses','actual_melee_captures','live_map_phases']:
  assert personal[key] is True,key
 checks={}
 for name in ['candidate','mirrored','live']:
  reports=re.findall(r'FLUID_ANIMATION_REPORT (\{[^\n]+\})',(base/name/'console.log').read_text(encoding='utf-8'))
  assert len(reports)==1,name
  report=json.loads(reports[0]);assert report['failures']==[],report
  checks[name]=report['checks']
 assert 'GAUGECOIL_IMPORTED_ATLAS_OK' in (base/'imported_atlas_console.log').read_text(encoding='utf-8')
 assert 'GAUGECOIL_MAP_PHASES_CAPTURED 8' in (base/'live/console.log').read_text(encoding='utf-8')
 assert all((base/'live'/f'map-phase-{i}.png').exists() for i in range(8))
 for script,args in [('verify_delivery.py',['--baseline-dir',str(base)]),('verify_failed_originals.py',[])]:
  subprocess.run([sys.executable,str(p.SOURCE_DIR/script),*args],cwd=p.ROOT,check=True)
 with exclusive('content'):
  row=next(r for r in json.loads((p.ROOT/'content/unit_animation_manifest.json').read_bytes())['items'] if r['unit_id']==p.SOURCE_DIR.name)
  maprow=json.loads((p.ROOT/'art/overworld/creature_idle.json').read_bytes())['units'][p.SOURCE_DIR.name]
 counts={name:int(row['pose_clips'][name]['frames']) for name in ['idle','move','attack','hit','defend','cast','death']}
 assert counts['idle']==8
 delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());selected=delivery['takes'];failed=delivery['failed_takes']
 records=[json.loads((p.SOURCE_DIR/name/'original.json').read_bytes()) for name in selected+failed]
 assert all(len(r['decoded_rgb_sha256'])==124 for r in records)
 sheet=Image.open(p.ROOT/row['pose_sheet'].removeprefix('res://'));action_poses=sum(counts.values())-8
 selected_rgba=[]
 for name in selected:
  selection=json.loads((p.SOURCE_DIR/name/'selection.json').read_bytes())
  matte=json.loads((p.SOURCE_DIR/name/'matte_v3.json').read_bytes())
  selected_rgba.extend(matte['rgba_sha256'][i] for i in selection['source_frames'])
 assert len(selected_rgba)==len(set(selected_rgba))==action_poses
 completion=dict(unit_id=p.SOURCE_DIR.name,status='complete_selected_unit',date='2026-10-03',clips=counts,
  held_corpse='Dead uses the personally accepted final original death pose with all four original legs folded beneath the grounded cold mineral body and attached gauges/tail.',
  sources=dict(takes=len(records),rgb_frames_per_take=124,retained_original_rgb_frames=124*len(records),selected_take_rgb_frames=124*len(selected),selected_action_pose_pngs=action_poses,preserved_idle_poses=8,
   rejected_takes={name:json.loads((p.SOURCE_DIR/name/'review.json').read_bytes())['review'] for name in failed},all_original_ffv1_and_decoded_rgb_hashes_verified=True,selected_original_rgba_poses_byte_unique=True,failed_originals_and_provenance_retained=True,
   guide_repair='Built-in imagegen created a closed-jaw physical-contact key replacing open-rosette conditioning after two rejected firing takes, an original low broad four-leg grounded brace replacing the rejected floating guard, a distinct connected raised-front-rock-leg support key, and a grounded cold endpoint retaining the red tail valve and three pressure pods/gauges. The first endpoint with a concealed third pod is rejected/preserved. Complete original images and exact prompt/reference hashes retained.'),
  visual_review=personal,
  validation=dict(platform='Windows Godot4.6.2 compatibility renderer on RTX5090',checks=checks,total_focused_assertions=sum(checks.values()),failures=[],all_source_pixel_and_ground_anchor_matches=action_poses,other_battle_and_map_rows_preserved=231,
   idle_battle_and_map_pixels_timing_exact=True,idle_frame_msec=maprow['frame_msec'],atlas_size=list(sheet.size),atlas_rgba_bytes=sheet.width*sheet.height*4,
   atlas_import_rgba_exact='Godot lossless texture equals original PNG after documented fix_alpha_edges transparent-border processing.',original_curated_identity_sha256=row['curated_source_sha256'],
   policies_checked=['Normal/Fast timing','reduced motion','static/dead presentation','authored contact/recovery','interruption/input lock','unchanged serialized simulation/session save'],full_suite_run=False,linux_run=False,
   recovered_git_index_lock_backup_preserved='.git/index-lock-recovery-20261002-93ec4839806c4886abb594d1167e878d.bin'))
 p.write(p.SOURCE_DIR/'completion.json',completion)
 print('GAUGECOIL_COMPLETE',sum(counts.values()),'poses',sum(checks.values()),'focused assertions',flush=True)
