"""Inspect/pack source crops only; no painting, generated motion, or frame synthesis."""
from pathlib import Path
import hashlib, json
from PIL import Image

ROOT = Path(__file__).resolve().parents[7]
HERE = Path(__file__).resolve().parent
source = HERE / 'idle_v1.png'
prompt = HERE / 'idle_v1.prompt.txt'
reference = ROOT / 'art/units/source/generated/town_upgrades/faction_embercourt/unit_river_guard_veteran_idle.png'
rel = lambda p: p.relative_to(ROOT).as_posix()
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
im = Image.open(source).convert('RGBA')
frames, images = [], []
for i in range(4):
    x, y = i % 4 * 384, i // 4 * 512
    rect = [x, y, x + 384, y + 512]
    frames.append({'name': f'idle_{i:02d}', 'clip':'idle', 'source':rel(source), 'rects':[rect], 'anchor':[x+207,y+490], 'scale':0.5})
    frame = im.crop(rect)
    frame.putalpha(frame.getchannel('A').point(lambda p: 0 if p <= 8 else p))
    canvas=Image.new('RGBA',(256,256))
    canvas.alpha_composite(frame.resize((192,256),Image.Resampling.LANCZOS),(24,0))
    images.append(canvas)
ret_source=HERE/'idle_return_v1.png'
ret=Image.open(ret_source).convert('RGBA')
for i in range(4):
    x,y=i%2*627,i//2*627
    anchor=[375 if i%2==0 else 925,610 if i<2 else 1231]
    rect=[x,y,x+627,y+627]
    frames.append({'name':f'idle_{i+4:02d}', 'clip':'idle','source':rel(ret_source),'rects':[rect],'anchor':anchor,'scale':0.4})
    frame=ret.crop(rect)
    frame.putalpha(frame.getchannel('A').point(lambda p:0 if p<=8 else p))
    frame=frame.resize((251,251),Image.Resampling.LANCZOS)
    canvas=Image.new('RGBA',(256,256))
    canvas.alpha_composite(frame,(round(127.5-(anchor[0]-x)*0.4),round(245-(anchor[1]-y)*0.4)))
    images.append(canvas)
unit = {'unit_id':'unit_river_guard_veteran', 'reference_height':256, 'source_facing':'right', 'frames':frames, 'alpha_noise_cutoff':8, 'clips':{'idle':{'indices':list(range(8)), 'frame_msec':140, 'loop':True, 'static_frame':0}}, 'accepted_clips':[], 'preserve_clips':[], 'visual_review':{'status':'pending', 'notes':'First4 original ascending poses followed by4 separately generated descending inbetweens; source sizes normalized by bodyreference and anatomicalground anchors. Root motion review required; observe any proportions drift at cross-sheet transition.'}}
unit['source_scale_by_image']={rel(source):0.5,rel(ret_source):0.4}
unit['source_scale_reason']='Original canvas resolutions differ: 1536x1024 4x2 sheet has 486px standing spear-to-sole reference;1254x1254 2x2 sheet has608px. Source-wide0.5/0.4 scales both to244px standing reference. No pose-specific bounding-box rescaling.'
(HERE/'handoff.json').write_text(json.dumps({'schema_version':1,'units':[unit]},indent=2)+'\n',encoding='utf8')
(HERE/'idle_v1.provenance.json').write_text(json.dumps({'generator':'built-in image_gen', 'source':rel(source), 'source_sha256':sha(source), 'prompt':rel(prompt),'prompt_sha256':sha(prompt), 'references':[{'path':rel(reference),'sha256':sha(reference),'role':'top-left stance identity and design'}], 'generation_output':'C:/Users/acorp/.codex/generated_images/01a0ccb1-654e-7aa2-af06-8bdc2dae09d2/exec-d99b7912-8c12-4ca8-b7b9-ebe30de648d8.png', 'review_status':'pending'},indent=2)+'\n',encoding='utf8')
for stem,output,refs,status in [('idle_v2','exec-e8d9f2ce-229e-4bbd-baad-701a4af81a21.png',[source],'rejected_abrupt_return'),('idle_return_v1','exec-a378f1c7-8da2-422b-9b9a-ddb1a0240028.png',[HERE/'reference_raised.png',HERE/'reference_neutral.png'],'pending')]:
    (HERE/f'{stem}.provenance.json').write_text(json.dumps({'generator':'built-in image_gen','source':rel(HERE/f'{stem}.png'),'source_sha256':sha(HERE/f'{stem}.png'),'prompt':rel(HERE/f'{stem}.prompt.txt'),'prompt_sha256':sha(HERE/f'{stem}.prompt.txt'),'references':[{'path':rel(p),'sha256':sha(p),'derived_from':rel(source)} for p in refs],'generation_output':'C:/Users/acorp/.codex/generated_images/01a0ccb1-654e-7aa2-af06-8bdc2dae09d2/'+output,'review_status':status},indent=2)+'\n',encoding='utf8')
images[0].save(HERE/'idle_preview.webp',save_all=True,append_images=images[1:],duration=140,loop=0,lossless=True)
contact=Image.new('RGBA',(256*4,256*2))
for i,frame in enumerate(images): contact.alpha_composite(frame,(i%4*256,i//4*256))
contact.save(HERE/'idle_preview.png')
print(rel(HERE/'handoff.json'))
