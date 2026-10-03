"""Source-correct missing fork ornaments and register body contacts once."""
import json,shutil
from pathlib import Path
from PIL import Image
import produce as p

PROMPTS=[
"Edit the FIRST supplied image, the seated original forest woman with a fallen fork staff. The second standing image is a prop detail reference only. Keep the first image's exact pose, adult woman anatomy with two arms and two legs, face, clothing, hair, wicker shield, staff geometry, two long green sling cords and one brown leather pouch, composition, framing and original painted strategy sprite style. Make one precise continuity correction only: restore the TWO small solid orange amber teardrop ornaments attached by the green bindings beside the staff's Y fork junction, exactly as seen at the fork in the second image. In the first image the staff lies diagonally on the ground across the foreground with fork at lower right, so those same two attached ornaments lie beside that visible fork junction. They remain physically attached to the fork, with original brown/green bindings; no magic, glow, particles, projectile or extra pouch. Preserve full staff, fork tips, pouch and limbs inside original generous blank margins. Transparent background with clean natural original brown/green/cream artwork edges. Return one corrected seated-pose sprite only, no second character, no labels. Preserve first image's 960 by 704 canvas and registration.",
"Edit the FIRST supplied image, the original forest woman resting on her side with fallen fork staff. The second standing image is a prop detail reference only. Keep the first image's exact resting pose, adult woman anatomy with two arms and two legs, closed eyes, face, clothing, hair, wicker shield, staff geometry, two long green sling cords and one brown leather pouch, composition, framing and original painted strategy sprite style. Make one precise continuity correction only: restore the TWO small solid orange amber teardrop ornaments attached by the green bindings beside the staff's Y fork junction, exactly as seen at the fork in the second image. In the first image the staff lies almost horizontally across the foreground with fork at lower right, so those same two attached ornaments lie beside that visible fork junction. They remain physically attached to the fork, with original brown/green bindings; no magic, glow, particles, projectile or extra pouch. Preserve full staff, fork tips, pouch and limbs inside original generous blank margins. Transparent background with clean natural original brown/green/cream artwork edges. Return one corrected resting-pose sprite only, no second character, no labels. Preserve first image's 960 by 704 canvas and registration."
]

if __name__=='__main__':
 old=p.SOURCE_DIR/'death_h3_v2';out=p.SOURCE_DIR/'death_h3_v3'
 assert (old/'original_lossless.mkv').exists() and not (out/'sampling_submission.json').exists()
 original=p.SOURCE_DIR/'death_h3_v1'
 specs=[('death_seated_continuity_v1','exec-be2c99fc-9d50-427f-9dc5-b4c13fbab05c.png',2,[779,697],.275),('death_resting_continuity_v1','exec-6d3facec-98a5-43f9-b300-d16952b53286.png',3,[750,826],.1915)]
 refs=[json.loads((old/'config.json').read_bytes())['references'][0]]
 for index,(name,filename,guide,anchor,scale) in enumerate(specs):
  tool=Path('C:/Users/acorp/.codex/generated_images/01a0fd4e-7754-7a91-8e06-2b328cba8526')/filename
  master=p.SOURCE_DIR/(name+'.png');prompt=p.SOURCE_DIR/(name+'.prompt.txt')
  shutil.copyfile(tool,master);assert p.sha(tool)==p.sha(master)
  prompt.write_text(PROMPTS[index]+'\n',encoding='utf-8')
  im=Image.open(master);assert im.mode=='RGBA' and im.size==(1465,1073)
  lineage=[original/f'guide_{guide}_rgba.png',original/'guide_0_rgba.png']
  p.write(master.with_suffix('.generation.json'),dict(image=master.relative_to(p.ROOT).as_posix(),image_sha256=p.sha(master),prompt_file=prompt.relative_to(p.ROOT).as_posix(),prompt_sha256=p.sha(prompt),tool='built-in imagegen',original_tool_output=str(tool),references=[dict(path=f.relative_to(p.ROOT).as_posix(),sha256=p.sha(f)) for f in lineage],registration=dict(anchor=anchor,scale=scale,reason='Single whole-master anatomical scale from original seated/resting body width, near palm/forearm ground contact. Original seated guide used foreground equipment as ground and lifted body above common floor. No per-frame stabilization or opaque pixel cleanup.'),review='Two-arm/two-leg original forest woman, one wicker buckler, one staff, twin green straps, one pouch and two attached amber fork ornaments. Source-corrected master; full prepared guide/native review required.'))
  refs.append(dict(source=master.relative_to(p.ROOT).as_posix(),rects=[[0,0,*im.size]],anchor=anchor,scale=scale,alpha_noise_cutoff=8))
 c=json.loads((old/'config.json').read_bytes());c.update(seed=2026109507,references=refs,guides=[[54,1]],last=2)
 c['prompt']=('One continuous natural lowering movement of the original forest woman from the first ready pose through the supplied seated pose into the final resting pose. '
 'Both human knees gradually bend while the torso leans forward and lowers, with continuous joint movement throughout. '
 'The right hand lowers the one wooden fork staff beside the body toward the foreground ground as the knees descend. '
 'The right elbow remains low. The staff butt descends first, the whole staff slowly turns into the ground position and the right palm reaches the same ground to support the torso. '
 'The left arm keeps the one wicker buckler close to the chest. Both legs settle sideways into the supplied seated pose. '
 'Continue moving smoothly: the right elbow bends and the torso lowers onto its side, head rests on the near attached arm, left buckler arm rests beside the chest. '
 'The body settles gently in the final original resting pose and stays there. '
 'Exactly two attached human arms and two human legs, same adult woman, face, flower-decorated curly brown hair, green scarf, cream sleeves, green trousers and brown-green original armor throughout. '
 'One complete original Y-fork wooden staff retains its two small attached solid amber fork ornaments, two green sling straps and one brown leather pouch while lowering and resting on the ground. '
 'One original wicker buckler stays on the left forearm. Ordinary inert painted materials, continuous passive body descent with low arms and downward staff motion. '
 'Fixed three-quarter tactical camera, screen-right facing, same scale and body root x480. Ground contact for knees, supporting palm and resting near forearm is y576; fallen staff and pouch lie below in foreground perspective. '
 'Full body and all equipment stay inside the960 by704 canvas. Uniform neutral gray around the subject stays completely blank at every instant.')
 out.mkdir(exist_ok=True);p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
 registration=json.loads((p.SOURCE_DIR/'runtime_registration.json').read_bytes())
 registration['original_corpse_guide']=registration.get('original_corpse_guide',registration['corpse_guide'])
 registration['corpse_guide']=refs[2];registration['death_seated_guide']=refs[1]
 registration['death_registration_reason']='Imagegen source-corrected fallen guides retain two fixed amber fork ornaments. One anatomical scale per new master (.275 seated/.1915 resting), near-palm/forearm floor contact measured once. Original seated reference placed body about96 source pixels above common floor using loose equipment anchor. Same .5 extraction scale,960x704 canvas and480,576 anchor throughout; no per-frame normalization or opaque art cleanup.'
 p.write(p.SOURCE_DIR/'runtime_registration.json',registration)
 assert p.sha(out/'guide_0_chroma.png')==p.sha(old/'guide_0_chroma.png')
 reason='Every124 original RGB/RGBA and17 enlarged critical poses reviewed: long held kneel through41 jumps directly to seated42, with no original transition; bare fork inherited from original fallen guides. Reject entire take; retain video/latent/mattes and source-correct guides plus one middle landmark.'
 rejected=json.loads((p.SOURCE_DIR/'rejected_takes.json').read_bytes());assert not any(r['take']=='death_h3_v2' for r in rejected['takes'])
 rejected['takes'].append(dict(take='death_h3_v2',reason=reason,original_frames_retained=124,original_sha256=p.sha(old/'original_lossless.mkv'),latent_sha256=p.sha(old/'original.latent'),replacement='death_h3_v3'));p.write(p.SOURCE_DIR/'rejected_takes.json',rejected)
 reviews=json.loads((p.SOURCE_DIR/'source_reviews.json').read_bytes());reviews['death_h3_v2']=dict(original_rgb_frames_reviewed=124,original_rgba_frames_reviewed=124,critical_enlarged_frames=[0,4,8,24,38,40,41,42,43,56,68,70,72,74,76,94,123],source_status='rejected_held_kneel_to_seated_cut_and_missing_ornaments',note=reason);p.write(p.SOURCE_DIR/'source_reviews.json',reviews)
 corrections=json.loads((p.SOURCE_DIR/'preproduction_corrections.json').read_bytes());corrections['death_h3_v3']=dict(from_take='death_h3_v2',reason=reason,source_corrections=['Two amber fork ornaments restored through imagegen on seated/resting original guides','Seated near-palm ground registered once instead of original foreground equipment anchor','One middle seated guide; continuous descent without authored holds between stages'],guide_frames=c['guides']);p.write(p.SOURCE_DIR/'preproduction_corrections.json',corrections)
 delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());delivery['takes']=[('death_h3_v3' if t=='death_h3_v2' else t) for t in delivery['takes']];p.write(p.SOURCE_DIR/'delivery.json',delivery)
 print('PREPARED_DEATH_V3_SOURCE_CONTINUITY',flush=True)
