"""Correct the rejected staff-swing take without modifying its original pixels."""
import json
import produce as p

if __name__ == '__main__':
 old=p.SOURCE_DIR/'death_h3_v1';out=p.SOURCE_DIR/'death_h3_v2'
 assert (old/'original_lossless.mkv').exists() and not (out/'sampling_submission.json').exists()
 c=json.loads((old/'config.json').read_bytes());c['seed']=2026109407
 c['guides']=[[24,1],[56,2],[94,3]]
 c['prompt']=('One slow continuous passive lowering study of the same original forest woman and ordinary equipment. '
 'Fixed three-quarter view facing screen right, exactly two attached human arms and two human legs, '
 'same flower-decorated brown hair, green scarf, cream sleeves and brown-green original clothing. '
 'The two knees bend directly downward into the supplied kneeling pose. The right elbow stays low beside the waist '
 'and the right hand keeps the wooden staff upright at screen left throughout this first descent. '
 'The staff remains beside her body, its butt resting at the ground while the knees lower. '
 'Then the right hand lowers the same staff directly forward onto the ground, the whole wooden fork turning gently '
 'downward as the palm reaches the ground in the supplied seated pose. The left forearm keeps its one wicker buckler close to the chest. '
 'One original wooden fork staff, two fixed amber ornaments beside its fork, two green sling straps and one brown leather pouch '
 'remain physically intact during every transition. The whole equipment assembly moves with the staff. '
 'The right palm supports the torso while both bent legs settle sideways, matching the supplied seated guide. '
 'Next the right elbow bends as the torso slowly lowers onto its side; the left buckler arm settles beside the chest '
 'and the head rests on the attached near arm, matching the supplied final resting pose by frame94. '
 'The knees and torso descend continuously, both arms remain below shoulder level, the staff moves only downward to the ground. '
 'The final original resting body, staff, straps and pouch stay still through the final second. '
 'Original body proportions and ordinary painted materials are constant. All amber ornaments are solid inert objects. '
 'Unchanging blank uniform neutral gray surrounds the full character and equipment at every instant. '
 'Fixed camera, scale, body root x480 and ground y576. Foreground staff and pouch lie below the near forearm contact in perspective. '
 'Full painted body and equipment stay inside the960 by704 canvas throughout.')
 out.mkdir(exist_ok=True);p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
 for index in range(4):
  assert p.sha(old/f'guide_{index}_chroma.png')==p.sha(out/f'guide_{index}_chroma.png')
  assert p.sha(old/f'guide_{index}_rgba.png')==p.sha(out/f'guide_{index}_rgba.png')
 reason='All124 RGB/RGBA and17 critical enlarged original poses reviewed. Overhand staff swing and elongated airborne right arm53-55, pouch/ornament temporarily lost, then restored. Source defect; keep full take and regenerate passive continuous downward lowering with identical original guides and earlier explicit resting guide.'
 rejected=json.loads((p.SOURCE_DIR/'rejected_takes.json').read_bytes())
 assert not any(r['take']=='death_h3_v1' for r in rejected['takes'])
 rejected['takes'].append(dict(take='death_h3_v1',reason=reason,original_frames_retained=124,original_sha256=p.sha(old/'original_lossless.mkv'),latent_sha256=p.sha(old/'original.latent'),replacement='death_h3_v2'))
 p.write(p.SOURCE_DIR/'rejected_takes.json',rejected)
 reviews=json.loads((p.SOURCE_DIR/'source_reviews.json').read_bytes())
 reviews['death_h3_v1']=dict(original_rgb_frames_reviewed=124,original_rgba_frames_reviewed=124,critical_enlarged_frames=[0,18,21,24,32,48,51,53,54,55,57,66,84,87,90,96,123],source_status='rejected_overhand_swing_and_equipment_loss',note=reason)
 p.write(p.SOURCE_DIR/'source_reviews.json',reviews)
 corrections=json.loads((p.SOURCE_DIR/'preproduction_corrections.json').read_bytes())
 corrections['death_h3_v2']=dict(from_take='death_h3_v1',reason=reason,original_guides_byte_identical=True,guide_frames=c['guides'])
 p.write(p.SOURCE_DIR/'preproduction_corrections.json',corrections)
 delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());delivery['takes']=[('death_h3_v2' if t=='death_h3_v1' else t) for t in delivery['takes']]
 p.write(p.SOURCE_DIR/'delivery.json',delivery)
 print('PREPARED_DEATH_V2_IDENTICAL_ORIGINAL_GUIDES',flush=True)
