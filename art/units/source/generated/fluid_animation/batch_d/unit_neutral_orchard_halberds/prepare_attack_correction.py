"""Constrain the billhook swing and recovery with a new original mid-arc guide."""
import json
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import produce as p

out=p.SOURCE_DIR/'attack_h3_v2'
out.mkdir(exist_ok=True)
c=json.loads((p.SOURCE_DIR/'attack_h3_v1/config.json').read_bytes())
c['seed']=2026092991
w,h=Image.open(p.SOURCE_DIR/'attack_midarc.png').size
c['references'].append(dict(name='billhook_midarc',source=(p.SOURCE_DIR/'attack_midarc.png').relative_to(p.ROOT).as_posix(),rects=[[0,0,w,h]],anchor=[670,964],scale=.30,alpha_noise_cutoff=8))
c['guides']=[[22,1],[42,4],[60,2],[78,3],[97,4],[114,0]]
c['prompt']=c['prompt'].replace('Perform ONE broad overhead billhook chop toward screen right.', 'Perform ONE controlled overhead billhook chop toward screen right, followed by an unhurried return to ready. Move at a steady slow rate between the supplied phase guides without pausing and snapping.')+' The entire swing stays PARALLEL TO THE IMAGE PLANE. The blade never travels toward the camera. The small dull silver curved blade stays the same size as the head, never a giant axe or gold paddle. The long straight wood shaft remains rigid and visible from its metal butt through the right-hand grip to the single blade. Follow the horizontal intermediate guide during both the downward chop and upward recovery. No weapon-size change, perspective enlargement, blurred duplicated weapons or detached fragments.'
p.write(p.SOURCE_DIR/'attack_h3_v1/rejection.json',dict(status='rejected',defects=['Blade grows into an oversized gold paddle in original frames 43-45 and 90-91 during swing/recovery.'],correction='A new original horizontal mid-arc guide constrains both intervals; more evenly spaced phase guides and parallel-plane motion prompt. Original take retained; no frame deletion to disguise the failed transition.'))
p.write(p.SOURCE_DIR/'attack_midarc.generation.json',dict(tool='image_gen.imagegen',image=dict(path=(p.SOURCE_DIR/'attack_midarc.png').relative_to(p.ROOT).as_posix(),sha256=p.sha(p.SOURCE_DIR/'attack_midarc.png')),prompt=dict(path=(p.SOURCE_DIR/'attack_midarc.prompt.txt').relative_to(p.ROOT).as_posix(),sha256=p.sha(p.SOURCE_DIR/'attack_midarc.prompt.txt')),references=[dict(path=(p.SOURCE_DIR/'attack_h3_v1'/f'guide_{i}_chroma.png').relative_to(p.ROOT).as_posix(),sha256=p.sha(p.SOURCE_DIR/'attack_h3_v1'/f'guide_{i}_chroma.png')) for i in [0,1]],original_tool_path='C:/Users/acorp/.codex/generated_images/01a0965d-a98e-7560-8e9d-802269b3760b/exec-5ede0f24-6c82-4e1a-ae3b-a44c7380d312.png',scale_reason='One .30 source scale matches the new 610-pixel adult body to the original roughly 365-pixel body at .50 extraction scale. Ground contact 964, body root 670. No generated video frame normalization.'))
p.prepare(out,c)
bands=[]
for i in range(len(c['references'])):
 a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float)
 opaque=binary_erosion(a[:,:,3]>240,iterations=3)
 bands.append(float((a[:,:,2]-np.maximum(a[:,:,0],a[:,:,1]))[opaque].max()))
c['protected_foreground_chroma']=max(bands)+2
c['foreground_measurement']=dict(rule='Maximum blue-minus-max(red,green) over alpha>240 opaque interiors eroded three pixels, plus two levels.',per_guide_max=bands)
p.write(out/'config.json',c)
p.verify(out,c)
print('Prepared',out.name,c['protected_foreground_chroma'])
