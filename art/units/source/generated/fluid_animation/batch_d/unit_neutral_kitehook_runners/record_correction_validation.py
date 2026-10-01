"""Record the finite correction's actual acceptance and published live proof."""
import json
import re
import produce as p


if __name__ == '__main__':
    work = p.ROOT / '.artifacts/kitehook_h3'
    reports = {}
    for name in ['correction_candidate', 'correction_live']:
        console = (work / name / 'console.log').read_text(encoding='utf-8')
        matches = re.findall(r'FLUID_ANIMATION_REPORT (\{[^\n]+\})', console)
        assert len(matches) == 1, name
        reports[name] = json.loads(matches[0])
        assert reports[name]['failures'] == [], name
    path = p.SOURCE_DIR / 'correction_delivery.json'
    delivery = json.loads(path.read_bytes())
    review = {
        'status': 'accepted_selected_clips',
        'accepted_clips': ['attack', 'defend', 'cast', 'death', 'hit'],
        'notes': 'Coordinator accepted new hit19 after all124 original/final matte chronological frames, enlarged anatomy, all19 native hit phases and mirrored native capture. Existing attack22/defend12/physical support19/death26 remain unchanged and accepted; original articulated idle8 preserved. Movement v1/v2 excluded because reciprocal near/far knee and boot loading/passing remains unproven. Continuous source/retimed playback remains unavailable. No further generation authorized this run.'}
    delivery['visual_review'] = review
    delivery['validation'] = {
        'candidate_report': reports['correction_candidate'],
        'live_report': reports['correction_live'],
        'candidate_exit_code': 0, 'live_exit_code': 0,
        'isolated_profile_import_exit_code': 0,
        'fixture': 'tests/fluid_creature_animation_regression.py --live --unit unit_neutral_kitehook_runners --overview-only --render',
        'contacts_only': False,
        'original_rgb_frames_verified': 992,
        'published_source_frames_verified': 98,
        'preserved_idle_frames': 8,
        'other_catalog_rows_unchanged': 231,
        'published_atlas_size': [2960, 2860], 'rgba_bytes': 33862400,
        'coverage': 'Unmodified shared full fixture: Normal/Fast/reduced, authored attack contacts and recovery, audio/VFX, session/save equality, actual BattleShell input/finish/focus and committed-save equality, live import dimensions, actual map shader frame changes and reduced-motion stability.',
        'visual_review': 'All106 live native phases, three actual BattleShell captures and map idle phases inspected. Mirrored candidate image is a review derivative of the actual native phase capture.'}
    p.write(path, delivery)
    handoff_path = p.SOURCE_DIR / 'handoff_corrections.json'
    handoff = json.loads(handoff_path.read_bytes())
    handoff['units'][0]['visual_review'] = review
    p.write(handoff_path, handoff)
    print('Recorded accepted selected five clips and actual candidate/live reports; old four-action proof unchanged.')
