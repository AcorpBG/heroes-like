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

UNIT = 'unit_neutral_reefbolt_crews'
URL = 'http://127.0.0.1:8189'
ANCHOR = [480, 480]
INPUT_SCALE = .42
RUNTIME_SCALE = .225 / INPUT_SCALE
PROMPT = '''Locked orthographic three-quarter RIGHT-facing fantasy strategy sprite camera. Animate the exact two-person Reefbolt Crew carrying its lifted tripod-mounted crossbow and bolt basket, walking IN PLACE in a seamless reciprocal two-step cycle. EXACTLY TWO humans, FOUR human legs and FOUR human arms total. Tall bearded gunner behind and on image RIGHT wears teal brimmed helmet with brass star, teal naval coat, black trousers, brown boots and gloves. Shorter braided woman on image LEFT wears teal bandana and coat, dark trousers and brown boots, with the full bolt basket strapped at her back/left hip. Preserve both distinct faces and costumes. The man holds the crossbow firmly with BOTH hands in the same positions: rear handle and forward stock. The woman holds the front tripod beam firmly with BOTH hands exactly as shown. These are load-bearing grips, never release, multiply or swap them. All THREE wooden rope-bound tripod legs stay rigidly joined to their original central hub and LIFTED CLEAR of the ground throughout walking. The crossbow stays pointed RIGHT, with the same brass crank, wooden stock, bow arms, string and coral-tipped bolt; no firing, reloading, changing bolt count or weapon transformation. The basket and its contents move attached to her body, never float separately. Both crew members take small coordinated alternating steps: first lower their raised feet, transfer weight onto those boots, lift the opposite boots from behind, bend knees and pass beneath hips, extend forward and plant; then exchange roles and complete the next step to return to the starting pose. Both left and right human legs must each take a turn reaching, supporting, lifting and passing. No repeated same-leg shuffle, no sliding the pair across frame and no bouncing without leg articulation. Keep four leg attachments and lengths, face shape, torso size, weapon dimensions and camera exactly consistent. Natural subtle shoulder/elbow compliance under the shared weight, and slight coat and basket sway only. Do not swing tripod legs like creature limbs. Do not plant or drag the tripod feet. Whole team remains centered for engine-driven travel; no turning, zoom, perspective change or camera motion. Keep all boots, bolt tip and tripod inside frame. End in the first pose for a seamless loop. Background remains perfectly flat SOLID MAGENTA RGB(255,0,255) throughout; no floor, cast shadow, scenery, smoke, effects, glow, text, motion blur or added objects.'''


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def prepare():
    if (OUT/'submission.json').exists():
        raise RuntimeError('Never overwrite a submitted original')
    source_dir = ROOT/'art/animation/source/poses'/UNIT
    recipe = json.loads((source_dir/'packing.json').read_text(encoding='utf-8'))
    refs = []
    for name, filename in [('crew_carry_passing','input_magenta.png'),('crew_carry_opposite_attempt','middle_magenta.png')]:
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
        '4':node('LoadImage',image='reefbolt_walk_input.png'),
        '5':node('MiniMaxH3ImageToVideo',clip=['2',0],vae=['3',0],prompt=PROMPT,width=960,height=544,length=124,first_frame=['4',0],last_frame=['4',0]),
        '6':node('BasicGuider',model=['1',0],conditioning=['17',0]),
        '7':node('RandomNoise',noise_seed=2026092413),
        '8':node('KSamplerSelect',sampler_name='res_multistep'),
        '9':node('BasicScheduler',model=['1',0],scheduler='simple',steps=20,denoise=1.0),
        '10':node('SamplerCustomAdvanced',noise=['7',0],guider=['6',0],sampler=['8',0],sigmas=['9',0],latent_image=['5',1]),
        '11':node('VAEDecode',samples=['10',0],vae=['3',0]),
        '13':node('CreateVideo',images=['11',0],fps=24,bit_depth=8),
        '14':node('SaveVideo',video=['13',0],filename_prefix='reefbolt_move_h3/original',**{'format':'mp4','format.codec':'h264'}),
        '15':node('SaveImage',images=['11',0],filename_prefix='reefbolt_move_h3/frames/decoded'),
        '16':node('LoadImage',image='reefbolt_walk_middle.png'),
        '17':node('MiniMaxH3AddGuide',positive=['5',0],latent=['5',1],vae=['3',0],frame_idx=61,image=['16',0]),
    }
    write(OUT/'workflow_api.json',graph)


def verify():
    graph=json.loads((OUT/'workflow_api.json').read_text(encoding='utf-8'))
    assert graph['5']['inputs']['first_frame']==graph['5']['inputs']['last_frame']==['4',0]
    assert graph['6']['inputs']['conditioning']==['17',0]
    assert graph['10']['inputs']['latent_image']==['5',1]
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
    for key,filename in [('4','input_magenta.png'),('16','middle_magenta.png')]:
        boundary='----ReefboltWalkH3'
        data=(f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="reefbolt_walk_{filename}"\r\nContent-Type: image/png\r\n\r\n'.encode()+(OUT/filename).read_bytes()+f'\r\n--{boundary}--\r\n'.encode())
        req=urllib.request.Request(URL+'/upload/image',data=data,headers={'Content-Type':'multipart/form-data; boundary='+boundary})
        with urllib.request.urlopen(req,timeout=60) as response:r=json.load(response)
        uploaded[key]=r;graph[key]['inputs']['image']='/'.join(s for s in [r.get('subfolder',''),r['name']] if s)
    write(OUT/'workflow_api.json',graph)
    started=time.time();r=request(URL,'/prompt',dict(prompt=graph,client_id='reefbolt_walk_h3'))
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
    target=ROOT/'.artifacts/reefbolt_move_h3';target.mkdir(parents=True,exist_ok=True)
    for part in range(2):
        sheet=Image.new('RGB',(1440,1600),(35,45,32));draw=ImageDraw.Draw(sheet)
        for j,i in enumerate(range(part*62,(part+1)*62)):
            x,y=j%8*180,j//8*200
            if j%2:sheet.paste((218,211,193),(x,y,x+180,y+200))
            im=Image.open(OUT/'matte'/f'rgba_{i:03}.png').crop((235,45,745,510));im.thumbnail((174,178),Image.Resampling.LANCZOS);sheet.paste(im,(x+(180-im.width)//2,y+20),im);draw.text((x+5,y+4),str(i),fill=(160,110,65))
        sheet.save(target/f'chronological_{part}.png')


def build():
    selection=json.loads((OUT/'selection.json').read_text(encoding='utf-8'));indices=selection['source_frames'];assert len(indices)>=8 and len(indices)==len(set(indices))
    frames=[dict(name=f'move_h3_{i:03}',clip='move',source=(OUT/'matte'/f'rgba_{i:03}.png').relative_to(ROOT).as_posix(),rects=[[0,0,960,544]],anchor=ANCHOR,scale=RUNTIME_SCALE,alpha_noise_cutoff=0,video_frame=i,video_time_seconds=i/24) for i in indices]
    provenance={n:dict(path=(OUT/n).relative_to(ROOT).as_posix(),sha256=sha(OUT/n)) for n in ['original_lossless.mkv','original.json','workflow_api.json','prompt.txt','reference.json','matte.json']}
    entry=dict(unit_id=UNIT,reference_height=256,source_facing='right',frames=frames,alpha_noise_cutoff=0,clips={'move':dict(indices=list(range(len(frames))),frame_msec=selection['frame_msec'],loop=True,static_frame=0)},source_scale_reason='Original carry pose runtime scale .225 / video guide scale .42, fixed anchor480,480; original source anchors retained; no per-pose normalization.',provenance=provenance,visual_review=dict(status='pending',notes=selection['review_note']))
    write(OUT/'handoff.json',dict(schema_version=1,units=[entry]))
    previous=json.loads((ROOT/'art/animation/source/fluid'/UNIT/'reviewed_handoff.json').read_text(encoding='utf-8'))['units'][0];candidate=combine(previous,entry);candidate['preserved_accepted_clips']=previous.get('preserved_accepted_clips',[])
    target=ROOT/'.artifacts/reefbolt_move_h3';target.mkdir(parents=True,exist_ok=True);write(target/'combined_handoff.json',dict(schema_version=1,units=[candidate]))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('verb',choices=['prepare','verify','submit','status','collect','process','review','build']);args=p.parse_args()
    if args.verb=='prepare':prepare();verify()
    elif args.verb=='status':status(OUT,URL)
    elif args.verb=='collect':collect(OUT,URL)
    else:globals()[args.verb]()
