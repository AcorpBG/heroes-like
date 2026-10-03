"""Preserve failed originals and prepare distinct static-plate correction takes."""
import json
import produce as p

if __name__ == '__main__':
    brief = json.loads((p.SOURCE_DIR / 'brief.json').read_bytes())
    identity = ('One original painterly ROOTMAUL BEHEMOTH facing SCREEN RIGHT in a fixed three-quarter tactical camera. '
                'Exactly four connected limbs: two heavy front root arms with three stone claws each and two rear root legs with stone feet. '
                'Keep its tangled brown bark, forked wooden crown enclosing the face, amber painted eyes and seed-heart, gray-green stone shoulder plates, leafy green moss mantle with orange leaves and curled root tail. '
                'Every original material retains its painted color and fixed light; the amber insets stay unchanged. ')
    plate = ('The entire empty backdrop is one unchanging flat magenta color RGB255,0,255 throughout every frame. '
             'Its color is identical to the supplied images from beginning to end. '
             'The background has no lighting, color transition or other objects. '
             'The creature has only quiet physical joint motion, while camera, original anatomical scale and root support plane remain fixed. ')
    actions = {
        'hit': ('Beginning in supplied ready, flex the two rear knees and hinge the shoulders backward a little while bending both front elbows to draw the clawed hands slightly inward. '
                'Keep the hands low and the same root feet under the hips. Settle the shoulders back, extend the rear knees and lower both front hands continuously into the identical supplied ready. '
                'One brief backward rock and one complete recovery, with no repeated cycle. '),
        'defend': ('Beginning in supplied ready, bend both front elbows and rear knees, lower the heavy shoulder plates and forked crown into the supplied compact low guard. '
                   'Keep the same two front clawed hands and two rear root feet braced against the original support plane. '
                   'Reach the supplied guard by the middle of the clip and hold this same quiet crouch through the last frame. ')
    }
    for clip in actions:
        old = p.SOURCE_DIR / f'{clip}_h3_v1'
        p.write(old / 'rejection.json', dict(
            status='rejected_source', original_rgb_frames_reviewed=124, matte_frames_reviewed=124,
            enlarged_matched_phase_indices=([0,16,24,32,44,64,80,100,123] if clip=='hit' else [0,16,32,48,64,80,100,123]),
            reason='Generated backdrop changes color and connected bark/leaf edges retain visibly unnatural purple coloration. Original RGB and opaque matte equality pass, but this source is unsuitable for publication. Do not recolor or mask connected subject pixels.',
            all_originals_and_recipes_preserved=True, continuous_video_playback=False))
        target = p.SOURCE_DIR / f'{clip}_h3_v2'
        assert not target.exists(), target
        target.mkdir()
        config = json.loads((old / 'config.json').read_bytes())
        config['prompt'] = (plate + identity + actions[clip] + plate).strip()
        config['seed'] = 2026120203 if clip == 'hit' else 2026120204
        if clip == 'defend': config['guides'] = [[64,1]]
        p.write(target / 'config.json', config)
        p.prepare(target, config)
        # Reuse the measured palette rule; new prepared guides are byte-identical
        # original paintings on the same fixed plate, not new artwork.
        for name in ['foreground_measurement.json','extraction_settings.json']:
            if (old / name).exists():
                record=json.loads((old / name).read_bytes())
                for guide in record.get('guides',[]):
                    guide['path']=guide['path'].replace(old.name,target.name)
                    assert p.sha(p.ROOT/guide['path'])==guide['sha256']
                p.write(target / name, record)
        p.write(target / 'correction.json', dict(
            prior_take=old.name, prior_rejection_sha256=p.sha(old/'rejection.json'),
            change='Shorter positive physical description with explicit identical static plate at both ends. New seed; guard adds one supplied original low-guard control at frame64. Original guide anatomy, canvas, registration, sampler, model and matte settings are unchanged.'))
    delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
    delivery['takes']=[x.replace('hit_h3_v1','hit_h3_v2').replace('defend_h3_v1','defend_h3_v2') for x in delivery['takes']]
    delivery['failed_takes']=['hit_h3_v1','defend_h3_v1']
    p.write(p.SOURCE_DIR/'delivery.json',delivery)
    print('Rejected originals preserved; corrected recoil/guard prepared, not submitted.',flush=True)
