"""Unsubmitted recoil source wording uses physical balance, avoiding v1 ram FX trigger."""
import json,shutil
import produce as p
from prepare import IDENTITY,PLATE
out=p.SOURCE_DIR/'hit_h3_v1';assert not (out/'sampling_submission.json').exists()
if not (out/'config_pre_quiet_wording.json').exists():
 shutil.copyfile(out/'config.json',out/'config_pre_quiet_wording.json');shutil.copyfile(out/'prompt.txt',out/'prompt_pre_quiet_wording.txt')
c=json.loads((out/'config.json').read_bytes());c['prompt']=(IDENTITY+'One short balance correction and recovery in empty air. Intact head and shoulders lean backward into the supplied original posture as the four paw joints bend and redistribute weight. The small handler leans back one step then steadies himself, left staff hand and right rein hand never release. Both figures remain screen-right at original grounded support height. Then lower head and return smoothly to exact ready. Only ordinary body and cloth motion; nothing touches either figure. Original amber lights remain small and enclosed inside their original glass lanterns. No fall, turn, leap, emission or new appendage. '+PLATE).strip()
p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
p.write(out/'source_wording_revision.json',dict(status='unsubmitted_preparation_change',reason='First original ram take invented a collision starburst. Remove impact wording from still-unsubmitted recoil, retaining original ready/recoil guides, seed and every H3 quality/model setting. Original unsubmitted config/prompt retained separately.'))
print('ORIGINAL_RECOIL_GUIDES_QUIET_WORDING_VERIFIED',flush=True)
