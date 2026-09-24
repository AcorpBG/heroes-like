"""Preserved Milestone Buckler H3 take; see selection/rejection and root README."""
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
from scipy.ndimage import label, binary_erosion, distance_transform_edt

ROOT = next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT/'tools'))
from trial_video_creature_animation import collect, request, status, node, write
from integrate_fluid_creature_animation import source_pose
from publish_fluid_creature_animation import combine

UNIT = 'unit_neutral_milestone_bucklers'
URL = 'http://127.0.0.1:8189'
ANCHOR = [480, 475]
INPUT_SCALE = .95
RUNTIME_SCALE = .65
PROMPT = 'This exact adult bearded male infantry soldier: short dark brown hair, cream scarf, rust-red quilted tunic, steel shoulder plates, navy trousers, brown gloves and boots, leather belt pouches. One rigid rectangular navy wooden shield with brass rim, vertical brass stripe and round boss stays on the far image-right forearm. The near image-left hand grips the same short wooden spear with one steel leaf-shaped head. Exactly two arms, hands and legs; no duplicate weapons. Original three-quarter RIGHT-facing orthographic view and body proportions. Make one physical rally salute: rotate the spear from its low diagonal ready position to vertical beside the head, keeping the same grip, shield and two planted boots. Raise12-42, hold the upright spear42-58, lower smoothly to ready by86. The shield remains steady in front. No attack, throwing, magic or added effects. The spear is rigid and retains its original length throughout. Locked camera and fixed root, scale and lighting. Full spear tip stays in frame. Clean crisp opaque painted sprite, no blur. Background is one stationary solid magenta matte color identical to the guides throughout.'


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def prepare():
    if (OUT/'submission.json').exists():
        raise RuntimeError('Never overwrite a submitted original')
    recipe = json.loads((ROOT/'art/animation/source/fluid/unit_neutral_milestone_bucklers/reviewed_handoff.json').read_bytes())['units'][0]
    originals=json.loads((ROOT/'art/units/source/generated/fluid_animation/batch_d/unit_neutral_milestone_bucklers/handoff.json').read_bytes())['units'][0]['frames']
    contacts = [next(f for f in originals if f['name']=='cast_00'),dict(next(f for f in originals if f['name']=='cast_02'),rects=[[0,365,512,762]])]
    refs = []
    for original,filename in zip(contacts,['input_magenta.png','peak_magenta.png']):
        frame = original.copy()
        frame.setdefault('alpha_noise_cutoff',8)
        original_scale = frame['scale']
        assert original_scale in [.46,.59,.61,.64]
        frame['scale'] = original_scale / RUNTIME_SCALE
        subject,(x,y) = source_pose(frame)
        transparent = Image.new('RGBA',(960,544))
        transparent.alpha_composite(subject,(ANCHOR[0]+x,ANCHOR[1]+y))
        transparent.save(OUT/filename.replace('_magenta','_rgba'))
        canvas = Image.new('RGBA',(960,544),(255,0,255,255))
        canvas.alpha_composite(transparent);canvas.convert('RGB').save(OUT/filename)
        refs.append(dict(source_frame=frame,source_sha256=sha(ROOT/frame['source']),input_file=filename,input_sha256=sha(OUT/filename),runtime_source_scale=original_scale))
    write(OUT/'reference.json',dict(unit_id=UNIT,guides=refs,canvas=[960,544],ground_anchor=ANCHOR,input_scale_rule="Each guide source_frame.scale equals runtime_source_scale / output_scale",output_scale=RUNTIME_SCALE))
    row = next(r for r in json.loads((ROOT/'content/unit_animation_manifest.json').read_text(encoding='utf-8'))['items'] if r['id']==UNIT)
    write(OUT/'accepted_baseline.json',row)
    (OUT/'prompt.txt').write_text(PROMPT+'\n',encoding='utf-8')
    graph = {
        '1':node('UNETLoader',unet_name='minimax_h3_fl2va_pruned_int8_convrot.safetensors',weight_dtype='default'),
        '2':node('CLIPLoader',clip_name='qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors',type='minimax',device='default'),
        '3':node('VAELoader',vae_name='minimax_h3_video_vae_int8_convrot.safetensors'),
        '4':node('LoadImage',image='milestone_cast_input.png'),
        '5':node('MiniMaxH3ImageToVideo',clip=['2',0],vae=['3',0],prompt=PROMPT,width=960,height=544,length=124,first_frame=['4',0],last_frame=['4',0]),
        '16':node('LoadImage',image='milestone_peak.png'),
        '17':node('MiniMaxH3AddGuide',positive=['5',0],latent=['5',1],frame_idx=42,vae=['3',0],image=['16',0]),
        '18':node('MiniMaxH3AddGuide',positive=['17',0],latent=['5',1],frame_idx=58,vae=['3',0],image=['16',0]),
        '19':node('MiniMaxH3AddGuide',positive=['18',0],latent=['5',1],frame_idx=86,vae=['3',0],image=['4',0]),
        '6':node('BasicGuider',model=['1',0],conditioning=['19',0]),
        '7':node('RandomNoise',noise_seed=2026092453),
        '8':node('KSamplerSelect',sampler_name='res_multistep'),
        '9':node('BasicScheduler',model=['1',0],scheduler='simple',steps=20,denoise=1.0),
        '10':node('SamplerCustomAdvanced',noise=['7',0],guider=['6',0],sampler=['8',0],sigmas=['9',0],latent_image=['5',1]),
        '11':node('VAEDecode',samples=['10',0],vae=['3',0]),
        '13':node('CreateVideo',images=['11',0],fps=24,bit_depth=8),
        '14':node('SaveVideo',video=['13',0],filename_prefix='milestone_h3/cast_v1/original',**{'format':'mp4','format.codec':'h264'}),
        '15':node('SaveImage',images=['11',0],filename_prefix='milestone_h3/cast_v1/frames/decoded'),
    }
    write(OUT/'workflow_api.json',graph)


def verify():
    graph=json.loads((OUT/'workflow_api.json').read_text(encoding='utf-8'))
    assert graph['5']['inputs']['first_frame']==graph['5']['inputs']['last_frame']==['4',0]
    assert graph['6']['inputs']['conditioning']==['19',0]
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
    for key,filename in [('4','input_magenta.png'),('16','peak_magenta.png')]:
        boundary='----MilestoneH3'
        data=(f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="milestone_cast_{filename}"\r\nContent-Type: image/png\r\n\r\n'.encode()+(OUT/filename).read_bytes()+f'\r\n--{boundary}--\r\n'.encode())
        req=urllib.request.Request(URL+'/upload/image',data=data,headers={'Content-Type':'multipart/form-data; boundary='+boundary})
        with urllib.request.urlopen(req,timeout=60) as response:r=json.load(response)
        uploaded[key]=r;graph[key]['inputs']['image']='/'.join(s for s in [r.get('subfolder',''),r['name']] if s)
    write(OUT/'workflow_api.json',graph)
    started=time.time();r=request(URL,'/prompt',dict(prompt=graph,client_id='milestone_cast_h3'))
    write(OUT/'submission.json',dict(**r,started_unix=started,url=URL,uploaded=uploaded));print(json.dumps(r))


def key(rgb):
 a=np.asarray(rgb,dtype=np.float32)
 corner_tiles=[a[:24,:24],a[:24,-24:],a[-24:,:24],a[-24:,-24:]]
 corner_medians=np.array([np.median(tile.reshape(-1,3),axis=0) for tile in corner_tiles])
 bg=np.median(corner_medians,axis=0)
 spread=float(np.max(np.linalg.norm(corner_medians-bg,axis=1)))
 if spread>10:raise ValueError(f'unsafe spatially varying corner plate {bg}; median spread={spread:.2f}')
 bgc=min(bg[0],bg[2])-bg[1]
 if bgc<150:raise ValueError(f'unsafe magenta backdrop {bg}')
 chroma=np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1]
 alpha=np.clip(1-chroma/bgc,0,1)
 alpha[np.linalg.norm(a-bg,axis=2)<12]=0
 # Refine alpha only in the four-pixel uncertain edge band. Estimate local
 # foreground from a confidently opaque interior, then solve the observed
 # RGB pixel as a foreground/background mixture. This removes magenta/red
 # contamination without eroding the silhouette or repainting opaque anatomy.
 core=binary_erosion(alpha>=.98,iterations=4)
 if not core.any():raise ValueError('No confident foreground interior')
 _,nearest=distance_transform_edt(~core,return_indices=True)
 foreground=a[nearest[0],nearest[1]]
 direction=foreground-bg
 estimate=np.clip(np.sum((a-bg)*direction,axis=2)/np.maximum(np.sum(direction*direction,axis=2),1),0,1)
 edge=(distance_transform_edt(alpha>=.98)<=4)&(alpha>0)
 alpha=np.where(edge,np.minimum(estimate,alpha),alpha)
 color=np.clip((a-(1-alpha[:,:,None])*bg)/np.maximum(alpha[:,:,None],.001),0,255)
 spill=np.maximum(np.minimum(color[:,:,0],color[:,:,2])-color[:,:,1],0)
 color[:,:,0]-=spill; color[:,:,2]-=spill
 mode='flat_magenta_local_edge_alpha_unmix'
 out=np.dstack([color,alpha*255]).astype('uint8');out[out[:,:,3]<8]=0
 # Retain every >8-alpha connected creature component that contains at least
 # one confidently opaque pixel. This removes disconnected plate noise while
 # keeping thin spear tips, scarf edges, hands and boot soles attached
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
    write(OUT/'matte.json',dict(frames=124,fps=24,rgba_sha256=hashes,background_frames=meta,recipe='Uniform pure-magenta corner check; min(red,blue)-green alpha; four-pixel edge alpha refined by nearest opaque interior RGB/background least-squares mixture; unmix and magenta despill; background distance floor12; alpha>=8 components retained when containing alpha>=128 pixels. No geometry editing or alignment.'))


def review():
    target=ROOT/'.artifacts/milestone_h3/cast_v1';target.mkdir(parents=True,exist_ok=True)
    for part in range(2):
        sheet=Image.new('RGB',(1440,1600),(35,45,32));draw=ImageDraw.Draw(sheet)
        for j,i in enumerate(range(part*62,(part+1)*62)):
            x,y=j%8*180,j//8*200
            if j%2:sheet.paste((218,211,193),(x,y,x+180,y+200))
            im=Image.open(OUT/'matte'/f'rgba_{i:03}.png').crop((190,15,800,520));im.thumbnail((174,178),Image.Resampling.LANCZOS);sheet.paste(im,(x+(180-im.width)//2,y+20),im);draw.text((x+5,y+4),str(i),fill=(160,110,65))
        sheet.save(target/f'chronological_{part}.png')


def build():
    selection=json.loads((OUT/'selection.json').read_text(encoding='utf-8'));indices=selection['source_frames'];assert len(indices)>=8 and len(indices)==len(set(indices))
    frames=[dict(name=f'cast_h3_{i:03}',clip='cast',source=(OUT/'matte'/f'rgba_{i:03}.png').relative_to(ROOT).as_posix(),rects=[[0,0,960,544]],anchor=ANCHOR,scale=RUNTIME_SCALE,alpha_noise_cutoff=0,video_frame=i,video_time_seconds=i/24) for i in indices]
    provenance={n:dict(path=(OUT/n).relative_to(ROOT).as_posix(),sha256=sha(OUT/n)) for n in ['original_lossless.mkv','original.json','workflow_api.json','prompt.txt','reference.json','matte.json']}
    entry=dict(unit_id=UNIT,reference_height=256,source_facing='right',frames=frames,alpha_noise_cutoff=0,clips={'cast':dict(indices=list(range(len(frames))),frame_msec=selection['frame_msec'],loop=False,static_frame=0)},source_scale_reason='Original Milestone source scales retained: ready and support .61, walking .64, collapse and corpse .46. Each input scale is original scale/.65; extraction fixed .65 with anatomical ground anchor480,475. No per-frame normalization.',provenance=provenance,visual_review=dict(status='pending',notes=selection['review_note']))

    if 'contact_frame' in selection: entry['clips']['cast']['contact_frame']=selection['contact_frame']
    if 'projectile_travel_msec' in selection: entry['clips']['cast']['projectile_travel_msec']=selection['projectile_travel_msec']
    write(OUT/'handoff.json',dict(schema_version=1,units=[entry]))
    previous=json.loads((ROOT/'art/animation/source/fluid'/UNIT/'reviewed_handoff.json').read_text(encoding='utf-8'))['units'][0];candidate=combine(previous,entry);candidate['preserved_accepted_clips']=previous.get('preserved_accepted_clips',[])
    target=ROOT/'.artifacts/milestone_h3/cast_v1';target.mkdir(parents=True,exist_ok=True);write(target/'combined_handoff.json',dict(schema_version=1,units=[candidate]))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('verb',choices=['prepare','verify','submit','status','collect','process','review','build']);args=p.parse_args()
    if args.verb=='prepare':prepare();verify()
    elif args.verb=='status':status(OUT,URL)
    elif args.verb=='collect':collect(OUT,URL)
    else:globals()[args.verb]()
