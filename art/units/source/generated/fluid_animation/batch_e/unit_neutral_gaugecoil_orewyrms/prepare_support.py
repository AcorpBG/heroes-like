"""Preserve a new original physical support key; one whole-reference scale."""
from PIL import Image
import produce as p
O=p.SOURCE_DIR;R=p.ROOT
master=O/'support_original_v1.png';im=Image.open(master).convert('RGBA');assert im.getchannel('A').getextrema()==(0,255)
print('ORIGINAL_SUPPORT_RGBA',im.size,im.getbbox(),flush=True)
ref=dict(name='support_signal',source=master.relative_to(R).as_posix(),rects=[[0,0,*im.size]],anchor=[890,760],scale=.26,alpha_noise_cutoff=8)
p.write(O/'support_reference.json',ref)
def record(path):return dict(path=path.relative_to(R).as_posix(),sha256=p.sha(path))
p.write(master.with_suffix('.generation.json'),dict(tool='built_in_imagegen',model='not exposed',date='2026-10-03',image=record(master),prompt=record(O/'support_prompt_v1.txt'),references=[record(O/'move_h3_v1/guide_0_rgba.png')],review_status='pending complete prepared guide/native review',reference_scale_reason='One entire painted key at0.26 runtime scale, fixed ground anchor; no aspect warping, manual limb edits or per-frame normalization.'))
