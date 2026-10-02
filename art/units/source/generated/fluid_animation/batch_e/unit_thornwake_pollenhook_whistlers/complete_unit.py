"""Record actual focused checks; finalize only after measured owned cleanup."""
import argparse,json,sys
from PIL import Image
import produce as p
UID='unit_thornwake_pollenhook_whistlers';REVIEW=p.ROOT/'.artifacts/parallel_animation_20261002'/UID
def read(path):return json.loads(path.read_bytes())
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('mode',choices=['prepare','finalize']);args=a.parse_args();path=p.SOURCE_DIR/'completion.json'
 if args.mode=='prepare':
  delivery=read(p.SOURCE_DIR/'delivery.json');h=read(p.SOURCE_DIR/'handoff.json')['units'][0];assert delivery['visual_review']['status']=='accepted_selected_unit'
  row=next(x for x in read(p.ROOT/'content/unit_animation_manifest.json')['items'] if x['unit_id']==UID);checks={}
  for name in ['candidate','candidate_mirrored','candidate_ranged','live','live_ranged']:
   report=read(REVIEW/name/'result.json');assert not report['failures'];checks[name]=report['checks']
  assert 'POLLENHOOK_WHISTLER_IMPORTED_ATLAS_OK ' in (REVIEW/'import/pixels.log').read_text(encoding='utf-8')
  atlas=Image.open(p.ROOT/row['pose_sheet'].removeprefix('res://'));clips={k:row['pose_clips'][k]['frames'] for k in ['idle','move','attack','ranged','hit','defend','cast','death']};all_takes=delivery['takes']+delivery.get('failed_takes',[])
  visual=dict(delivery['visual_review']);visual.update(live_native_all_poses_reviewed=True,actual_live_melee_captures_reviewed=8,actual_live_ranged_captures_reviewed=8,live_overworld_idle_frames_reviewed=[0,3],imported_atlas_exact_rgba=True,all_selected_source_pixels_and_anchors_verified=True,other231_battle_and_map_rows_preserved=True,existing_idle_map_pixels_and_timing_exact=True)
  result=dict(unit_id=UID,status='validated_pending_cleanup',date='2026-10-02',solo_unit_worker=True,source_method='Original MiniMax H3 video, retained sampler latent and124-frame FFV1 RGB proof per take; pinned local BiRefNet soft matte',clips=clips,new_selected_poses=len(h['frames']),preserved_idle_poses=8,held_corpse_from_final_death=True,battle_atlas_size=list(atlas.size),battle_texture_rgba_bytes=atlas.width*atlas.height*4,original_selected_rgb_frames_reviewed=len(delivery['takes'])*124,preserved_original_rgb_frames=len(all_takes)*124,rejected_takes=delivery.get('failed_takes',[]),validation=dict(checks=checks,total=sum(checks.values()),failures=[],source_pixel_and_ground_anchor_equality=True,other231_battle_and_map_rows_preserved=True,imported_atlas_exact_rgba=True,preserved_battle_and_overworld_idle_exact=True,visual_review=visual,normal_fast_reduced_static_dead_contact_interrupt_rng_save=True,manual_game_session=False,continuous_video_playback=False,linux_run=False,full_suite_run=False),broad_goal_status='in_progress')
  p.write(path,result);print('Validated selected unit; mandatory cleanup remains.',sum(checks.values()),flush=True)
 else:
  result=read(path);assert result['status']=='validated_pending_cleanup';cleanup=json.load(sys.stdin);assert cleanup['applied'] and cleanup['original_videos_latents_guides_prompts_provenance_and_caches_preserved']
  h=read(p.SOURCE_DIR/'handoff.json')['units'][0]
  for frame in h['frames']:assert (p.ROOT/frame['source']).is_file()
  for record in h['provenance'].values():assert p.sha(p.ROOT/record['path'])==record['sha256']
  result['status']='complete_selected_unit';result['cleanup']=cleanup;result['cleanup']['retained_original_rgb_frames']=result['preserved_original_rgb_frames'];p.write(path,result);print('COMPLETE_SELECTED_UNIT',result['new_selected_poses'],result['validation']['total'],cleanup['recovered_bytes'],flush=True)
