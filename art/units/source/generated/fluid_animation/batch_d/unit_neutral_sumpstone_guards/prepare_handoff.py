"""Build Sumpstone crops using shared exact-component extraction in sibling source."""
from pathlib import Path
import importlib.util,json
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('source_extraction',HERE.parent/'unit_neutral_sporelamp_tossers/prepare_handoff.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
m.HERE=HERE;m.ROOT=HERE.parents[6];m.UID=HERE.name
m.OUTPUTS={
 'move_v1':'exec-d2b2ccb4-59c0-4762-aeb2-45f9a4637dc4.png',
 'attack_v1':'exec-b137b9f0-148d-4759-b6d9-d84f73ca8443.png',
 'reactions_v1':'exec-9df71ca4-c24a-48a3-b244-3337915f31f8.png',
 'death_v1':'exec-f4f60b55-8bce-4787-8b1f-138103350d14.png',
 'cast_v1':'exec-3c561bfd-f9d2-434d-9c42-e61d41d60cf3.png',
 'cast_v2':'exec-d4a69faf-2052-4097-91f6-544d49dbe3dc.png',
 'move_contacts_v1_rejected':'exec-9d8f60bd-3a39-4401-9e97-0cd38a8d0124.png',
 'move_contacts_v2':'exec-7f30aa6e-fe6e-48cf-86e2-184fdb821699.png',
 'move_inbetweens_v1_rejected':'exec-ffbdd51d-187e-40a5-b28d-ab93b0e9f1ef.png',
 'move_inbetweens_v2_rejected':'exec-a296635b-f66d-4761-99c6-779a52a0f6a6.png',
 'move_inbetweens_v3':'exec-bb466efe-e6ee-41dd-ae73-f454d5d90fe5.png',
}
m.SPECS={
 'move_contacts_v2':{'scale':0.212,'clips':['move']*2,'xs':[460,1332],'ys':[844,839]},
 'move_inbetweens_v3':{'scale':0.331,'columns':3,'clips':['move']*6,'xs':[285,781,1277,285,781,1277],'ys':[498,503,504,995,977,999]},
 'attack_v1':{'scale':0.433,'clips':['attack']*8,'xs':[295,773,295,776,294,776,297,778],'ys':[380,376,797,795,1137,1151,1511,1512]},
 'reactions_v1':{'scale':0.419,'clips':['hit']*4+['defend']*4,'xs':[287,779,287,778,287,779,289,778],'ys':[400,401,785,794,1179,1173,1519,1519]},
 'death_v1':{'scale':0.377,'clips':['death']*8,'xs':[287,803,291,789,291,787,293,787],'ys':[444,443,837,861,1191,1206,1497,1497]},
 'cast_v2':{'scale':0.503,'clips':['cast']*8,'xs':[290,770,287,771,287,771,287,772],'ys':[374,374,751,751,1132,1128,1487,1487]},
}
if __name__=='__main__':
    m.build()
    path=HERE/'handoff.json';handoff=json.loads(path.read_text());entry=handoff['units'][0]
    entry['source_scale_reason']='Each originating master has one fixed anatomical scale matching existing 162-pixel idle figure. Separate crop files retain that exact master scale; no per-frame normalization.'
    entry['visual_review']={'status':'pending','existing_idle':'Eight original idle paintings inspected: coherent pickaxe arm lift and settle with planted feet and rigid shield. Recommend retention, coordinator final acceptance required.','movement':'Opposite-contact and six-inbetween paintings repaired with specific leg-only edits; both shield-side and pick-side legs now lead. Pending coordinator review of full motion.'}
    entry['clips']['move']['loop']=True
    indices=entry['clips']['move']['indices'];entry['clips']['move']['indices']=[indices[i] for i in [0,2,3,4,1,5,6,7]]
    path.write_text(json.dumps(handoff,indent=2)+'\n')
    path=HERE/'provenance.json';provenance=json.loads(path.read_text())
    for generation in provenance['generations']:
        if generation['master'].endswith('cast_v1.png'):
            generation['status']='rejected';generation['rejection_reason']='Raised pickaxe touches preceding pose in source sheet.'
        if generation['master'].endswith('cast_v2.png'):
            generation['reference']=(HERE/'cast_v1.png').relative_to(m.ROOT).as_posix()
        name=Path(generation['master']).stem
        if name=='move_v1':generation['status']='rejected';generation['rejection_reason']='Same lead-foot shuffle rather than alternating gait.'
        refs={
          'move_contacts_v1_rejected':['art/units/source/generated/fluid_animation/batch_a/unit_river_guard_veteran/move_contacts_v2.png',provenance['reference']],
          'move_contacts_v2':[(HERE/'move_contacts_v1_rejected.png').relative_to(m.ROOT).as_posix()],
          'move_inbetweens_v1_rejected':['art/units/source/generated/fluid_animation/batch_a/unit_river_guard_veteran/move_inbetweens_v1.png',(HERE/'move_contacts_v2.png').relative_to(m.ROOT).as_posix()],
          'move_inbetweens_v2_rejected':[(HERE/'move_inbetweens_v1_rejected.png').relative_to(m.ROOT).as_posix()],
          'move_inbetweens_v3':[(HERE/'move_inbetweens_v2_rejected.png').relative_to(m.ROOT).as_posix()],
        }
        if name in refs:generation['references']=refs[name]
    for crop in provenance['extraction']:crop['method']='Exact connected foreground pixel extraction with alpha<=8 removed; no repainting, warping or interpolation.'
    path.write_text(json.dumps(provenance,indent=2)+'\n')
