"""Build only the qualifying hit correction beside four unchanged accepted clips."""
import copy
import json
import produce as p

if __name__=='__main__':
    out=p.SOURCE_DIR/'hit_h3_v2'
    selection=dict(source_frames=[18,19,20,21,22,23,24,26,28,64,65,66,67,68,69,70,71,72,75],frame_msec=45,
        review_note='All124 chronological original and final matte frames reviewed, plus enlarged18,20,21,22,23,24,26,28,64,65,66,67,68,69,70,72. One backward torso/head impact recoil; exactly two arms/grips on one hook pole, two legs and original rope/cloth retained. Long recoil hold shortened between original28 and64 using distinct unmodified original pixels, then full recovery64-75. Four-source-pixel boundary-only green despill preserves alpha/body geometry and opaque teal. Fixed .5 extraction scale and470,560 anchor. Continuous source/retimed playback unavailable; selected native fixture and coordinator acceptance required.')
    selection['frame_durations_msec']=[45]*len(selection['source_frames'])
    selection['frame_durations_msec'][8]=100
    p.write(out/'selection.json',selection)
    p.build(out,json.loads((out/'config.json').read_bytes()))
    previous=json.loads((p.SOURCE_DIR/'handoff.json').read_bytes())['units'][0]
    hit=json.loads((out/'handoff.json').read_bytes())['units'][0]
    combined=p.combine(previous,hit)
    combined['provenance']={**copy.deepcopy(previous['provenance']),**{'hit_h3_v2_'+k:v for k,v in hit['provenance'].items()}}
    combined['preserved_accepted_clips']=['idle']
    combined['visual_review']={'status':'pending','notes':'Correction candidate includes unchanged published attack22/defend12/physical support19/death26 plus new hit19. Original articulated idle8 retained. Only hit is pending coordinator acceptance/publication; old four are accepted and remain pixel-identical. Movev2 excluded: repeated upright-ready blocks and abrupt changes do not prove coherent reciprocal armored-knee/boot support/loading/passing. No further generation authorized this run; all originals/latent/guides/provenance preserved. Continuous playback unavailable; native/source lineage checks required.'}
    p.write(p.SOURCE_DIR/'handoff_corrections.json',{'schema_version':1,'units':[combined]})
    p.write(p.SOURCE_DIR/'correction_delivery.json',dict(unit_id=hit['unit_id'],finite_pair=['move_h3_v2','hit_h3_v2'],candidate_clips=['hit'],preserved_published_clips=['attack','defend','cast','death'],preserved_accepted_clips=['idle'],rejected_takes={'move_h3_v2':'Stable green plate with all124 matte frames intact, but repeated upright ready holds13-21/47-55/79-86/113-120 and abrupt ready-to-run22/56/87 and raised-knee-to-opposed contact33/65; enlarged35/36→37-40 and65-70 does not establish reciprocal near/far armored-knee/boot support reliably. Continuous weight transfer, stance-to-swing and passing identity remain unproven. No more retries this run.'},visual_review=combined['visual_review']))
