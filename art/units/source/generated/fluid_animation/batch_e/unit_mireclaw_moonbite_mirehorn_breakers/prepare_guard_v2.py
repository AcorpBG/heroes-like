"""Quiet joint movement into the authentic original guard; failed v1 retained."""
import json
import produce as p
from prepare import IDENTITY
if __name__ == '__main__':
 old=p.SOURCE_DIR/'defend_h3_v1';out=p.SOURCE_DIR/'defend_h3_v2'
 assert not out.exists();out.mkdir()
 c=json.loads((old/'config.json').read_bytes());c['seed']=2026110364;c['guides']=[[62,1]]
 c['prompt']=(IDENTITY+'One slow connected weight adjustment into the supplied low posture. The four paw joints bend progressively as the shoulders settle downward and the faceplate tips forward. The handler bends both knees and lowers his torso beside the beast, retaining his left staff grip and right rein grip. The attached reed mantle, small amber glass pieces and chain links follow this ordinary body movement. Every amber glass piece keeps the same small painted appearance throughout. Complete the lowering over the first three seconds, then stay in the supplied low posture for the final two seconds. Every part of the group connects through smooth intermediate joint positions. The group remains grounded and faces screen right throughout. A single plain flat magenta RGB255,0,255 background fills the entire frame throughout. Locked camera, original artwork and scale, fixed ground reference y576. All original horns, mantle, staff, paws, feet and chains stay inside generous canvas margins.').strip()
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
 p.write(out/'correction.json',dict(rejected_take='defend_h3_v1',original_rgb_reviewed=124,partial_mattes_preserved=121,defect='Invented sparks and glows obscure equipment early; huge yellow disk grows behind the group. Strict extraction stopped121.',change='Same authentic ready/guard references, scales, anchor and quality. Positive quiet joint-motion and inert painted glass wording removes defensive/brace and negative spark/magic trigger list. One original low guide62 with original low endpoint; no gear edits or synthesized posture.',acceptance='Pending full chronological original RGB, alpha, enlarged and actual-scale both-facing review.'))
 print('PREPARED_ORIGINAL_QUIET_GUARD_V2',flush=True)
