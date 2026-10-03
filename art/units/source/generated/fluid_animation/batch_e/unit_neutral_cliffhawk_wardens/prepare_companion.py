"""Prepare original companion-only controls; no original woman/pike pixels change."""
from pathlib import Path
import json,hashlib,shutil
import numpy as np
from scipy.ndimage import label
from PIL import Image
R=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists());S=Path(__file__).parent;UID='unit_neutral_cliffhawk_wardens';B=R/'art/units/source/generated/fluid_animation/batch_c'/UID/'death_h3_v1';T=S/'companion_h3_v1';assert not T.exists();T.mkdir()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
master=S/'landing_hawk_v1.png';a=Image.open(master).convert('RGBA');box=a.getchannel('A').getbbox();assert box and a.getextrema()[3][0]==0
ink=a.crop(box);ink=ink.resize((round(ink.width*.12),round(ink.height*.12)),Image.Resampling.LANCZOS);canvas=Image.new('RGBA',(960,544));canvas.alpha_composite(ink,(825-ink.width//2,480-ink.height));canvas.save(S/'landing_hawk_canvas.png')
mid=Image.open(B/'matte/rgba_040.png').convert('RGBA');arr=np.array(mid);labs,n=label(arr[:,:,3]>=8,np.ones((3,3)));bird=labs[205,640];assert bird and bird!=labs[330,430];arr[labs!=bird]=0;cut=Image.fromarray(arr).crop((536,134,702,278));canvas=Image.new('RGBA',(960,544));canvas.alpha_composite(cut,(536+150,134+130));canvas.save(S/'airborne_mid_canvas.png')
refs=[]
for name in ['original_airborne_hawk_canvas.png','airborne_mid_canvas.png','landing_hawk_canvas.png']:
 refs.append(dict(source=(S/name).relative_to(R).as_posix(),rects=[[0,0,960,544]],anchor=[480,480],scale=.5,alpha_noise_cutoff=0))
prompt='One small natural brown-and-cream hawk from the supplied reference, alone in the elevated three-quarter orthographic fantasy strategy sprite camera, facing screen-right. One head with a dark hooked beak and natural dark eyes, cream breast, brown feathered back and exactly TWO feathered wings, one intact tail and exactly TWO natural taloned feet. Keep original painted feather markings, proportions and fixed anatomical scale. The camera is locked. Starting already airborne at the supplied first position, the hawk makes several coherent wingbeats along a gentle down-right arc within the safe interior of the canvas. It decelerates beside the supplied right-side landing position, extends both feet downward, touches down gently, folds both wings naturally and settles into the supplied standing landing pose. Every full wing, foot, beak and tail remains visible throughout, with generous margins. Never cross the top, bottom or side borders. Keep the body and head the same small size during flight and landing. Keep the landing position held quietly at the end. Uniform unchanged flat MAGENTA RGB255,0,255 background throughout; no floor, scenery, shadow, human, spear, second bird, extra limbs, armor, text, smoke, glow, sparks or magic.'
config=dict(unit_id=UID,clip='death_companion',canvas=[960,544],scale=.5,anchor=[480,480],key_rgb=[255,0,255],references=refs,last=2,guides=[[48,1]],seed=202610030936,prompt=prompt,tiled_decode=dict(tile_size=256,overlap=64,temporal_size=16,temporal_overlap=4))
(T/'config.json').write_text(json.dumps(config,indent=2)+'\n')
template=R/'art/units/source/generated/fluid_animation/batch_e/unit_thornwake_woundroot_rootmaul_behemoths'
produce=(template/'produce.py').read_text().split('\ndef build(out,c):')[0].replace('Rootmaul Behemoth','Cliffhawk companion').replace('RootmaulBehemothH3','CliffhawkCompanionH3').replace('rootmaul_behemoth','cliffhawk_companion_fix').replace('unit_thornwake_woundroot_rootmaul_behemoths','unit_neutral_cliffhawk_wardens')
produce=produce.replace("ROOT/'.artifacts/parallel_animation_20261002/unit_neutral_cliffhawk_wardens'","ROOT/'.artifacts/parallel_animation_20261002/middle53_completion_audit/cliffhawk-correction'")
(S/'produce.py').write_text(produce.rstrip()+'\n')
for name in ['stage_video.py','run_bound_actions.py']:
 text=(template/name).read_text().replace('rootmaul_behemoth','cliffhawk_companion_fix');(S/name).write_text(text.rstrip()+'\n')
shutil.copyfile(template/'matting_model.json',S/'matting_model.json')
measurement=[]
for ref in refs:
 aa=np.array(Image.open(R/ref['source']).convert('RGBA')).astype(int);opaque=aa[:,:,3]>=250;chroma=np.minimum(aa[:,:,0],aa[:,:,2])-aa[:,:,1];measurement.append(int(chroma[opaque].max()))
protected=max(24,max(measurement)+2);assert protected<175
segment=(template/'segment.py').read_text().replace('24.0',str(float(protected))).replace('protected_foreground_magenta_chroma=24',f'protected_foreground_magenta_chroma={protected}')
segment=segment.replace('max22; protected band24',f'max{max(measurement)}; protected band{protected}').replace('chroma max<=22; protected band24',f'chroma max<={max(measurement)}; protected band{protected}').replace('protected band24',f'protected band{protected}').replace('root claw/body gaps','original companion feather gaps').replace('open root limbs','original companion feather gaps').replace('green is\n # present in original leaves','green may\n # be present in original pixels').replace('never key green leaves','never key original green pixels')
(S/'segment.py').write_text(segment.rstrip()+'\n')
(T/'foreground_measurement.json').write_text(json.dumps(dict(opaque_chroma_max=measurement,protected_foreground_magenta_chroma=protected,rule='One fixed source-guide palette band for every original frame; no per-frame adjustment'),indent=2)+'\n')
(S/'landing_hawk_v1.generation.json').write_text(json.dumps(dict(tool='built-in image_gen',original_tool_output='C:/Users/acorp/.codex/generated_images/01a0fd50-f23a-7d32-8303-80fafa7a2272/exec-836031ba-b295-4269-a40e-47778fe26df2.png',master_sha256=sha(master),reference='original_airborne_hawk.png',reference_sha256=sha(S/'original_airborne_hawk.png'),generated_pose='Same hawk standing with folded wings and both feet visible',guide_crop=list(box),guide_source_scale=.12,scale_reason='Match original hawk head width about27 original video pixels, not wingspan or standing height',guide_ground=[825,480]),indent=2)+'\n')
print('COMPANION_GUIDES_PREPARED',measurement,'protected',protected,flush=True)
