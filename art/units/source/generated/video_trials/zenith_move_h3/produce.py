"""Original-guide H3 reciprocal walk for Zenith Lensbearers; publication is explicit."""
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

UNIT = 'unit_sunvault_zenith_lensbearers'
URL = 'http://127.0.0.1:8189'
ANCHOR = [480, 475]
INPUT_SCALE = 1.0
RUNTIME_SCALE = .6 / INPUT_SCALE
PROMPT = 'Locked orthographic three-quarter RIGHT-facing fantasy strategy sprite camera. Animate this exact Zenith Lensbearer walking IN PLACE through two full reciprocal left-right cycles and returning to the reference stance. Preserve pale face and swept white hair, blue crystal eye lens, navy blue/gold cloak and coat, white split tabard, silver-and-gold leg armor and boots, dark gloves. Exactly two arms and two legs. Both hands keep their ORIGINAL separate grips on the ONE long horizontal gold-and-silver lens weapon aimed toward image RIGHT at waist/chest height. Keep the rigid straight barrel, gold rings, bright blue internal crystal, and ONE front angular gold lens cage around its blue glass sphere. No recoil, firing, charging, spellcasting, duplicated lens cages, extra guns or changing weapon length. Rear hand holds rear grip and forward hand supports barrel; hands never merge or swap. Preserve the separate small vertical blue orb on gold stem behind his head and angular prism plates on back: they stay attached and do not become a second held weapon. All blue light remains contained in the original optics; no beams, particles or new effects. Both feet must alternate: near boot reaches forward toward IMAGE RIGHT and plants heel then sole while far leg trails; far knee bends and far boot swings under pelvis to opposite forward heel contact; far foot plants and supports body while near foot trails, passes and reaches forward again. Each leg shows forward contact, support, heel lift and passing, never repeating only one leading leg. Controlled modest stride while carrying a heavy rigid instrument. No hopping, skating, boot stretching or foot swaps. Torso, pelvis and knees keep original RIGHT-facing three-quarter orientation; do not turn body left or to front/profile. Small natural shoulder motion, weapon remains rightward and steady. Cloak and tabard gently lag with footsteps. Same anatomy/body scale and centered pelvis throughout; no world travel, camera pan, zoom or perspective changes. Entire hair, back orb, weapon tip, cloak and both boots stay inside frame. Background perfectly uniform PURE GREEN RGB(0,255,0) throughout, no floor, shadow, gradient, text, blur or scenery.'


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def prepare():
    if (OUT/'submission.json').exists():
        raise RuntimeError('Never overwrite a submitted original')
    recipe = json.loads((ROOT/'art/animation/source/fluid/unit_sunvault_zenith_lensbearers/reviewed_handoff.json').read_bytes())['units'][0]
    contacts = [recipe['frames'][recipe['clips']['attack']['indices'][0]]]
    refs = []
    for original,filename in zip(contacts,['input_green.png']):
        frame = original.copy()
        original_scale = frame['scale']
        assert original_scale==.6
        frame['scale'] = INPUT_SCALE
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
        '4':node('LoadImage',image='zenith_walk_input.png'),
        '5':node('MiniMaxH3ImageToVideo',clip=['2',0],vae=['3',0],prompt=PROMPT,width=960,height=544,length=124,first_frame=['4',0],last_frame=['4',0]),
        '6':node('BasicGuider',model=['1',0],conditioning=['5',0]),
        '7':node('RandomNoise',noise_seed=2026092424),
        '8':node('KSamplerSelect',sampler_name='res_multistep'),
        '9':node('BasicScheduler',model=['1',0],scheduler='simple',steps=20,denoise=1.0),
        '10':node('SamplerCustomAdvanced',noise=['7',0],guider=['6',0],sampler=['8',0],sigmas=['9',0],latent_image=['5',1]),
        '11':node('VAEDecode',samples=['10',0],vae=['3',0]),
        '13':node('CreateVideo',images=['11',0],fps=24,bit_depth=8),
        '14':node('SaveVideo',video=['13',0],filename_prefix='zenith_move_h3/original',**{'format':'mp4','format.codec':'h264'}),
        '15':node('SaveImage',images=['11',0],filename_prefix='zenith_move_h3/frames/decoded'),
    }
    write(OUT/'workflow_api.json',graph)


def verify():
    graph=json.loads((OUT/'workflow_api.json').read_text(encoding='utf-8'))
    assert graph['5']['inputs']['first_frame']==graph['5']['inputs']['last_frame']==['4',0]
    assert graph['6']['inputs']['conditioning']==['5',0]
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
    for key,filename in [('4','input_green.png')]:
        boundary='----ZenithWalkH3'
        data=(f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="zenith_walk_{filename}"\r\nContent-Type: image/png\r\n\r\n'.encode()+(OUT/filename).read_bytes()+f'\r\n--{boundary}--\r\n'.encode())
        req=urllib.request.Request(URL+'/upload/image',data=data,headers={'Content-Type':'multipart/form-data; boundary='+boundary})
        with urllib.request.urlopen(req,timeout=60) as response:r=json.load(response)
        uploaded[key]=r;graph[key]['inputs']['image']='/'.join(s for s in [r.get('subfolder',''),r['name']] if s)
    write(OUT/'workflow_api.json',graph)
    started=time.time();r=request(URL,'/prompt',dict(prompt=graph,client_id='zenith_walk_h3'))
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
    target=ROOT/'.artifacts/zenith_move_h3';target.mkdir(parents=True,exist_ok=True)
    for part in range(2):
        sheet=Image.new('RGB',(1440,1600),(35,45,32));draw=ImageDraw.Draw(sheet)
        for j,i in enumerate(range(part*62,(part+1)*62)):
            x,y=j%8*180,j//8*200
            if j%2:sheet.paste((218,211,193),(x,y,x+180,y+200))
            im=Image.open(OUT/'matte'/f'rgba_{i:03}.png').crop((240,40,750,515));im.thumbnail((174,178),Image.Resampling.LANCZOS);sheet.paste(im,(x+(180-im.width)//2,y+20),im);draw.text((x+5,y+4),str(i),fill=(160,110,65))
        sheet.save(target/f'chronological_{part}.png')


def build():
    selection=json.loads((OUT/'selection.json').read_text(encoding='utf-8'));indices=selection['source_frames'];assert len(indices)>=8 and len(indices)==len(set(indices))
    frames=[dict(name=f'move_h3_{i:03}',clip='move',source=(OUT/'matte'/f'rgba_{i:03}.png').relative_to(ROOT).as_posix(),rects=[[0,0,960,544]],anchor=ANCHOR,scale=RUNTIME_SCALE,alpha_noise_cutoff=0,video_frame=i,video_time_seconds=i/24) for i in indices]
    provenance={n:dict(path=(OUT/n).relative_to(ROOT).as_posix(),sha256=sha(OUT/n)) for n in ['original_lossless.mkv','original.json','workflow_api.json','prompt.txt','reference.json','matte.json']}
    entry=dict(unit_id=UNIT,reference_height=256,source_facing='right',frames=frames,alpha_noise_cutoff=0,clips={'move':dict(indices=list(range(len(frames))),frame_msec=selection['frame_msec'],loop=True,static_frame=0)},source_scale_reason='Accepted ready source uses .6 runtime scale; video 1.0 input scale, extraction .6, fixed anchor480,475. No per-pose normalization.',provenance=provenance,visual_review=dict(status='pending',notes=selection['review_note']))
    write(OUT/'handoff.json',dict(schema_version=1,units=[entry]))
    previous=json.loads((ROOT/'art/animation/source/fluid'/UNIT/'reviewed_handoff.json').read_text(encoding='utf-8'))['units'][0];candidate=combine(previous,entry);candidate['preserved_accepted_clips']=previous.get('preserved_accepted_clips',[])
    target=ROOT/'.artifacts/zenith_move_h3';target.mkdir(parents=True,exist_ok=True);write(target/'combined_handoff.json',dict(schema_version=1,units=[candidate]))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('verb',choices=['prepare','verify','submit','status','collect','process','review','build']);args=p.parse_args()
    if args.verb=='prepare':prepare();verify()
    elif args.verb=='status':status(OUT,URL)
    elif args.verb=='collect':collect(OUT,URL)
    else:globals()[args.verb]()
