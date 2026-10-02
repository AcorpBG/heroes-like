"""Reject baked impact star; guide a plain physical palm shove earlier."""
import json
import produce as p
c=json.loads((p.SOURCE_DIR/'attack_h3_v1/config.json').read_bytes())
c['seed']=2026108312;c['guides']=[[24,1],[48,2],[70,2]]
c['prompt']='A PLAIN PHYSICAL MELEE SHOVE with no visual effects anywhere. The free hand stays an ordinary leather-gloved human palm: no glow, light, sparks, starburst, streaks, magic or shockwave at any frame. '+c['prompt']+' Draw the free LEFT hand back during frames12-24; smoothly extend forearm and open palm from24-48 with no abrupt cut. Hold the plain palm contact briefly, then smoothly withdraw and recover. Keep the rope hand low and bell physically tethered. ALL background stays one constant flat magenta; no color cycling.'
out=p.SOURCE_DIR/'attack_h3_v2';out.mkdir(exist_ok=True)
if (out/'sampling_submission.json').exists() or (out/'submission.json').exists():
 assert json.loads((out/'config.json').read_bytes())==c,'Submitted correction is immutable'
else:p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
path=p.SOURCE_DIR/'rejected_takes.json';rejected=json.loads(path.read_bytes()) if path.exists() else {}
rejected['attack_h3_v1']=dict(status='rejected',defect='Invented bright palm impact star/lines in original44-50; abrupt impulse44. Preserve original124 RGB frames/latent and recipes. Regenerate plain physical palm transition with earlier contact guide.',reviewed_original_frames=124,reviewed_matte_frames=124)
p.write(path,rejected)
