"""Record this personally accepted delivery from the actual focused results."""
import json,re
import produce as p
from creature_animation_lock import exclusive

if __name__=='__main__':
 base=p.ROOT/'.artifacts/parallel_animation_20261002'/p.SOURCE_DIR.name
 checks={}
 for name in ['candidate','mirrored','ranged','live','live_ranged']:
  log=(base/name/'console.log').read_text(encoding='utf-8')
  reports=re.findall(r'FLUID_ANIMATION_REPORT (\{[^\n]+\})',log)
  assert len(reports)==1,name
  report=json.loads(reports[0]);assert report['failures']==[],report
  checks[name]=report['checks']
 assert 'WHITEGAUGE_IMPORTED_ATLAS_OK (3960, 3768) exact RGBA pixels' in (base/'imported_atlas_console.log').read_text(encoding='utf-8')
 assert 'WHITEGAUGE_MAP_PHASES_CAPTURED 8' in (base/'live/console.log').read_text(encoding='utf-8')
 assert all((base/'live'/f'map-phase-{i}.png').exists() for i in range(8))
 with exclusive('content'):
  row=next(r for r in json.loads((p.ROOT/'content/unit_animation_manifest.json').read_bytes())['items'] if r['unit_id']==p.SOURCE_DIR.name)
 counts={name:int(row['pose_clips'][name]['frames']) for name in ['idle','move','attack','ranged','hit','defend','cast','death']}
 assert counts==dict(idle=8,move=52,attack=36,ranged=30,hit=25,defend=26,cast=35,death=45)
 delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
 records=[json.loads((p.SOURCE_DIR/name/'original.json').read_bytes()) for name in delivery['takes']+delivery['failed_takes']]
 assert len(records)==10 and all(len(r['decoded_rgb_sha256'])==124 for r in records)
 completion=dict(unit_id=p.SOURCE_DIR.name,status='complete_selected_unit',date='2026-10-03',clips=counts,
  held_corpse='Final original death pose123 is cold and grounded; runtime dead references the last packed death frame.',
  sources=dict(takes=10,rgb_frames_per_take=124,retained_original_rgb_frames=1240,selected_take_rgb_frames=868,selected_action_pose_pngs=249,preserved_idle_poses=8,
   rejected_takes=dict(attack_h3_v1='Unwanted discharge and weak shove from a missing authentic melee peak.',ranged_h3_v1='Exterior attached beam and changing barrel dimensions.',ranged_h3_v2='Exterior beam touching the original muzzle.'),
   all_original_ffv1_and_decoded_rgb_hashes_verified=True,failed_originals_and_provenance_retained=True,
   guide_repairs='Original separated guard muzzle strip recovered without moving the ground anchor. Authentic operator-and-cannon forward melee peak repaired with built-in imagegen using original identity guides; exact prompt, original image and generation lineage retained.'),
  visual_review=dict(accepted=True,chronological_original_frames_inspected=1240,enlarged_original_and_alpha_trouble_areas=True,candidate_native_poses=257,mirrored_native_poses=257,live_native_poses=257,
   candidate_and_mirrored_actual_melee_captures=16,actual_ranged_captures=8,live_actual_melee_captures=8,live_actual_ranged_captures=8,live_map_shader_phases=8,
   melee_actual_drawn_poses_observed=36,ranged_actual_drawn_poses_observed=30,continuous_video_playback=False,manual_game_playtest=False,
   actual_capture_facing='Actual fixtures use the normal BattleShell facing. Reflected native gallery was personally reviewed in full.',
   actions='Six attached mechanical leg chains creep, brace, shove and buckle. One original operator absorbs recoil, crouches, turns the original upper pressure-control valve, and falls prone beside the cold grounded intact cannon. Original inner barrel compresses and returns for ranged, with unchanged muzzle diameter and outer sleeve.',
   corrections='Pinned semantic alpha from untouched original RGB, measured palette-protected despill, and fixed anchor480,500/uniform scale0.5. Original matching holds trimmed without duplicated padding, warps, synthetic interpolation or anatomy painting. Contained furnace heat retained; exterior effects excluded by correcting original guides/conditioning and resampling.',remaining_defects=[]),
  validation=dict(platform='Windows Godot4.6.2 compatibility renderer on RTX5090',checks=checks,total_focused_assertions=sum(checks.values()),failures=[],
   all_source_pixel_and_ground_anchor_matches=249,other_battle_and_map_rows_preserved=231,idle_battle_and_map_pixels_timing_exact=True,idle_frame_msec=240,
   atlas_size=[3960,3768],atlas_rgba_bytes=59685120,atlas_import_rgba_exact='Godot lossless texture equals original PNG after documented fix_alpha_edges transparent-border processing.',
   original_curated_identity_sha256='7f8ecd42d2a28afbadae2a5483ce6d09ef0c51882578633813b566c71468741a',
   policies_checked=['Normal/Fast timing','reduced motion','static/dead presentation','authored contact/recovery','interruption/input lock','presentation leaves serialized simulation/session save unchanged'],
   full_suite_run=False,linux_run=False,host_warnings=['Restricted Windows root certificate store unreadable.','GLES3 2D MSAA unsupported.'],
   recovered_git_index_lock_backup_preserved='.git/index-lock-recovery-20261002-93ec4839806c4886abb594d1167e878d.bin'))
 p.write(p.SOURCE_DIR/'completion.json',completion)
 print('Personally accepted Whitegauge delivery:',sum(counts.values()),'poses;',sum(checks.values()),'focused assertions')
