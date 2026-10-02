"""Reassess two breath-contaminated takes with literal motion and dense guides."""
import json
import produce as p

if __name__=='__main__':
    c=json.loads((p.SOURCE_DIR/'attack_h3_v2/config.json').read_bytes())
    out=p.SOURCE_DIR/'attack_h3_v3';out.mkdir(exist_ok=True)
    assert not (out/'sampling_submission.json').exists(),'Submitted source is immutable'
    c['seed']=2026108322
    c['guides']=[[8,0],[18,1],[32,1],[48,1],[64,1],[84,0],[104,0]]
    c['prompt']='The exact original four-winged white-opal jewel creature in the supplied reference images, facing screen right in its original three-quarter side view. Exactly four attached glass wings with their original gold frame and curved veins, two small gold taloned legs, and two white trailing tail ribbons ending in prism-leaf fins. Its original swept golden crest, long white-and-gold beak, glass colours and proportions remain consistent. One short physical balancing adjustment: the near leg gently unfolds forward, extends its small gold claws in the supplied second pose, closes the claws once, then curls back underneath the chest. The far leg stays tucked. The beak stays fully shut and relaxed throughout, with its mouth outline fixed. The glass wings brace with small hinge adjustments, and both tail ribbons sway slightly then settle. The wing roots and body retain the same position and anatomical scale in a fixed camera. After this single leg extension and recovery, continue quiet hovering in the initial ready posture. The entire space outside the complete creature silhouette stays uniform dark navy RGB16,32,64 throughout. All four wing tips, both tails and both legs remain comfortably inside the image. The original airborne body keeps its original clearance above logical ground plane y640.'
    p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
    delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
    delivery['takes']=['attack_h3_v3' if t=='attack_h3_v2' else t for t in delivery['takes']]
    if 'attack_h3_v2' not in delivery['rejected_takes']:delivery['rejected_takes'].append('attack_h3_v2')
    delivery['rejection_notes'].append(dict(take='attack_h3_v2',reviewed_original_frames=124,reason='All124 RGB frames reviewed. Reach14-22 is followed by unwanted connected breath23-26 and detached shards27-51. Clean held64 and pre-emission22 have different wing elevation and tail curvature; native join would jump. Reject whole source rather than remove connected pixels or splice incompatible endpoints. Reassessment: remove effect/combat terminology from positive conditioning and constrain ready/contact/recovery with seven closer original-painting guides.'))
    p.write(p.SOURCE_DIR/'delivery.json',delivery)
    print('Prepared literal physical balancing motion with seven dense original guides; both previous takes preserved.',flush=True)
