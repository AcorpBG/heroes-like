"""Correct loose-jar hallucination by retaining a visible chest grip."""
import json
import numpy as np
from PIL import Image
import produce as p
import prepare as guides

def main():
    master=p.SOURCE_DIR/'gripped_dead_v1.png';prompt=master.with_suffix('.prompt.txt')
    record=lambda path:dict(path=path.relative_to(p.ROOT).as_posix(),sha256=p.sha(path))
    p.write(master.with_suffix('.generation.json'),dict(tool='image_gen',image=record(master),prompt=record(prompt),references=[record(p.SOURCE_DIR/'grounded_dead_v1.png')],purpose='Original corpse guide retains the round jar in original right hand against chest; left hand empty and grounded.'))
    im=Image.open(master).convert('RGBA');bounds=im.getchannel('A').point(lambda a:255 if a>=128 else 0).getbbox()
    dead=dict(name='gripped_round_jar_corpse',source=master.relative_to(p.ROOT).as_posix(),rects=[[0,0,*im.size]],anchor=[800,bounds[3]],scale=.18,alpha_noise_cutoff=8)
    c=json.loads((p.SOURCE_DIR/'death_h3_v2/config.json').read_bytes())
    c.update(seed=2026100816,references=[guides.ref(17),guides.ref(14),dead],guides=[[30,1],[65,2]],last=2)
    c['prompt']=(guides.IDENTITY+' One continuous physical knee buckle and side collapse. Maintain original RIGHT hand wrapped securely around the compact round corked jar from first frame through final corpse. Bend knees and descend into kneel, hips lower, torso tips toward screen right, LEFT empty hand reaches ground to brace and body rolls into supplied side-prone corpse with head at screen right. RIGHT hand brings the same original round jar against CHEST and KEEPS HOLDING it with fingers wrapped around jar through final frame. Three original belt jars remain attached. Both knees, boots, forearms, face and cloak finish grounded. Preserve exactly two arms, hands and legs. Original jar remains gripped against chest: never release, toss, float or fly any jar, no loose objects anywhere, no changing jar shape or size. End still and grounded; no standing recovery. Locked elevated three-quarter orthographic camera, unchanged anatomical body size and fixed root. Whole creature fully within960x544 generous margins. Uniform GREEN RGB0,255,0 background in every frame, no floor, shadows, gradients, background color changes, effects, other people or text.').strip()
    out=p.SOURCE_DIR/'death_h3_v3';out.mkdir(exist_ok=True);assert not (out/'submission.json').exists()
    p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
    maximum=max(int((lambda a:(a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[a[:,:,3]>=245].max())(np.asarray(Image.open(out/f'guide_{i}_rgba.png').convert('RGBA')).astype(int))) for i in range(3))
    p.write(out/'extraction_settings.json',dict(protected_foreground_chroma=maximum+2,original_guide_maximum=maximum,margin=2,opaque_alpha_minimum=245))

if __name__=='__main__':main()
