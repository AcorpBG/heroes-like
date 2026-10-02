"""Complete this unit only after personally reviewed and focused live proofs."""
import json,re
from PIL import Image
import produce as p
from creature_animation_lock import exclusive
import publish_selected,verify_delivery
UID='unit_neutral_noonshard_prism_kites'
OUT=p.ROOT/'.artifacts/parallel_animation_20261002'/UID

if __name__=='__main__':
    delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
    review=delivery['visual_review']
    assert review['status']=='accepted_selected_clips'
    assert review['all_original_takes_personally_reviewed']
    reports={}
    for key,folder in [('candidate','candidate_native'),('mirrored','mirrored_native'),('ranged','ranged_native'),('live','live_native'),('live_ranged','live_ranged')]:
        lines=re.findall(r'FLUID_ANIMATION_REPORT (\{[^\n]+\})',(OUT/folder/'console.log').read_text(encoding='utf-8'))
        assert len(lines)==1
        report=json.loads(lines[0]);assert not report['failures'],report
        reports[key]=report['checks']
    assert 'NOONSHARD_PRISM_KITE_IMPORTED_ATLAS_OK' in (OUT/'imported_pixels.log').read_text()
    with exclusive('content'):
        publish_selected.refresh_other_rows();verify_delivery.verify(OUT)
        rows=json.loads((p.ROOT/'content/unit_animation_manifest.json').read_bytes())['items']
        units=json.loads((p.ROOT/'content/units.json').read_bytes())['items']
        by_id={row['unit_id']:row for row in rows}
        complete=sum(({'idle','move','attack','hit','defend','cast','death'}|({'ranged'} if unit.get('ranged') else set()))<=set(by_id[unit['id']].get('pose_accepted_clips',[])) for unit in units)
    handoff=json.loads((p.SOURCE_DIR/'handoff.json').read_bytes())['units'][0]
    counts={name:len(spec['indices']) for name,spec in handoff['clips'].items()}
    assert set(counts)=={'move','attack','ranged','hit','defend','cast','death'}
    minima={'move':8,'attack':8,'ranged':8,'hit':4,'defend':4,'cast':8,'death':8}
    assert all(counts[name]>=minimum for name,minimum in minima.items()),counts
    takes=list(dict.fromkeys(delivery['takes']+delivery.get('rejected_takes',[])))
    original_frames=sum(json.loads((p.SOURCE_DIR/take/'original.json').read_bytes())['frames'] for take in takes)
    image=Image.open(p.ROOT/f'art/animation/runtime/fluid/{UID}.png')
    counts['idle']=8
    record=dict(unit_id=UID,status='complete_selected_unit',solo=True,date='2026-10-03',source_method='Original MiniMax H3 video and pinned BiRefNet soft matte; no synthetic sprite motion or interpolation',clips=counts,new_selected_poses=sum(counts.values())-8,preserved_idle_poses=8,battle_atlas_size=list(image.size),battle_texture_rgba_bytes=image.width*image.height*4,preserved_original_rgb_frames=original_frames,provenance_digests=len(handoff['provenance']),validation=dict(checks=reports,total=sum(reports.values()),failures=[],source_pixel_and_ground_anchor_equality=True,other231_battle_and_map_rows_preserved=True,imported_atlas_exact_rgba=True,preserved_battle_and_overworld_idle_exact=True,visual_review=review,all_selected_normal_reflected_and_live_poses_personally_reviewed=True,actual_melee_and_ranged_captures_personally_reviewed=True,full_suite_run=False,linux_run=False,manual_game_session=False,continuous_video_playback=False),roster=dict(complete=complete,total=len(units),remaining=len(units)-complete),broad_goal_status='in_progress')
    p.write(p.SOURCE_DIR/'completion.json',record)
    print(json.dumps(dict(clips=counts,checks=reports,total=sum(reports.values()),roster=record['roster']),indent=2))
