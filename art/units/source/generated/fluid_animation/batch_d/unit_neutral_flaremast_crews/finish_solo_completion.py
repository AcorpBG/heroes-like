"""Pack reviewed original action selections without altering accepted artwork."""
import copy
import json
import produce as p

if __name__=='__main__':
    s=p.SOURCE_DIR
    selections=json.loads((s/'solo_selections.json').read_bytes())
    previous=json.loads((p.ROOT/'art/animation/source/fluid/unit_neutral_flaremast_crews/reviewed_handoff.json').read_bytes())['units'][0]
    combined=copy.deepcopy(previous)
    provenance=copy.deepcopy(previous['provenance'])
    for clip,record in selections['clips'].items():
        take=record['take'];out=s/take;selection=record['selection']
        p.write(out/'selection.json',selection)
        p.build(out,json.loads((out/'config.json').read_bytes()))
        entry=json.loads((out/'handoff.json').read_bytes())['units'][0]
        # Match the established reference-to-idle conversion for this unit.
        for frame in entry['frames']:
            frame['scale']=.45;frame['anchor']=[470,576]
        entry['source_scale_reason']='Same .90 anatomical conversion as accepted guard/support/death; every new H3 action fixed .45 scale and [470,576] ground registration.'
        combined=p.combine(combined,entry)
        provenance.update({take+'_'+k:v for k,v in entry['provenance'].items()})
    # Control compositions reference original guide masters and H3 frame crops.
    # Preserve that complete lineage, including rejected original guide variants.
    names=['mast_original35','mast_component35','ranged_aim_original36','walk_contact_original48','walk_contact_original61','melee_elbow_master_v1','melee_elbow_body_v2','melee_elbow_body_v2_control','hit_tucked_body_v1','hit_tucked_body_v2','hit_tucked_body_v2_control','ranged_recoil_body_v1','ranged_recoil_body_v2','ranged_recoil_body_v2_control','walk_opposed_contact_v1','walk_opposed_contact_v1_matte','melee_kick_body_v1','melee_kick_body_v1_control']
    for name in names:
        for suffix in ['.png','.json','.prompt.txt','.generation.json']:
            path=s/(name+suffix)
            if path.exists():provenance['solo_guide_'+path.name]=dict(path=path.relative_to(p.ROOT).as_posix(),sha256=p.sha(path))
    combined['provenance']=provenance
    combined['preserved_accepted_clips']=['idle']
    combined['visual_review']=copy.deepcopy(selections['visual_review'])
    p.write(s/'handoff_solo_completion.json',dict(schema_version=1,units=[combined]))
    p.write(s/'solo_delivery.json',dict(unit_id='unit_neutral_flaremast_crews',new_takes=[r['take'] for r in selections['clips'].values()],new_clips=list(selections['clips']),preserved_published_clips=['idle','defend','cast','death','dead'],selection_source='solo_selections.json',visual_review=combined['visual_review'],runtime_scale=.45,ground_anchor=[470,576],rule='Solo full-unit closure; every selected frame is original H3 output, no synthesis or per-frame normalization.'))
    print('Prepared candidate clips:',{k:len(v['indices']) for k,v in combined['clips'].items()})
