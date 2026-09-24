"""Original-guide H3 reciprocal walk for Worldroot; publication is explicit."""
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

UNIT = 'unit_thornwake_worldroot_bastion'
URL = 'http://127.0.0.1:8189'
ANCHOR = [480, 465]
INPUT_SCALE = .36
RUNTIME_SCALE = .185 / INPUT_SCALE
PROMPT = '''Locked orthographic three-quarter RIGHT-facing fantasy strategy sprite camera. This exact original Worldroot Bastion is a massive living wooden fortress standing on EXACTLY FOUR articulated root legs. It walks IN PLACE slowly and heavily, one root foot at a time, always supported by the other three. Preserve the identical green leaf-patterned front doorway on image center-right, ivory birch armor, red thorn bindings, amber lantern nodules, tall amber crown, three small red roof turrets, wooden bridges, foliage and ivory pennants. Keep all architecture rigid and identical: no towers multiplying, roof morphing, opening door, flying parts or living face. There are four ROOT LEGS, no separate humanoid arms. Begin with the rear root foot on extreme image LEFT lifted as shown. Lower it to its original contact lane, transfer weight, bend and lift the thick FOREGROUND root foot left of the green door to match the first quarter guide. Lower it, then lift the thinner rear root foot visible BELOW the door at the midpoint guide. Lower it, then lift the root foot on extreme image RIGHT to match the three-quarter guide. Lower it, and return the extreme-left rear foot to its first raised position. Smoothly articulate knees/wooden joints and curled root toes between the four supplied original poses. Each foot lifts clear, passes a SHORT controlled distance, then plants; the three supporting feet bear weight. Keep the same four leg attachments, original paw size and constant building dimensions. Do not fuse roots, grow extra limbs, slide all feet together or exaggerate reaching toward the camera. Body remains centered with subtle natural weight transfer only; no horizontal travel, turning, zoom, camera tilt or perspective change. Small pennants and hanging vines may sway subtly. Amber lamps maintain steady original brightness; no spells, bursts, particles, smoke or new glow. End exactly in the first pose for one seamless complete walking cycle. Every root toe, turret and crown stays inside frame. Background must remain perfectly uniform SOLID MAGENTA RGB(255,0,255) throughout, never shifting hue or brightness. No floor, scenery, cast shadow, text, motion blur or new objects.'''


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def prepare():
    if (OUT/'submission.json').exists():
        raise RuntimeError('Never overwrite a submitted original')
    source_dir = ROOT/'art/animation/source/poses'/UNIT
    recipe = json.loads((source_dir/'packing.json').read_text(encoding='utf-8'))
    refs = []
    for name, filename in [('step_rear_left','input_magenta.png'),('step_rear_middle','middle_magenta.png'),('step_fore_left','quarter_magenta.png'),('step_fore_right','threequarter_magenta.png')]:
        frame = next(f for f in recipe['frames'] if f['name']==name).copy()
        original_scale = frame['scale']
        frame['source'] = (source_dir/frame['source']).relative_to(ROOT).as_posix()
        frame['scale'] = INPUT_SCALE
        subject,(x,y) = source_pose(frame)
        transparent = Image.new('RGBA',(960,544))
        transparent.alpha_composite(subject,(ANCHOR[0]+x,ANCHOR[1]+y))
        transparent.save(OUT/filename.replace('_magenta','_rgba'))
        canvas = Image.new('RGBA',(960,544),(255,0,255,255))
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
        '4':node('LoadImage',image='worldroot_walk_input.png'),
        '5':node('MiniMaxH3ImageToVideo',clip=['2',0],vae=['3',0],prompt=PROMPT,width=960,height=544,length=124,first_frame=['4',0],last_frame=['4',0]),
        '6':node('BasicGuider',model=['1',0],conditioning=['20',0]),
        '7':node('RandomNoise',noise_seed=2026092410),
        '8':node('KSamplerSelect',sampler_name='res_multistep'),
        '9':node('BasicScheduler',model=['1',0],scheduler='simple',steps=20,denoise=1.0),
        '10':node('SamplerCustomAdvanced',noise=['7',0],guider=['6',0],sampler=['8',0],sigmas=['9',0],latent_image=['5',1]),
        '11':node('VAEDecode',samples=['10',0],vae=['3',0]),
        '13':node('CreateVideo',images=['11',0],fps=24,bit_depth=8),
        '14':node('SaveVideo',video=['13',0],filename_prefix='worldroot_move_h3/original',**{'format':'mp4','format.codec':'h264'}),
        '15':node('SaveImage',images=['11',0],filename_prefix='worldroot_move_h3/frames/decoded'),
        '16':node('LoadImage',image='worldroot_walk_middle.png'),
        '17':node('MiniMaxH3AddGuide',positive=['5',0],latent=['5',1],vae=['3',0],frame_idx=61,image=['16',0]),
        '18':node('LoadImage',image='worldroot_fore_left.png'),
        '21':node('LoadImage',image='worldroot_fore_right.png'),
        '19':node('MiniMaxH3AddGuide',positive=['17',0],latent=['5',1],vae=['3',0],frame_idx=30,image=['18',0]),
        '20':node('MiniMaxH3AddGuide',positive=['19',0],latent=['5',1],vae=['3',0],frame_idx=92,image=['21',0]),
    }
    write(OUT/'workflow_api.json',graph)


def verify():
    graph=json.loads((OUT/'workflow_api.json').read_text(encoding='utf-8'))
    assert graph['5']['inputs']['first_frame']==graph['5']['inputs']['last_frame']==['4',0]
    assert graph['6']['inputs']['conditioning']==['20',0]
    assert graph['10']['inputs']['latent_image']==['5',1]
    assert graph['19']['inputs']==dict(positive=['17',0],latent=['5',1],vae=['3',0],frame_idx=30,image=['18',0])
    assert graph['20']['inputs']==dict(positive=['19',0],latent=['5',1],vae=['3',0],frame_idx=92,image=['21',0])
    assert graph['17']['inputs']==dict(positive=['5',0],latent=['5',1],vae=['3',0],frame_idx=61,image=['16',0])
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
    for key,filename in [('4','input_magenta.png'),('16','middle_magenta.png'),('18','quarter_magenta.png'),('21','threequarter_magenta.png')]:
        boundary='----WorldrootWalkH3'
        data=(f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="worldroot_walk_{filename}"\r\nContent-Type: image/png\r\n\r\n'.encode()+(OUT/filename).read_bytes()+f'\r\n--{boundary}--\r\n'.encode())
        req=urllib.request.Request(URL+'/upload/image',data=data,headers={'Content-Type':'multipart/form-data; boundary='+boundary})
        with urllib.request.urlopen(req,timeout=60) as response:r=json.load(response)
        uploaded[key]=r;graph[key]['inputs']['image']='/'.join(s for s in [r.get('subfolder',''),r['name']] if s)
    write(OUT/'workflow_api.json',graph)
    started=time.time();r=request(URL,'/prompt',dict(prompt=graph,client_id='worldroot_walk_h3'))
    write(OUT/'submission.json',dict(**r,started_unix=started,url=URL,uploaded=uploaded));print(json.dumps(r))


def process():
    (OUT/'matte').mkdir(exist_ok=True);hashes=[]
    with av.open(str(OUT/'original_lossless.mkv')) as video:
        for i,frame in enumerate(video.decode(video=0)):
            a=np.asarray(frame.to_image().convert('RGB'),dtype=np.float32)
            corners=np.array([np.median(t.reshape(-1,3),axis=0) for t in (a[:24,:24],a[:24,-24:],a[-24:,:24],a[-24:,-24:])]);bg=np.median(corners,axis=0)
            if np.max(np.linalg.norm(corners-bg,axis=1))>10 or min(bg[0],bg[2])-bg[1]<150:raise ValueError(f'Frame {i}: unsafe magenta plate')
            alpha=np.clip(1-(np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1])/(min(bg[0],bg[2])-bg[1]),0,1)
            rgb=np.clip((a-(1-alpha[:,:,None])*bg)/np.maximum(alpha[:,:,None],.001),0,255)
            spill=np.maximum(0,np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]);rgb[:,:,0]-=spill;rgb[:,:,2]-=spill
            rgba=np.dstack([rgb,alpha*255]).astype('uint8');rgba[rgba[:,:,3]<8]=0
            labels,n=label(rgba[:,:,3]>=8,structure=np.ones((3,3),dtype=np.uint8));keep=np.zeros(n+1,dtype=bool);keep[np.unique(labels[rgba[:,:,3]>=128])]=True;keep[0]=False;rgba[~keep[labels]]=0
            p=OUT/'matte'/f'rgba_{i:03}.png';Image.fromarray(rgba).save(p);hashes.append(sha(p))
    assert len(hashes)==124
    write(OUT/'matte.json',dict(frames=124,fps=24,rgba_sha256=hashes,recipe='Uniform magenta corner check; magenta alpha unmix and RGB despill; alpha>=8 components retained if containing alpha>=128. Preserve separate ornaments; no largest-component masking, geometry editing or per-frame alignment.'))


def review():
    target=ROOT/'.artifacts/worldroot_move_h3';target.mkdir(parents=True,exist_ok=True)
    for part in range(2):
        sheet=Image.new('RGB',(1440,1600),(35,45,32));draw=ImageDraw.Draw(sheet)
        for j,i in enumerate(range(part*62,(part+1)*62)):
            x,y=j%8*180,j//8*200
            if j%2:sheet.paste((218,211,193),(x,y,x+180,y+200))
            im=Image.open(OUT/'matte'/f'rgba_{i:03}.png').crop((220,20,750,530));im.thumbnail((174,178),Image.Resampling.LANCZOS);sheet.paste(im,(x+(180-im.width)//2,y+20),im);draw.text((x+5,y+4),str(i),fill=(160,110,65))
        sheet.save(target/f'chronological_{part}.png')


def build():
    selection=json.loads((OUT/'selection.json').read_text(encoding='utf-8'));indices=selection['source_frames'];assert len(indices)>=8 and len(indices)==len(set(indices))
    frames=[dict(name=f'move_h3_{i:03}',clip='move',source=(OUT/'matte'/f'rgba_{i:03}.png').relative_to(ROOT).as_posix(),rects=[[0,0,960,544]],anchor=ANCHOR,scale=RUNTIME_SCALE,alpha_noise_cutoff=0,video_frame=i,video_time_seconds=i/24) for i in indices]
    provenance={n:dict(path=(OUT/n).relative_to(ROOT).as_posix(),sha256=sha(OUT/n)) for n in ['original_lossless.mkv','original.json','workflow_api.json','prompt.txt','reference.json','matte.json']}
    entry=dict(unit_id=UNIT,reference_height=256,source_facing='right',frames=frames,alpha_noise_cutoff=0,clips={'move':dict(indices=list(range(len(frames))),frame_msec=selection['frame_msec'],loop=True,static_frame=0)},source_scale_reason='Original walk scale .185 / video guide scale .36, fixed source anchor480,465; no per-pose normalization.',provenance=provenance,visual_review=dict(status='pending',notes=selection['review_note']))
    write(OUT/'handoff.json',dict(schema_version=1,units=[entry]))
    previous=json.loads((ROOT/'art/animation/source/fluid'/UNIT/'reviewed_handoff.json').read_text(encoding='utf-8'))['units'][0];candidate=combine(previous,entry);candidate['preserved_accepted_clips']=previous.get('preserved_accepted_clips',[])
    target=ROOT/'.artifacts/worldroot_move_h3';target.mkdir(parents=True,exist_ok=True);write(target/'combined_handoff.json',dict(schema_version=1,units=[candidate]))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('verb',choices=['prepare','verify','submit','status','collect','process','review','build']);args=p.parse_args()
    if args.verb=='prepare':prepare();verify()
    elif args.verb=='status':status(OUT,URL)
    elif args.verb=='collect':collect(OUT,URL)
    else:globals()[args.verb]()
