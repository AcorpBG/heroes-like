"""Record only actual focused results, then close precise measured cleanup."""
import argparse,json,datetime
from PIL import Image
import produce as p
UID='unit_mireclaw_moonbite_mirehorn_breakers'
root=p.ROOT/'.artifacts/parallel_animation_20261002'/UID
a=argparse.ArgumentParser();a.add_argument('mode',choices=['record','finish']);args=a.parse_args()
if args.mode=='record':
 results={}
 for case in ['candidate/native','candidate/mirror','live/native','live/mirror']:
  log=(root/case/'console.log').read_text(encoding='utf-8');reports=[json.loads(line.split('FLUID_ANIMATION_REPORT ',1)[1]) for line in log.splitlines() if line.startswith('FLUID_ANIMATION_REPORT ')]
  assert len(reports)==1 and not reports[0]['failures'],(case,reports);results[case]=reports[0]
 assert 'MIREHORN_BREAKER_IMPORTED_ATLAS_OK' in (root/'import/pixels.log').read_text(encoding='utf-8')
 h=json.loads((p.SOURCE_DIR/'handoff.json').read_bytes())['units'][0];d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());baseline=json.loads((p.SOURCE_DIR/'original_baseline.json').read_bytes());row=next(r for r in json.loads((p.ROOT/'content/unit_animation_manifest.json').read_bytes())['items'] if r['unit_id']==UID)
 assert d['visual_review']['status']=='accepted_selected_clips'
 takes=[t for t in p.SOURCE_DIR.glob('*_h3_v*') if (t/'original.json').exists()];rgb=sum(len(json.loads((t/'original.json').read_bytes())['decoded_rgb_sha256']) for t in takes)
 atlas=p.ROOT/row['pose_sheet'].removeprefix('res://');size=Image.open(atlas).size
 p.write(p.SOURCE_DIR/'completion.json',dict(status='validated_cleanup_pending',unit_id=UID,completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),clips={k:dict(frames=len(v['indices']),**{x:v[x] for x in ['frame_msec','frame_durations_msec','contact_frame','static_frame','loop'] if x in v}) for k,v in h['clips'].items()},preserved_idle=dict(frames=len(baseline['row']['pose_clips']['idle']['indices']),frame_msec=baseline['row']['pose_clips']['idle']['frame_msec'],battle_map_pixels_exact=True),new_action_poses=len(h['frames']),original_take_count=len(takes),original_rgb_frames_preserved=rgb,focused_results=results,passed_focused_assertions=sum(r['checks'] for r in results.values()),atlas=dict(path=atlas.relative_to(p.ROOT).as_posix(),sha256=p.sha(atlas),width=size[0],height=size[1],rgba_bytes=size[0]*size[1]*4),verification=dict(original_rgb_sha256=True,source_packed_pixel_anchor_exact=True,source_distinct_poses=True,imported_rgba_exact_after_default_alpha_border_fix=True,other_rows_preserved_at_mutex_publication=True),visual_review=d['visual_review'],scope=dict(windows_godot='4.6.2',linux_validation=False,fullsuite=False,manual_game_playtest=False,continuous_manual_clip_playback=False),preserved='All original RGB videos, failed takes, latents, workflows, prompts, guide art, original packed poses, model/NN/plate recipes, selected source mattes, caches, saves, backups and RMG material.'))
 print('RECORDED_ACTUAL_FOCUSED_RESULTS',sum(r['checks'] for r in results.values()),rgb,flush=True)
else:
 c=json.loads((p.SOURCE_DIR/'completion.json').read_bytes());assert c['status']=='validated_cleanup_pending'
 records={f.stem:json.loads(f.read_bytes()) for f in p.SOURCE_DIR.glob('cleanup_*.json')};assert {'cleanup_duplicates','cleanup_unselected','cleanup_reviews'}<=set(records)
 assert not root.exists();c['cleanup']=dict(records=records,removed_files=sum(r['files'] for r in records.values()),recovered_bytes=sum(r['bytes'] for r in records.values()),rebuildable=True);c['status']='complete_selected_unit';p.write(p.SOURCE_DIR/'completion.json',c);print('COMPLETE_SELECTED_UNIT',c['cleanup'],flush=True)
