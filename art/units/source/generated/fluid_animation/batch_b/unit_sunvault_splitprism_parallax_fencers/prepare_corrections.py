"""Targeted Parallax Fencers corrections for rejected support and death takes, preserving rejects."""
import json
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import produce as p
from prepare_h3 import ref, IDENTITY, UID

STATIC_PLATE = (' Locked elevated three-quarter orthographic camera at the reference angle, fixed anatomical scale and centered root. '
 'The entire fencer and both blades stay visible. Uniform pure saturated green RGB0,255,0 background in every frame. '
 'Keep this green plate completely static from first to last frame: it never changes color, flashes or darkens, and no light is cast on the fencer. '
 'Continuous physical joints, stable grips and stable material colors. No glow bursts, trails, sparks or magic effects.')

def make(name, indices, guides, last, action, seed):
    out = p.SOURCE_DIR/name
    out.mkdir(exist_ok=False)
    c = dict(unit_id=UID, clip=name.split('_')[0], canvas=[960,640], anchor=[470,560], scale=.5,
             key_rgb=[0,255,0], seed=seed, references=[ref(i) for i in indices], guides=guides, last=last,
             prompt=(IDENTITY+action+STATIC_PLATE).strip(),
             tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
    p.prepare(out, c)
    bands = []
    for i in range(len(indices)):
        a = np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float)
        mask = binary_erosion(a[:,:,3]>240, iterations=3)
        bands.append(float((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[mask].max()))
    c['protected_foreground_chroma'] = max(0, int(max(bands))+2)
    c['foreground_measurement'] = dict(rule='Eroded opaque green-minus-max(red,blue) maximum plus two across original guides.', per_guide_max=bands)
    p.write(out/'config.json', c)

if __name__ == '__main__':
    make('cast_h3_v2', [14,17], [[34,1],[58,1]], 0,
         'Perform a crisp duelist salute to encourage allies. Slowly bend the sword elbow and raise the crystal sword so its gold guard comes up before the chest '
         'and the blade points upward, as in the middle reference, nod once and hold the salute briefly, then deliberately lower the blade forward '
         'and down back to the starting ready stance. The rear hand keeps gripping the same golden dagger, visible and pointing down and back in every frame. '
         'Both boots stay planted. A nonmagical physical gesture with clear elbow and wrist motion during both raise and return.', 2026100150)
    make('death_h3_v2', [14,11,12,13], [[30,1],[80,2]], 3,
         'Collapse continuously, with no pause and no sudden jumps. The knees buckle and she sinks onto one knee with the head bowed and the sword tip lowering, '
         'as in the first middle reference. Without stopping, her torso keeps tipping sideways toward screen right; the forward hand and crystal sword reach down '
         'to the ground, then the hip and shoulder lower gradually until she rests on her side as in the second middle reference. Finally she settles flat, '
         'motionless, in the supplied final corpse pose with the head toward screen right. The crystal sword lies beside her forward hand and the golden dagger '
         'beside her rear hand; exactly two blades remain. Body, sash and both blades stay attached and visible throughout.', 2026100151)
    d = json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
    d['takes'] = [t.replace('cast_h3_v1','cast_h3_v2').replace('death_h3_v1','death_h3_v2') for t in d['takes']]
    d['rejected_takes'] = {
        'cast_h3_v1': 'All124 raw originals reviewed: backdrop cycles between green and red from frame16 onward, so no reproducible matte; the rear-hand golden dagger also disappears during the raised salute. Rejected; regenerate with static-plate wording and explicit dagger retention.',
        'death_h3_v1': 'All124 chronological frames reviewed: knee drop 24-28 is a three-frame smear, and kneel-to-prone 65-67 is a two-frame teleport at the fall guide instead of a continuous topple. Rejected; regenerate with earlier kneel guide, later side-rest guide and continuous-topple wording.'}
    for take, reason in d['rejected_takes'].items():
        p.write(p.SOURCE_DIR/take/'rejection.json', dict(status='rejected', reason=reason))
    p.write(p.SOURCE_DIR/'delivery.json', d)
