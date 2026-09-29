"""Pin the reviewed original raised-pike pose on one consistent blue plate."""
import json
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion
import produce as p
from prepare import IDENTITY

out=p.SOURCE_DIR/'cast_h3_v3';out.mkdir(exist_ok=False)
c=json.loads((p.SOURCE_DIR/'cast_h3_v1/config.json').read_bytes())
c['seed']=2026092985
raised=p.SOURCE_DIR/'cast_h3_v2/matte/rgba_060.png'
c['references'].append(dict(name='original_h3_support_peak_60',source=raised.relative_to(p.ROOT).as_posix(),rects=[[0,0,960,640]],anchor=[420,560],scale=.5,alpha_noise_cutoff=0))
c['guides']=[[40,1],[80,1]]
c['prompt']=(IDENTITY+
 'Perform one deliberate two-handed readiness salute. Both boots stay planted. '
 'Raise the pike from its diagonal carry up to the supplied shoulder-height '
 'reference, nod once, hold briefly, then lower it back to the starting carry. '
 'The large spearhead stays on the left and the small butt spike on the right. '
 'Both gloves keep the same shaft grips throughout. '
 'Uniform bright saturated BLUE fills every background pixel and every gap '
 'between the arms and weapon, exactly matching all supplied reference images '
 'throughout the entire clip. Constant lighting and unchanging blue background. '
 'Locked orthographic camera and fixed adult proportions. Entire pike and boots '
 'remain visible. A physical readiness gesture by this solitary actor.').strip()
p.prepare(out,c)
bands=[]
for i in range(len(c['references'])):
 a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3)
 bands.append(float((a[:,:,2]-np.maximum(a[:,:,0],a[:,:,1]))[mask].max()))
c['protected_foreground_chroma']=max(0,int(max(bands))+2)
c['foreground_measurement']=dict(rule='Eroded opaque blue minus max(red,green) maximum plus two.',per_guide_max=bands)
p.write(out/'config.json',c)
p.write(out/'correction.json',dict(replaces='cast_h3_v2',
 defect='Yellow interval has a mixed magenta/yellow region inside the arm gap; whole-take publication rejected instead of cutting away the rise gesture.',
 change='Second targeted correction changes control: pin an actually reviewed original raised-pike frame at 40 and 80 on the same blue plate as the original ready guide.',
 raised_guide=dict(source=raised.relative_to(p.ROOT).as_posix(),sha256=p.sha(raised),original_video='cast_h3_v2/original_lossless.mkv',video_frame=60,extraction='cast_h3_v2/extraction_settings.json')))
