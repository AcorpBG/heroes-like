"""Preserve unsubmitted recipes and prepare quiet physical support/collapse."""
import json
import produce as p

if __name__ == '__main__':
    for name, count in [('hit_h3_v2',25),('defend_h3_v2',21)]:
        out=p.SOURCE_DIR/name
        review=json.loads((out/'source_interval_review.json').read_bytes())
        assert len(review['selected_frames'])==count
        review['status']='source_interval_personally_reviewed_pending_full_unit_runtime'
        review['selected_enlarged_frames_reviewed']=count
        review['all_selected_matched_rgb_rgba_enlarged_reviewed']=True
        review['notes']=review['notes'].replace('Source enlarged representative phases reviewed; all selected enlarged poses and actual full-unit runtime remain pending.', 'Every selected pose personally reviewed enlarged against its original RGB. Actual full-unit runtime remains pending.')
        p.write(out/'source_interval_review.json',review)
        p.build(out,json.loads((out/'config.json').read_bytes()))
    plate=('The entire empty backdrop is one unchanging flat magenta color RGB255,0,255 throughout every frame. Its color is identical to the supplied images from beginning to end. The background has no lighting, color transition or other objects. The creature has only quiet physical joint motion, while camera, original anatomical scale and root support plane remain fixed. ')
    identity=('One original painterly ROOTMAUL BEHEMOTH facing SCREEN RIGHT in a fixed three-quarter tactical camera. Exactly four connected limbs: two heavy front root arms with three stone claws each and two rear root legs with stone feet. Keep its tangled brown bark, forked wooden crown enclosing the face, amber painted eyes and seed-heart, gray-green stone shoulder plates, leafy green moss mantle with orange leaves and curled root tail. Every original material retains its painted color and fixed light. ')
    actions={
        'cast': 'Beginning in supplied ready, bend the near front root elbow on SCREEN LEFT and raise that same three-stone-clawed hand to upper chest height as in the supplied hand gesture. The far front hand on SCREEN RIGHT and both rear root feet remain grounded under the same hunched creature. Hold the raised hand briefly, then lower it smoothly into the identical supplied ready. One complete quiet physical hand gesture and recovery. ',
        'death': 'Beginning in supplied ready, bend the two rear root knees and let the hips sink. Both front root elbows flex under the same heavy torso as the forked crown lowers. All four connected root limbs fold as the creature settles onto its original side, following the supplied buckle and grounded collapse paintings. End in the supplied quiet grounded corpse with its dull painted amber details and hold this final pose. One continuous physical collapse. '
    }
    for clip in actions:
        old=p.SOURCE_DIR/f'{clip}_h3_v1';out=p.SOURCE_DIR/f'{clip}_h3_v2'
        assert not (old/'sampling_submission.json').exists() and not out.exists()
        out.mkdir();c=json.loads((old/'config.json').read_bytes())
        c['prompt']=(plate+identity+actions[clip]+plate).strip()
        c['seed']=2026120205 if clip=='cast' else 2026120206
        p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
        for filename in ['foreground_measurement.json','extraction_settings.json']:
            if (old/filename).exists():
                record=json.loads((old/filename).read_bytes())
                for guide in record.get('guides',[]):
                    guide['path']=guide['path'].replace(old.name,out.name)
                    assert p.sha(p.ROOT/guide['path'])==guide['sha256']
                p.write(out/filename,record)
        p.write(out/'correction.json',dict(prior_take=old.name,prior_take_was_unsubmitted=True,change='Short positive physical motion and unchanged static plate wording from successful recoil/guard. Same original references, controls, anatomical registration, model, sampler and fixed matte; distinct seed.'))
    delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
    delivery['takes']=[x.replace('cast_h3_v1','cast_h3_v2').replace('death_h3_v1','death_h3_v2') for x in delivery['takes']]
    delivery['superseded_unsubmitted_takes']=['cast_h3_v1','death_h3_v1']
    p.write(p.SOURCE_DIR/'delivery.json',delivery)
    brief=json.loads((p.SOURCE_DIR/'brief.json').read_bytes());brief['source_status']='four_sources_personally_reviewed_support_collapse_prepared_unsubmitted';p.write(p.SOURCE_DIR/'brief.json',brief)
    print('Four selected sources reviewed; two quiet static-plate recipes verified, unsubmitted.',flush=True)
