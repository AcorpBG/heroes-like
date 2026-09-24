"""Original-guide H3 reciprocal walk for Prism Harrier; publication is explicit."""
import argparse
import hashlib
import json
import sys
import time
import urllib.request
from pathlib import Path

import av
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import label

ROOT = next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT/'tools'))
from trial_video_creature_animation import collect, request, status, node, write
from integrate_fluid_creature_animation import source_pose
from publish_fluid_creature_animation import combine

UNIT = 'unit_prism_adept'
URL = 'http://127.0.0.1:8189'
ANCHOR = [480, 475]
INPUT_SCALE = .95
RUNTIME_SCALE = .6 / INPUT_SCALE
PROMPT = 'Locked orthographic three-quarter RIGHT-facing fantasy strategy sprite camera. This exact Prism Harrier, a young adult female fantasy crossbow soldier with ivory hood and blue lining, long dark hair, face looking RIGHT, gold-edged white and royal blue split tabard with gold sun star, dark leggings, two gold boots, gold/blue gloves, iridescent blue-gold crystal shoulder plates, crystal bolt pouch at her image-left hip. Exactly two arms, two hands and two legs. ONE rigid elaborate gold/blue crystal CROSSBOW held diagonally across her waist pointed toward image-right, trigger hand at image-left side of her chest and support hand beneath the forward stock. Keep original stock length, curved bow limbs, thin bowstring, central blue gem and crystal muzzle; no additional weapons, shield, staff, bolts, particles or flashes. One continuous non-graphic defeat and collapse from the supplied upright ready pose to the supplied fully grounded side-lying corpse. Slow heavy continuous physical fall over first THREE seconds. Ready to kneeling at frame34, roll down to supplied corpse by frame72, then rest. Brief recoil and loss of balance, BOTH knees bend and buckle, torso lowers naturally, one knee reaches ground, body tips down onto her side, shoulder then head settle onto folded arm, both legs come to rest sideways as in final guide. Keep head/torso size unchanged through fall. Crossbow is ONE rigid object retained by the same two hands as they lower it together; bow comes to rest flat on ground in front of body, never upright or floating. Cloth folds under body. Eyes close and face becomes motionless. All materials stay FULLY OPAQUE AND SHARP THROUGH EVERY FRAME including crossbow panels and solid gold bow limbs; NO ghosting, dissolves, transparency, motion smears, morphing or crossfades. Hands physically lower and rotate the crossbow together with the falling torso, never release it or drag it separately afterward. Bow is already resting in front when shoulder/head touch ground. No getting back up, fading, disappearing, dismemberment, blood, stretching anatomy, extra limbs or equipment duplication. Preserve intended local fall and grounded contact. Begin fall promptly; complete by final quarter and remain completely motionless at terminal corpse. No camera movement, zoom or perspective changes. Entire hood, both boots and complete weapon visible with generous margins. Background perfectly uniform PURE GREEN RGB(0,255,0), no floor, shadows, gradients, text or scenery.'


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def prepare():
    if (OUT/'submission.json').exists():
        raise RuntimeError('Never overwrite a submitted original')
    recipe = json.loads((ROOT/'art/animation/source/fluid/unit_prism_adept/reviewed_handoff.json').read_bytes())['units'][0]
    contacts = [recipe['frames'][0].copy(),dict(name='grounded_corpse',clip='death',source='art/units/source/generated/fluid_animation/batch_b/unit_prism_adept/death_v2.png',rects=[[570,1130,1136,1385]],anchor=[850,1332],scale=.54,alpha_noise_cutoff=8),dict(name='kneeling_support',clip='death',source='art/units/source/generated/fluid_animation/batch_b/unit_prism_adept/death_v2.png',rects=[[0,490,565,830]],anchor=[290,804],scale=.54,alpha_noise_cutoff=8)]
    refs = []
    for original,filename in zip(contacts,['input_green.png','corpse_green.png','kneel_green.png']):
        frame = original.copy()
        original_scale = frame['scale']
        assert original_scale in [.6,.54]
        frame['scale'] = original_scale / RUNTIME_SCALE
        subject,(x,y) = source_pose(frame)
        transparent = Image.new('RGBA',(960,544))
        transparent.alpha_composite(subject,(ANCHOR[0]+x,ANCHOR[1]+y))
        transparent.save(OUT/filename.replace('_green','_rgba'))
        canvas = Image.new('RGBA',(960,544),(0,255,0,255))
        canvas.alpha_composite(transparent);canvas.convert('RGB').save(OUT/filename)
        refs.append(dict(source_frame=frame,source_sha256=sha(ROOT/frame['source']),input_file=filename,input_sha256=sha(OUT/filename),runtime_source_scale=original_scale))
    write(OUT/'reference.json',dict(unit_id=UNIT,guides=refs,canvas=[960,544],ground_anchor=ANCHOR,input_source_scale=INPUT_SCALE,output_scale=RUNTIME_SCALE))
    row = next(r for r in json.loads((ROOT/'content/unit_animation_manifest.json').read_text(encoding='utf-8'))['items'] if r['id']==UNIT)
    write(OUT/'accepted_baseline.json',row)
    (OUT/'prompt.txt').write_text(PROMPT+'\n',encoding='utf-8')
    graph = {
        '1':node('UNETLoader',unet_name='minimax_h3_fl2va_pruned_int8_convrot.safetensors',weight_dtype='default'),
        '2':node('CLIPLoader',clip_name='qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors',type='minimax',device='default'),
        '3':node('VAELoader',vae_name='minimax_h3_video_vae_int8_convrot.safetensors'),
        '4':node('LoadImage',image='prism_adept_death_input.png'),
        '5':node('MiniMaxH3ImageToVideo',clip=['2',0],vae=['3',0],prompt=PROMPT,width=960,height=544,length=124,first_frame=['4',0],last_frame=['16',0]),
        '16':node('LoadImage',image='prism_adept_corpse.png'),
        '17':node('LoadImage',image='prism_adept_kneel.png'),
        '18':node('MiniMaxH3AddGuide',positive=['5',0],latent=['5',1],frame_idx=34,vae=['3',0],image=['17',0]),
        '19':node('MiniMaxH3AddGuide',positive=['18',0],latent=['5',1],frame_idx=72,vae=['3',0],image=['16',0]),
        '6':node('BasicGuider',model=['1',0],conditioning=['19',0]),
        '7':node('RandomNoise',noise_seed=2026092435),
        '8':node('KSamplerSelect',sampler_name='res_multistep'),
        '9':node('BasicScheduler',model=['1',0],scheduler='simple',steps=20,denoise=1.0),
        '10':node('SamplerCustomAdvanced',noise=['7',0],guider=['6',0],sampler=['8',0],sigmas=['9',0],latent_image=['5',1]),
        '11':node('VAEDecode',samples=['10',0],vae=['3',0]),
        '13':node('CreateVideo',images=['11',0],fps=24,bit_depth=8),
        '14':node('SaveVideo',video=['13',0],filename_prefix='prism_adept_h3/death_guided_v2/original',**{'format':'mp4','format.codec':'h264'}),
        '15':node('SaveImage',images=['11',0],filename_prefix='prism_adept_h3/death_guided_v2/frames/decoded'),
    }
    write(OUT/'workflow_api.json',graph)


def verify():
    graph=json.loads((OUT/'workflow_api.json').read_text(encoding='utf-8'))
    assert graph['5']['inputs']['first_frame']==['4',0] and graph['5']['inputs']['last_frame']==['16',0]
    assert graph['6']['inputs']['conditioning']==['19',0] and graph['18']['inputs']['frame_idx']==34 and graph['19']['inputs']['frame_idx']==72
    assert graph['10']['inputs']['latent_image']==['5',1]
    assert graph['5']['inputs']['prompt']==(OUT/'prompt.txt').read_text(encoding='utf-8').strip()
    for ref in json.loads((OUT/'reference.json').read_text(encoding='utf-8'))['guides']:
        assert sha(OUT/ref['input_file'])==ref['input_sha256']
        assert sha(ROOT/ref['source_frame']['source'])==ref['source_sha256']


def submit():
    verify()
    if (OUT/'submission.json').exists():raise RuntimeError('Already submitted; inspect exact job')
    q=request(URL,'/queue')
    if q['queue_running'] or q['queue_pending']:raise RuntimeError('Server busy; leave queue untouched')
    graph=json.loads((OUT/'workflow_api.json').read_text(encoding='utf-8'));uploaded={}
    for key,filename in [('4','input_green.png'),('16','corpse_green.png'),('17','kneel_green.png')]:
        boundary='----PrismHarrierH3H3'
        data=(f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="prism_adept_death_{filename}"\r\nContent-Type: image/png\r\n\r\n'.encode()+(OUT/filename).read_bytes()+f'\r\n--{boundary}--\r\n'.encode())
        req=urllib.request.Request(URL+'/upload/image',data=data,headers={'Content-Type':'multipart/form-data; boundary='+boundary})
        with urllib.request.urlopen(req,timeout=60) as response:r=json.load(response)
        uploaded[key]=r;graph[key]['inputs']['image']='/'.join(s for s in [r.get('subfolder',''),r['name']] if s)
    write(OUT/'workflow_api.json',graph)
    started=time.time();r=request(URL,'/prompt',dict(prompt=graph,client_id='prism_adept_death_h3'))
    write(OUT/'submission.json',dict(**r,started_unix=started,url=URL,uploaded=uploaded));print(json.dumps(r))


def key(rgb):
 a=np.asarray(rgb,dtype=np.float32)
 corner_tiles=[a[:24,:24],a[:24,-24:],a[-24:,:24],a[-24:,-24:]]
 corner_medians=np.array([np.median(tile.reshape(-1,3),axis=0) for tile in corner_tiles])
 bg=np.median(corner_medians,axis=0)
 spread=float(np.max(np.linalg.norm(corner_medians-bg,axis=1)))
 if spread>10:raise ValueError(f'unsafe spatially varying corner plate {bg}; median spread={spread:.2f}')
 bgc=bg[1]-max(bg[0],bg[2])
 if bgc<150:raise ValueError(f'unsafe green backdrop {bg}')
 chroma=a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2])
 alpha=np.clip(1-chroma/bgc,0,1)
 alpha[np.linalg.norm(a-bg,axis=2)<12]=0
 color=np.clip((a-(1-alpha[:,:,None])*bg)/np.maximum(alpha[:,:,None],.001),0,255)
 color[:,:,1]=np.minimum(color[:,:,1],np.maximum(color[:,:,0],color[:,:,2]))
 mode='flat_green_chroma_unmix'
 out=np.dstack([color,alpha*255]).astype('uint8');out[out[:,:,3]<8]=0
 # Retain every >8-alpha connected creature component that contains at least
 # one confidently opaque pixel. This removes disconnected plate noise while
 # keeping thin blade edges, scarf strands, finger grips, and boot soles attached
 # to their own solid pixels.
 mask=out[:,:,3]>=8; labels,n=label(mask,structure=np.ones((3,3),dtype=np.uint8))
 solid=np.unique(labels[out[:,:,3]>=128]); keep=np.zeros(n+1,dtype=bool);keep[solid]=True;keep[0]=False
 out[~keep[labels]]=0
 return Image.fromarray(out,'RGBA'),dict(background_rgb=[round(float(v),3) for v in bg],corner_median_spread=round(float(spread),3),mode=mode,component_rule='alpha>=8 components retained only when they contain alpha>=128 source pixels')

def process():
    (OUT/'matte').mkdir(exist_ok=True);hashes=[];meta=[]
    with av.open(str(OUT/'original_lossless.mkv')) as video:
        for i,frame in enumerate(video.decode(video=0)):
            im,details=key(frame.to_image().convert('RGB'))
            p=OUT/'matte'/f'rgba_{i:03}.png';im.save(p);hashes.append(sha(p));meta.append(details)
    assert len(hashes)==124
    write(OUT/'matte.json',dict(frames=124,fps=24,rgba_sha256=hashes,background_frames=meta,recipe='Uniform pure-green corner check; green dominance alpha unmix and RGB despill; background distance floor12; alpha>=8 components retained when containing alpha>=128 pixels. No geometry editing or alignment.'))


def review():
    target=ROOT/'.artifacts/prism_adept_h3/death_guided_v2';target.mkdir(parents=True,exist_ok=True)
    for part in range(2):
        sheet=Image.new('RGB',(1440,1600),(35,45,32));draw=ImageDraw.Draw(sheet)
        for j,i in enumerate(range(part*62,(part+1)*62)):
            x,y=j%8*180,j//8*200
            if j%2:sheet.paste((218,211,193),(x,y,x+180,y+200))
            im=Image.open(OUT/'matte'/f'rgba_{i:03}.png').crop((170,40,850,520));im.thumbnail((174,178),Image.Resampling.LANCZOS);sheet.paste(im,(x+(180-im.width)//2,y+20),im);draw.text((x+5,y+4),str(i),fill=(160,110,65))
        sheet.save(target/f'chronological_{part}.png')


def build():
    selection=json.loads((OUT/'selection.json').read_text(encoding='utf-8'));indices=selection['source_frames'];assert len(indices)>=8 and len(indices)==len(set(indices))
    frames=[dict(name=f'death_h3_{i:03}',clip='death',source=(OUT/'matte'/f'rgba_{i:03}.png').relative_to(ROOT).as_posix(),rects=[[0,0,960,544]],anchor=ANCHOR,scale=RUNTIME_SCALE,alpha_noise_cutoff=0,video_frame=i,video_time_seconds=i/24) for i in indices]
    provenance={n:dict(path=(OUT/n).relative_to(ROOT).as_posix(),sha256=sha(OUT/n)) for n in ['original_lossless.mkv','original.json','workflow_api.json','prompt.txt','reference.json','matte.json']}
    entry=dict(unit_id=UNIT,reference_height=256,source_facing='right',frames=frames,alpha_noise_cutoff=0,clips={'death':dict(indices=list(range(len(frames))),frame_msec=selection['frame_msec'],loop=False,static_frame=len(frames)-1)},source_scale_reason='Original accepted ready uses .6 runtime body scale, .95 input and .6/.95 extraction. Original corpse uses .54 source anatomical scale, same extraction; source anchor850,1332 mapped to480,475. No per-pose size normalization.',provenance=provenance,visual_review=dict(status='pending',notes=selection['review_note']))
    write(OUT/'handoff.json',dict(schema_version=1,units=[entry]))
    previous=json.loads((ROOT/'art/animation/source/fluid'/UNIT/'reviewed_handoff.json').read_text(encoding='utf-8'))['units'][0];candidate=combine(previous,entry);candidate['preserved_accepted_clips']=previous.get('preserved_accepted_clips',[])
    target=ROOT/'.artifacts/prism_adept_h3/death_guided_v2';target.mkdir(parents=True,exist_ok=True);write(target/'combined_handoff.json',dict(schema_version=1,units=[candidate]))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('verb',choices=['prepare','verify','submit','status','collect','process','review','build']);args=p.parse_args()
    if args.verb=='prepare':prepare();verify()
    elif args.verb=='status':status(OUT,URL)
    elif args.verb=='collect':collect(OUT,URL)
    else:globals()[args.verb]()
