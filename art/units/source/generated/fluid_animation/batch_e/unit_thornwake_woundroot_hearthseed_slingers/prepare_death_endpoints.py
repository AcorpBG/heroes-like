"""Retain rejected intermediate prop duplication; use original ready/resting endpoints."""
import json
import produce as p

if __name__=='__main__':
 old=p.SOURCE_DIR/'death_h3_v3';out=p.SOURCE_DIR/'death_h3_v4'
 assert (old/'matte.json').exists() and not (out/'sampling_submission.json').exists()
 c=json.loads((old/'config.json').read_bytes())
 c.update(seed=2026109607,references=[c['references'][0],c['references'][2]],guides=[],last=1)
 c['prompt']=('The original adult forest woman slowly falls from the ready standing pose into the supplied final resting pose in one continuous natural movement. '
 'Her knees bend, hips and torso lower, and the body gently settles on its side. The right elbow stays low while the right hand lowers the single wooden fork staff to the foreground ground. '
 'The left arm keeps the single wicker buckler beside the chest. The near hand and forearm support the body as it lowers; the head finally rests on the near arm. '
 'Keep moving smoothly throughout the descent, then remain still in the final resting pose. '
 'Same original face, flower-decorated curly brown hair, green scarf, cream sleeves, green trousers, bark armor and boots; exactly two attached human arms and two legs. '
 'The one complete original Y-fork staff carries exactly two small fixed amber ornaments at its fork junction, two green sling straps and one brown leather pouch. These same attached parts rotate together as the staff lowers. '
 'Ordinary inert painted materials. Fixed three-quarter tactical camera facing screen right, body root x480, ground y576, full body and equipment within the960 by704 canvas. '
 'Uniform neutral gray background stays blank throughout.')
 out.mkdir(exist_ok=True);p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
 assert p.sha(out/'guide_0_chroma.png')==p.sha(old/'guide_0_chroma.png')
 assert p.sha(out/'guide_1_chroma.png')==p.sha(old/'guide_2_chroma.png')
 reason='All124 original RGB/RGBA and16 enlarged poses personally reviewed. Continuous body lowering passes, but fork carries four fixed amber ornaments during descent (24/34), resolving to two near96. Competing seated fork orientation likely caused duplication; reject original intact and remove seated middle guide.'
 rejected=json.loads((p.SOURCE_DIR/'rejected_takes.json').read_bytes());assert not any(r['take']=='death_h3_v3' for r in rejected['takes'])
 rejected['takes'].append(dict(take='death_h3_v3',reason=reason,original_frames_retained=124,original_sha256=p.sha(old/'original_lossless.mkv'),latent_sha256=p.sha(old/'original.latent'),replacement='death_h3_v4'));p.write(p.SOURCE_DIR/'rejected_takes.json',rejected)
 reviews=json.loads((p.SOURCE_DIR/'source_reviews.json').read_bytes());reviews['death_h3_v3']=dict(original_rgb_frames_reviewed=124,original_rgba_frames_reviewed=124,critical_enlarged_frames=[0,4,8,24,34,36,38,40,54,72,76,80,84,88,96,123],source_status='rejected_duplicate_fixed_fork_ornaments',note=reason);p.write(p.SOURCE_DIR/'source_reviews.json',reviews)
 corrections=json.loads((p.SOURCE_DIR/'preproduction_corrections.json').read_bytes());corrections['death_h3_v4']=dict(from_take='death_h3_v3',reason=reason,source_corrections=['Original ready and corrected resting endpoints only; seated master retained unused','Same canvas, anchors, anatomical scale and extraction; no subject cleanup'],guide_frames=[]);p.write(p.SOURCE_DIR/'preproduction_corrections.json',corrections)
 delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());delivery['takes']=[('death_h3_v4' if t=='death_h3_v3' else t) for t in delivery['takes']];p.write(p.SOURCE_DIR/'delivery.json',delivery)
 print('PREPARED_DEATH_V4_ENDPOINTS',flush=True)
