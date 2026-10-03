"""Preserve endpoint-key correction lineage; one anatomical scale per original."""
from PIL import Image
import produce as p
O=p.SOURCE_DIR;R=p.ROOT
def rec(path):return dict(path=path.relative_to(R).as_posix(),sha256=p.sha(path))
for version,status,refs in [(1,'rejected original endpoint: valve restored but third pressure bulb/gauge not visibly retained',[O/'death_legacy_endpoint_reference.png',O/'move_h3_v1/guide_0_rgba.png']),(2,'accepted original endpoint: all FOUR folded rock legs, THREE cold attached pressure bulbs/gauges and ONE original red valve tail visible on ground; full original reviewed, prepared native guide pending',[O/'death_key_original_v1.png',R/'art/units/source/curated/unit_neutral_gaugecoil_orewyrms.png'])]:
 image=O/f'death_key_original_v{version}.png';im=Image.open(image).convert('RGBA');assert im.getchannel('A').getextrema()==(0,255)
 p.write(image.with_suffix('.generation.json'),dict(tool='built_in_imagegen',model='not exposed',date='2026-10-03',image=rec(image),prompt=rec(O/f'death_key_prompt_v{version}.txt'),references=[rec(ref) for ref in refs],review_status=status))
 print('ORIGINAL_DEATH_KEY_RGBA',version,im.size,im.getbbox(),flush=True)
im=Image.open(O/'death_key_original_v2.png')
p.write(O/'death_reference.json',dict(name='dead_repaired',source=(O/'death_key_original_v2.png').relative_to(R).as_posix(),rects=[[0,0,*im.size]],anchor=[904,793],scale=.27,alpha_noise_cutoff=8,registration_reason='One entire new original endpoint at0.27 runtime scale; match unchanged drill-jaw/body anatomical size and place lowest grounded folded-leg/jaw pixels at ground. No aspect warping or per-frame normalization.'))
