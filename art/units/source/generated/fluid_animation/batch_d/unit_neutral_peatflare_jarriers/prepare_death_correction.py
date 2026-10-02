"""Prepare a grounded round-jar corpse guide for a physical collapse."""
import json
import numpy as np
from PIL import Image
import produce as p
import prepare as guides

def main():
    master=p.SOURCE_DIR/'grounded_dead_v1.png'
    prompt=master.with_suffix('.prompt.txt')
    references=[p.SOURCE_DIR/'death_h3_v1/matte/rgba_123.png',p.ROOT/'art/units/source/curated/unit_neutral_peatflare_jarriers.png']
    record=lambda path:dict(path=path.relative_to(p.ROOT).as_posix(),sha256=p.sha(path))
    p.write(master.with_suffix('.generation.json'),dict(tool='image_gen',image=record(master),prompt=record(prompt),references=[record(r) for r in references],purpose='Original corpse pose correction: compact round corked jar replaces cylindrical loose barrel; full grounded anatomy.'))
    dead=dict(name='grounded_round_jar_corpse',source=master.relative_to(p.ROOT).as_posix(),rects=[[0,0,1666,944]],anchor=[790,817],scale=.23,alpha_noise_cutoff=8)
    c=json.loads((p.SOURCE_DIR/'death_h3_v1/config.json').read_bytes())
    c.update(seed=2026100815,key_rgb=[0,255,0],references=[guides.ref(17),dead],guides=[],last=1)
    plate=' Locked elevated three-quarter orthographic camera facing screen right. Full human, hands, both boots, jars and cloak within960x544 generous margins, same anatomical size and centered root. Uniform saturated GREEN RGB0,255,0 background in EVERY frame, no floor, gradients, shadow, backdrop color changes, text, particles, magic, other people or extra props.'
    c['prompt']=(guides.IDENTITY+' One continuous physical collapse. Knees buckle, hips descend onto bent knees, torso tips sideways toward screen right, the left empty palm reaches down to brace and body rolls into supplied grounded side-prone corpse, head at screen right. Right hand holds its compact ROUND jar close against chest during descent; release only when hand reaches ground beside face so jar travels a short distance and rests on ground beside the left hand, with glow extinguished. Do not toss jar into air, do not hover or spin it above the head; jar stays round and same size throughout. Preserve exactly two original arms, two original legs and three small round belt jars. Both boots, knees, forearms, face, cloak and loose round jar finish grounded and remain still; no recovery to standing. '+plate).strip()
    out=p.SOURCE_DIR/'death_h3_v2';out.mkdir(exist_ok=True)
    assert not (out/'submission.json').exists()
    p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
    maximum=max(int((lambda a:(a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[a[:,:,3]>=245].max())(np.asarray(Image.open(out/f'guide_{i}_rgba.png').convert('RGBA')).astype(int))) for i in range(2))
    p.write(out/'extraction_settings.json',dict(protected_foreground_chroma=maximum+2,original_guide_maximum=maximum,margin=2,opaque_alpha_minimum=245))

if __name__=='__main__':main()
