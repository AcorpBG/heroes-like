"""CPU preparation of separately preserved physical-mechanism corrections."""
import json,shutil
from pathlib import Path
import numpy as np
from PIL import Image
import produce as p
S=p.SOURCE_DIR
def write(path,v):path.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
generated=Path('C:/Users/acorp/.codex/generated_images/01a0fd4a-b27e-7940-b631-3e2e6a3966f3/exec-7b56ab1c-cb27-48a4-9468-acef39e22bce.png')
guide=S/'melee_shove_repaired_original.png'
if not guide.exists():shutil.copyfile(generated,guide)
rgb=Image.open(guide).convert('RGB');assert rgb.size==(1666,944),rgb.size
rgba,recipe=p.key(rgb,dict(key_rgb=[255,0,255],protected_foreground_chroma=29))
rgba.save(S/'melee_shove_repaired_alpha.png')
write(S/'melee_guide_repair.json',dict(tool='Built-in imagegen',edit_target='attack_h3_v1/guide_2_chroma.png',edit_target_sha256=p.sha(S/'attack_h3_v1/guide_2_chroma.png'),original_sha256=p.sha(guide),alpha_sha256=p.sha(S/'melee_shove_repaired_alpha.png'),prompt_file='melee_guide_repair_prompt.txt',recipe=recipe,source_size=[1666,944],source_anchor=[833,820],source_scale=.5*960/1666,note='Uniform source-size conversion and original painted front-middle toe ground y820; no per-frame normalization. Camera and six-leg machine/single operator retained; joint-supported forward-load peak repaired because inherited peak was close to ready.'))
identity=('One original ivory/brass/black six-legged mechanical walker and exactly ONE white-coated human operator at rear viewer-RIGHT, matching these supplied paintings. Three near ivory leg chains and three far dark leg chains with original hinge/ankle/three-toed feet. One rigid long black/brass cylindrical assembly in fixed ivory sleeve, same round opening/rings/diameter; original boiler, TWO white gauges, red wheels/hoses, ONE tall chimney, contained orange apertures. Operator original helmet, orange goggles, split coat, exactly two arms/hands/legs/boots. Same original anatomical and mechanical size. Fixed three-quarter camera, cylinder points SCREEN LEFT, centered ground registration. ')
plate=(' The orange light remains steadily INSIDE the circular opening and furnace hardware. The surrounding magenta background is perfectly flat and uninterrupted on every frame, including all space immediately in front of the cylinder opening. Only original solid mechanisms and operator joints move. No added geometry, new limbs/crew, external lights, vapor, effects, scenery, text, shadows, cuts, zoom, camera changes or size changes. Entire original silhouette remains inside canvas. ')
for name,old,seed in [('attack_h3_v2','attack_h3_v1',2026110601),('ranged_h3_v3','ranged_h3_v2',2026110602)]:
 out=S/name;out.mkdir(exist_ok=True);assert not (out/'sampling_submission.json').exists()
 c=json.loads((S/old/'config.json').read_bytes());c['seed']=seed
 if c['clip']=='attack':
  c['references'][2]=dict(name='repaired_joint_loaded_shove',source=(S/'melee_shove_repaired_alpha.png').relative_to(p.ROOT).as_posix(),rects=[[0,0,1666,944]],anchor=[833,820],scale=.5*960/1666,alpha_noise_cutoff=8)
  c['guides']=[[18,0],[38,1],[62,2],[76,2],[103,0],[115,0]]
  beat=('One deliberate supported forward PUSH and reset: ready0..18;18..38 pull elbows back and bend knees to load the original rear joints;38..62 extend rear joints while front knees bend, driving the original rigid cylinder/boiler/body forward and down into the supplied peak pose;62..76 hold brief strongest physical pressure;76..103 unload and bring joints, elbows and knees back to ready;103..123 hold. Operator spreads two real boots and drives with BOTH hands continuously gripping original control bar. Clear physical shove through original joints, with at least three mechanical feet supporting every phase. Original rigid cylinder length and diameter unchanged throughout. ')
 else:
  c['guides']=[[18,0],[38,1],[48,2],[62,2],[74,0],[82,0],[108,0]]
  beat=('One physical spring-and-piston compression stroke and reset controlled by the original operator:0..18 ready;18..38 slightly elevate the original cylindrical assembly and brace six legs;38..48 operator presses the existing control bar, bends elbows/knees while the SAME inner cylinder slides BACK one third inside the fixed ivory sleeve;48..62 briefly holds the original compressed piston;62..74 the same original piston releases gradually to its exact original first-frame length;74..123 hold ready. The circular opening diameter and original metal rings stay constant; maximum exposed inner-cylinder length equals the first supplied guide at all times, never farther. Both real hands remain on original control bar. A single supported backward compression and full recovery, with readable original piston travel and operator elbow/knee reaction. ')
 c['prompt']=(identity+beat+plate).strip()
 write(out/'config.json',c);p.prepare(out,c)
 write(out/'correction.json',dict(replaces=old,change='Different physical-mechanism vocabulary and explicit motion beats; unchanged H3 quality/models. '+('Original deficient peak repaired through built-in imagegen; no video warp.' if c['clip']=='attack' else 'Original guide pixels unchanged; removes all positive combat/firing vocabulary that preceded two unwanted beams.')))
for take,note in [('attack_h3_v1','Unwanted exterior shot at26..29. Later34..95 intact but physical shove too weak; inherited peak guide too close to ready. Full original retained, no accepted frames.'),('ranged_h3_v2','Barrel growth repaired but two unwanted exterior beams at36..39 and68..71 with muzzle-edge alpha loss. No accepted frame selection; cannot crop effects touching equipment or erase them.')]:
 write(S/take/'review_failure.json',dict(status='rejected',review='All124 original RGB and alpha frames viewed chronologically; enlarged action/effect poses on light/dark backgrounds.',defect=note))
d=json.loads((S/'delivery.json').read_bytes());d['takes']=[t.replace('attack_h3_v1','attack_h3_v2').replace('ranged_h3_v2','ranged_h3_v3') for t in d['takes']];d['failed_takes']=['attack_h3_v1','ranged_h3_v1','ranged_h3_v2'];write(S/'delivery.json',d)
m=json.loads((S/'foreground_measurement.json').read_bytes())
for take in ['attack_h3_v2','ranged_h3_v3']:
 for path in (S/take).glob('guide_*_rgba.png'):
  a=np.asarray(Image.open(path).convert('RGBA')).astype(np.int16);colors=a[:,:,:3][a[:,:,3]>=240];R,G,B=colors.T;bands=dict(magenta=np.minimum(R,B)-G,green=G-np.maximum(R,B),blue=B-np.maximum(R,G),cyan=np.minimum(G,B)-R)
  m['guides'].append(dict(path=path.relative_to(p.ROOT).as_posix(),sha256=p.sha(path),opaque_pixels=len(colors),maximum={k:int(v.max()) for k,v in bands.items()},percentile999={k:round(float(np.percentile(v,99.9)),3) for k,v in bands.items()}))
m['protected_bands']={k:max(r['maximum'][k] for r in m['guides'])+2 for k in m['protected_bands']};write(S/'foreground_measurement.json',m)
print('PREPARED_REPAIRED_MELEE_AND_PHYSICAL_PISTON',m['protected_bands'],flush=True)

