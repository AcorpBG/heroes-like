"""Replace rejected obscuring source effects with a physical torso exercise."""
import json
import produce as p
from prepare import IDENTITY, PLATE
out=p.SOURCE_DIR/'attack_h3_v2';assert not out.exists();out.mkdir()
c=json.loads((p.SOURCE_DIR/'attack_h3_v1/config.json').read_bytes());c['seed']=2026108322
c['prompt']=(IDENTITY+' One restrained physical swimming-body exercise. The intact torso and sealed rounded upper lip draw backward slightly while both pectoral fins fold toward the belly, then the closed rounded head and shoulder press forward SCREEN RIGHT once into the supplied forward-leaning pose. Briefly hold this maximum forward extension at guide65, then recover the torso and spread the same original fins back to exact hovering ready. The mouth remains firmly closed throughout. Only the animal body, original fins, flukes and attached bells move; the whole painted animal stays clearly visible in every frame. The background remains a completely uniform stationary solid magenta field in every frame. Ordinary physical repositioning of the same animal, fixed camera and constant body size. '+PLATE).strip()
p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());d['takes']=[t.replace('attack_h3_v1','attack_h3_v2') for t in d['takes']];p.write(p.SOURCE_DIR/'delivery.json',d)
r=json.loads((p.SOURCE_DIR/'rejected_takes.json').read_bytes());r['takes'].append(dict(take='attack_h3_v1',status='rejected_obscuring_original_effect',reviewed_original_rgb_frames=124,reviewed_rgba_frames=0,defect='Original frames1-33 invent an incoming ring and full-canvas teal flash, completely obscuring the whale at14-23. Later body motion cannot supply the missing full ready-to-windup sequence. Strict three-corner plate validation correctly stopped early. No matte relaxation, painted repair or jumped selection.',correction='Retain the same original closed-mouth physical torso guides. Describe a restrained physical body exercise and forward shoulder press, with only animal and attached bells moving on an unchanged plate.'))
p.write(p.SOURCE_DIR/'rejected_takes.json',r)
print('PHYSICAL_TORSO_CORRECTION_PREPARED',flush=True)
