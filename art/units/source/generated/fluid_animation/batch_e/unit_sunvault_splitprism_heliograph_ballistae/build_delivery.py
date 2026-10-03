"""Pack reviewed Heliograph originals without altering its existing idle."""
import json
from PIL import Image
import produce as p

REQUIRED = {'move', 'attack', 'ranged', 'hit', 'defend', 'cast', 'death'}


def read(path):
    return json.loads(path.read_bytes())


def build(take, baseline):
    folder = p.SOURCE_DIR/take
    c = read(folder/'config.json')
    selected = read(folder/'selection.json')
    review = read(folder/'visual_review.json')
    assert review['status'] == 'qualified_source_pending_runtime', 'Personal source review required'
    name = c['action']
    assert name in REQUIRED and c['unit_id'] == baseline['unit_id']
    indices = selected['source_frames']
    assert indices == sorted(set(indices))
    assert all(isinstance(i, int) and 0 <= i < 124 for i in indices)
    assert len(indices) >= (4 if name in {'hit', 'defend'} else 8)
    assert 30 <= selected['frame_msec'] <= 1000
    # Register to anatomy, never a pose's variable bounding-box height.
    assert c['scale'] == .45 and c['anchor'] == [480, 576]
    matte = read(folder/'matte.json')
    frames = []
    for index in indices:
        file = folder/'matte'/f'rgba_{index:03}.png'
        assert p.sha(file) == matte['rgba_sha256'][index]
        with Image.open(file) as im:
            assert im.mode == 'RGBA' and list(im.size) == c['canvas']
            bounds = im.getchannel('A').getbbox()
            assert bounds and bounds[0] > 0 and bounds[1] > 0 and bounds[2] < im.width and bounds[3] < im.height, (take, index, bounds)
        frames.append(dict(name=f'{name}_original_h3_{index:03}', clip=name,
                           source=file.relative_to(p.ROOT).as_posix(),
                           rects=[[0, 0, *c['canvas']]], anchor=c['anchor'],
                           scale=c['scale'], alpha_noise_cutoff=0,
                           video_frame=index, video_time_seconds=index/24))
    clip = dict(indices=list(range(len(frames))), frame_msec=selected['frame_msec'],
                loop=name == 'move',
                static_frame=len(frames)-1 if name in {'death', 'defend'} else 0)
    for key in ['contact_frame', 'frame_durations_msec']:
        if key in selected:
            clip[key] = selected[key]
    if name in {'attack', 'ranged'}:
        assert 0 < clip['contact_frame'] < len(frames)-1, 'Contact/release must leave anticipation and recovery'
    if 'frame_durations_msec' in clip:
        assert len(clip['frame_durations_msec']) == len(frames)
        assert all(30 <= msec <= 1000 for msec in clip['frame_durations_msec'])
    provenance = {}
    for name in ['config.json', 'selection.json', 'selection_full24fps.json', 'visual_review.json',
                 'original_lossless.mkv', 'original.mp4', 'original.json',
                 'original.latent', 'reference.json', 'prompt.txt', 'matte.json',
                 'segmentation_recipe.json', 'workflow_api.json',
                 'sampling_workflow_api.json', 'sampling_submission.json',
                 'sampling_history.json', 'decode_submission.json',
                 'generation_history.json', 'staged_generation.json', 'recipe.json']:
        file = folder/name
        if file.exists():
            provenance[name] = dict(path=file.relative_to(p.ROOT).as_posix(), sha256=p.sha(file))
    if c.get('composite'):
        assert name == 'move' or c['action'] == 'move'
        recipe=read(folder/'recipe.json')
        assert matte['recipe_sha256']==p.sha(folder/'recipe.json')
        for parent in [recipe['body'],recipe['wheels']]:
            original_folder=p.SOURCE_DIR/parent
            for file in original_folder.iterdir():
                if file.is_file() and file.suffix in {'.json','.mkv','.mp4','.latent','.txt'}:
                    provenance[parent+'_'+file.name]=dict(path=file.relative_to(p.ROOT).as_posix(),sha256=p.sha(file))
        for helper in ['composite_movement.py','measure_wheel_phase.py']:
            file=p.SOURCE_DIR/helper
            provenance[helper]=dict(path=file.relative_to(p.ROOT).as_posix(),sha256=p.sha(file))
    unit = dict(unit_id=baseline['unit_id'],
                reference_height=baseline.get('pose_reference_height', baseline['pose_frame_size']['height']),
                source_facing=baseline.get('pose_source_facing', 'right'),
                frames=frames, clips={c['action']: clip}, provenance=provenance,
                source_scale_reason='Fixed .45 anatomical scale with ground origin480,576; six whole-source H3 actions and original H3 wheel/body component movement. Fixed component scales, original axle registration and foreground occlusion; no per-frame size normalization, synthetic rotation or poses.',
                visual_review=dict(status='pending', notes=selected['review_note']))
    assert unit['reference_height'] == 256 and unit['source_facing'] == 'left'
    p.write(folder/'handoff.json', dict(schema_version=1, units=[unit]))
    return unit


def assemble():
    S = p.SOURCE_DIR
    delivery = read(S/'delivery.json')
    baseline = read(S/'original_unit_baseline.json')
    assert baseline['unit_id'] == S.name
    assert baseline['pose_clips']['idle']['frames'] == 8
    assert baseline['pose_clips']['idle']['frame_msec'] == 240
    assert 'idle' not in baseline.get('pose_aliases', {})
    unit = None
    provenance = {}
    for take in delivery['takes']:
        part = build(take, baseline)
        unit = p.combine(unit, part)
        provenance.update({take+'_'+key: value for key, value in part['provenance'].items()})
    assert set(unit['clips']) == REQUIRED
    unit['preserved_accepted_clips'] = ['idle']
    unit['visual_review'] = delivery.get('visual_review', dict(status='pending', notes='Seven source-qualified original H3 actions; actual battle Strike/Shoot, both-facing native, overworld and reduced-motion review still required. Preserve original eight240ms idle phases.'))
    for name in ['prepare.py', 'prepare_corrections.py', 'produce.py', 'stage_video.py',
                 'run_actions.py', 'segment.py', 'inspect_sources.py', 'matting_model.json',
                 'record_corrected_pair_review.py', 'record_melee_hit_review.py',
                 'prepare_hit_key_repair.py', 'matte_rotation_key.py', 'run_key_and_actions.py',
                 'prepare_brace_support_correction.py', 'record_hit_death_review.py',
                 'refine_rotation_plate.py', 'prepare_rolling_phase_control.py',
                 'record_brace_support_review.py',
                 'record_collapse_and_reassess_travel.py',
                 'record_support_and_prepare_physical_travel.py',
                 'sample_delivery_sources.py',
                 'runtime_profile.json', 'original_unit_baseline.json', 'original_map_baseline.json',
                 'original_pose_references.json', 'identity_lineage.json', 'brief.json',
                 'guide_review.json', 'initial_pair_review.json', 'delivery.json',
                 'contact_support_keys_v1/original.png', 'contact_support_keys_v1/generation.json',
                 'contact_support_keys_v1/prompt.txt', 'contact_support_keys_v1/references.json',
                 'build_delivery.py', 'prepare_review_tools.py', 'capture_clock.py',
                 'configure_runtime_review.py',
                 'run_native_review.py', 'run_mirrored_native.py', 'run_ranged_native.py',
                 'run_review_stage.py', 'run_live_review.py', 'verify_imported_atlas.gd',
                 'verify_delivery.py']:
        file = S/name
        assert file.is_file(), name
        provenance[name] = dict(path=file.relative_to(p.ROOT).as_posix(), sha256=p.sha(file))
    for name in ['rolling_rotation_key_v4/original.png', 'rolling_rotation_key_v4/generation.json',
                 'rolling_rotation_key_v4/prompt.txt', 'rolling_rotation_key_v4/matte.png',
                 'rolling_rotation_key_v4/matte.json', 'rolling_rotation_key_v4/matte_spatial_plate.png',
                 'rolling_rotation_key_v4/matte_spatial_plate.json',
                 'rolling_rotation_key_v4/matte_spatial_reference.json',
                 'rolling_rotation_key_v4/visual_review.json']:
        file=S/name
        assert file.is_file(),name
        provenance[name]=dict(path=file.relative_to(p.ROOT).as_posix(),sha256=p.sha(file))
    for ref in read(S/'original_pose_references.json'):
        file = p.ROOT/ref['source']
        provenance['original_'+ref['source']] = dict(path=ref['source'], sha256=p.sha(file))
    file = p.ROOT/'art/units/source/curated'/f'{S.name}.png'
    provenance['original_curated_identity'] = dict(path=file.relative_to(p.ROOT).as_posix(), sha256=p.sha(file))
    unit['provenance'] = provenance
    p.write(S/'handoff.json', dict(schema_version=1, units=[unit]))


if __name__ == '__main__':
    assemble()
