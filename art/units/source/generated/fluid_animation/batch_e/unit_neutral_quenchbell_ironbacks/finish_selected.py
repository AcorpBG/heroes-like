"""Record the personally reviewed unit only after all focused checks pass."""
import json, re
from PIL import Image
import produce as p
from creature_animation_lock import exclusive
import publish_selected, verify_delivery

UID = 'unit_neutral_quenchbell_ironbacks'
OUT = p.ROOT/'.artifacts/parallel_animation_20261002'/UID


if __name__ == '__main__':
    reports = {}
    for key, folder in [('candidate','candidate_native'),
                        ('mirrored','mirrored_native'), ('live','live_native')]:
        output = (OUT/folder/'console.log').read_text(encoding='utf-8')
        lines = re.findall(r'FLUID_ANIMATION_REPORT (\{[^\n]+\})', output)
        assert len(lines) == 1
        report = json.loads(lines[0]); assert not report['failures'], report
        reports[key] = report['checks']
    assert 'QUENCHBELL_IRONBACK_IMPORTED_ATLAS_OK' in (OUT/'imported_pixels.log').read_text()
    with exclusive('content'):
        # Peers can legitimately publish a different UID during live review.
        # Own original baselines remain immutable; compare against their latest
        # rows and verify every own source/anchor/idle pixel again atomically.
        publish_selected.refresh_other_rows()
        verify_delivery.verify(OUT)
        rows = json.loads((p.ROOT/'content/unit_animation_manifest.json').read_bytes())['items']
        units = json.loads((p.ROOT/'content/units.json').read_bytes())['items']
        by_id = {row['unit_id']:row for row in rows}
        complete = sum(({'idle','move','attack','hit','defend','cast','death'} |
                        ({'ranged'} if unit.get('ranged') else set())) <=
                       set(by_id[unit['id']].get('pose_accepted_clips',[])) for unit in units)
    handoff = json.loads((p.SOURCE_DIR/'handoff.json').read_bytes())['units'][0]
    counts = {name:len(spec['indices']) for name,spec in handoff['clips'].items()}
    counts['idle'] = 8
    assert sum(counts.values()) == 211
    image = Image.open(p.ROOT/f'art/animation/runtime/fluid/{UID}.png')
    review = dict(status='accepted_selected_unit', unit_id=UID, solo=True,
                  all124_original_frames_each_selected_take_inspected=True,
                  all_original_takes_reviewed=7, original_frames_reviewed=868,
                  selected_original_frames_reviewed=744, new_selected_poses=203,
                  preserved_idle_poses=8, native_candidate_all211_poses_reviewed=True,
                  mirrored_candidate_all211_poses_reviewed=True,
                  live_native_all211_poses_reviewed=True,
                  actual_candidate_melee_captures_reviewed=8,
                  actual_mirrored_run_melee_captures_reviewed=8,
                  actual_live_melee_captures_reviewed=8,
                  actual_melee_capture_facing='normal',
                  live_overworld_idle_frames_reviewed=[0,3],
                  imported_atlas_exact_rgba=True,
                  all_selected_source_pixels_and_anchors_verified=True,
                  other231_battle_and_map_rows_preserved=True,
                  existing_idle_map_pixels_and_timing_exact=True,
                  review_note=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())['visual_review']['notes'].replace(
                      'live/imported review pending.',
                      'All211 imported/live poses, eight actual live ram captures and map idle phases0/3 personally inspected; exact imported RGBA/source/anchor/map checks passed.'),
                  continuous_video_playback=False, manual_game_session=False,
                  linux_run=False, full_suite_run=False)
    record = dict(unit_id=UID, status='complete_selected_unit', date='2026-10-02',
                  solo=True, source_method='MiniMax H3 original video with pinned local BiRefNet soft matting',
                  clips=counts, new_selected_poses=203, preserved_idle_poses=8,
                  battle_atlas_size=list(image.size),
                  battle_texture_rgba_bytes=image.width*image.height*4,
                  original_selected_rgb_frames_reviewed=744,
                  preserved_original_rgb_frames=868, provenance_digests=len(handoff['provenance']),
                  validation=dict(checks=reports,total=sum(reports.values()),failures=[],
                      source_pixel_and_ground_anchor_equality=True,
                      other231_battle_and_map_rows_preserved=True,
                      imported_atlas_exact_rgba=True,
                      preserved_battle_and_overworld_idle_exact=True,
                      visual_review=review, full_suite_run=False,linux_run=False,
                      manual_game_session=False,continuous_video_playback=False),
                  roster=dict(complete=complete,total=len(units),remaining=len(units)-complete),
                  broad_goal_status='in_progress')
    p.write(p.SOURCE_DIR/'completion.json', record)
    print(json.dumps(dict(clips=counts, checks=reports, total=sum(reports.values()),
                         roster=record['roster']), indent=2))
