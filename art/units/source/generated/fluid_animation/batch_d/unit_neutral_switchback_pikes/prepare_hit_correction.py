"""Replace the rejected generated incoming beam with a self-contained recoil."""
import json
import produce as p
from prepare import IDENTITY

out=p.SOURCE_DIR/'hit_h3_v2'
out.mkdir(exist_ok=False)
c=json.loads((p.SOURCE_DIR/'hit_h3_v1/config.json').read_bytes())
c['seed']=2026092982
c['guides']=[[32,1]]
c['prompt']=(IDENTITY+
 'The solitary actor demonstrates one quick startled flinch and recovery. '
 'Starting from the ready pose, jerk the shoulders backward, bend both knees and '
 'lean the torso back into the reference pose. The supporting glove holds the pike; '
 'the free glove opens briefly for balance. Then straighten naturally, close the '
 'free glove around the shaft and settle into the starting ready stance. '
 'This is a self-contained acting exercise performed by the one character alone. '
 'Every visible pixel belongs either to the character with his original equipment '
 'or to the uninterrupted flat saturated blue background. '
 'Locked orthographic camera, fixed body scale, boots planted at the same ground '
 'reference. Entire hat, boots and both pike ends remain inside the frame. '
 'Only his body, clothing and carried equipment move.').strip()
p.write(out/'config.json',c)
p.prepare(out,c)
p.write(out/'correction.json',dict(replaces='hit_h3_v1',
 defect='Generated incoming luminous beam and contact flash overlap the original onset at frames 19-35. Reject the full take for publication; preserve original video and provenance.',
 change='Positive solitary acting brief replaces impact/effect vocabulary; earlier recoil guide preserves onset and recovery. Same original identity and recoil references, fixed scale and canvas.'))
