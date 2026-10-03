"""Source-backed quiet horn-lowering correction after invented starburst in v1."""
import json
import produce as p
from prepare import IDENTITY,PLATE,reference
out=p.SOURCE_DIR/'attack_h3_v2';assert not (out/'sampling_submission.json').exists();out.mkdir(exist_ok=True)
c=json.loads((p.SOURCE_DIR/'attack_h3_v1/config.json').read_bytes())
c.update(seed=2026110342,references=[reference(i) for i in [11,4,5]],guides=[[16,1],[32,1],[48,2],[62,2],[76,1],[100,0]],last=0,prompt=IDENTITY+'One calm controlled forward weight shift on empty air. Slowly lower the intact horned head and bend the four paw joints into the supplied forward posture, lean shoulders forward once with both horns plainly visible, then lift the intact head and straighten back to the exact original ready. The small handler leans back to keep the rein taut, left hand keeps the staff and both feet keep support. The backdrop is empty; nothing touches the horns. Only the group moves; all original amber light stays inside the original attached glass lanterns. Every transition shows the complete faceplate, both horn outlines, all four original paws and both handler grips. '+PLATE)
c['prompt']=c['prompt'].strip()
p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
p.write(out/'correction.json',dict(rejected_source='attack_h3_v1',failure='Invented original-RGB yellow starburst obscures horns/head around41-56; full124 originals inspected and preserved. Not an alpha-only issue; no plate-validation relaxation, anatomy repainting or erasure.',control_change='Empty-air forward weight-shift wording removes collision trigger and6 dense original guide positions replace2 sparse intermediates; same anatomical references, models/quality settings/resolution/extraction scale.',guide_source_indices=[11,4,5]))
print('QUIET_ORIGINAL_GUIDED_RAM_V2_PREPARED',flush=True)
