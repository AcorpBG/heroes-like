"""Preserve failed arm display and condition a separate original grounded nod."""
import json
import produce as p

if __name__ == '__main__':
    old = p.SOURCE_DIR / 'cast_h3_v4'
    out = p.SOURCE_DIR / 'cast_h3_v5'
    assert not out.exists()
    p.write(old / 'rejection.json', dict(status='rejected_source', original_rgb_frames_reviewed=124, matte_frames_reviewed=124, enlarged_matched_phase_indices=[24,30,36,48,74,123], representative_native_frame_indices=list(range(16,48)), native_facings_reviewed=['normal','reflected'], reason='Stable magenta backdrop, but an invented connected white-yellow chest burst grows during raised-arm display around frames30-46. Original painted seed-heart becomes a bright effect. Full gesture cannot be selected by omitting its middle. No connected effect removal or recoloring.', all_originals_and_recipes_preserved=True, continuous_video_playback=False))
    c = json.loads((old / 'config.json').read_bytes())
    guard = json.loads((p.SOURCE_DIR / 'defend_h3_v2/config.json').read_bytes())
    c['references'] = [guard['references'][0], dict(guard['references'][1], name='original_grounded_nod')]
    c['guides'] = [[48,1]]
    c['last'] = 0
    c['seed'] = 2026120505
    c['prompt'] = ('One original painted Rootmaul Behemoth performs one grounded shoulder and head nod in the fixed three-quarter tactical view. '
                   'Starting in the supplied ready, bend the two rear knees a little and hinge both front elbows so the heavy shoulders and forked wooden crown settle forward and downward into the supplied low original painting. '
                   'Its two front root arms keep their three stone claws low beside the two rear root feet. Both hands and both feet remain connected to the same body. '
                   'Hold the low nod briefly, then extend the knees and elbows smoothly to recover the identical supplied ready. One complete nod and recovery. '
                   'Every surface is fixed painted brown bark, gray-green stone, green moss and orange leaves with unchanged original shading and unchanged painted orange insets. '
                   'The tail remains curled behind the body. The entire empty backdrop stays uniformly magenta RGB255,0,255 from first to last frame. '
                   'Original anatomical proportions, four limbs, camera, scale, lighting and root support plane stay fixed throughout.')
    out.mkdir()
    p.write(out / 'config.json', c)
    p.prepare(out, c)
    p.verify(out, c)
    measurement = json.loads((p.SOURCE_DIR / 'defend_h3_v2/foreground_measurement.json').read_bytes())
    for guide in measurement['guides']:
        guide['path'] = guide['path'].replace('defend_h3_v2', out.name)
        assert p.sha(p.ROOT / guide['path']) == guide['sha256']
    p.write(out / 'foreground_measurement.json', measurement)
    p.write(out / 'correction.json', dict(prior_take=old.name, prior_rejection_sha256=p.sha(old / 'rejection.json'), change='Raised-arm display induced a connected chest burst despite stable background. New dedicated support source uses the personally reviewed original grounded low pose, quiet head/shoulder nod and complete ready recovery. This is independent H3 footage, not guard/idle footage reuse. No model, sampler, canvas, anatomy scale, anchor or matte changes.', fixed_matte_sha256=p.sha(p.SOURCE_DIR / 'segment.py')))
    delivery = json.loads((p.SOURCE_DIR / 'delivery.json').read_bytes())
    delivery['takes'] = [x.replace('cast_h3_v4','cast_h3_v5') for x in delivery['takes']]
    delivery['failed_takes'].append('cast_h3_v4')
    p.write(p.SOURCE_DIR / 'delivery.json', delivery)
    print('Separate original grounded support prepared and verified; unsubmitted.', flush=True)
