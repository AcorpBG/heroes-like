"""Preserved Millstone Slinger H3 take; see selection/rejection and root README."""
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
from scipy.ndimage import label, distance_transform_edt

ROOT = next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists())
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT/'tools'))
from trial_video_creature_animation import collect, request, status, node, write
from integrate_fluid_creature_animation import source_pose
from publish_fluid_creature_animation import combine

UNIT = 'unit_neutral_millstone_slingers'
URL = 'http://127.0.0.1:8189'
ANCHOR = [480, 475]
INPUT_SCALE = .95
RUNTIME_SCALE = .6
PROMPT = 'Locked orthographic fantasy strategy sprite camera. Keep this exact adult female Millstone Slinger: brown hair in small bun, green cloth headband and neck scarf, off-white rolled-sleeve tunic, loose moss-green trousers, brown lace-up leather boots, brown forearm bracers and apron, belt pouches of gray stones, diagonal leather bandolier with gray stones. Face and body remain three-quarter RIGHT-facing. Exactly two arms, two hands and two legs. ONE plain brown leather sling with two flexible cords and one small leather cup belongs only to her image-left hand; no bow, staff, shield, sword or extra limbs. All straps and pouches remain attached. One non-magical support/rally signal, then full recovery. Both boots stay planted. Image-left sling hand stays low holding the same loaded sling beside her thigh. Free image-right arm lifts from belt to shoulder, elbow extends upward, open palm signals allies overhead as in middle guide, hold briefly, then elbow bends and hand lowers back to the same ready position. Visible independent shoulder, elbow, wrist and finger movement, modest upper-body weight shift. This is a practical rally hand signal, not magic or an attack. No glows, particles, new objects or thrown stones. Complete one signal within first three seconds, then settle. Fixed body scale and ground reference, no camera motion, pan, zoom or perspective change. Entire head, both hands, all sling cords and both boots stay within frame. Perfectly flat PURE MAGENTA RGB(255,0,255) background, no floor, shadows, gradients, text, scenery, motion blur or translucent ghosting.'


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def prepare():
    if (OUT/'submission.json').exists():
        raise RuntimeError('Never overwrite a submitted original')
    recipe = json.loads((ROOT/'art/animation/source/fluid/unit_neutral_millstone_slingers/reviewed_handoff.json').read_bytes())['units'][0]
    originals=json.loads((ROOT/'art/units/source/generated/fluid_animation/batch_d/unit_neutral_millstone_slingers/handoff.json').read_bytes())['units'][0]['frames']
    contacts = [next(f for f in originals if f['name']=='cast_00'),next(f for f in originals if f['name']=='cast_03')]
    refs = []
    for original,filename in zip(contacts,['input_magenta.png','peak_magenta.png']):
        frame = original.copy()
        original_scale = frame['scale']
        assert .5 < original_scale < .7
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
        '4':node('LoadImage',image='millstone_cast_input.png'),
        '5':node('MiniMaxH3ImageToVideo',clip=['2',0],vae=['3',0],prompt=PROMPT,width=960,height=544,length=124,first_frame=['4',0],last_frame=['4',0]),
        '16':node('LoadImage',image='millstone_peak.png'),
        '17':node('MiniMaxH3AddGuide',positive=['5',0],latent=['5',1],frame_idx=42,vae=['3',0],image=['16',0]),
        '6':node('BasicGuider',model=['1',0],conditioning=['17',0]),
        '7':node('RandomNoise',noise_seed=2026092438),
        '8':node('KSamplerSelect',sampler_name='res_multistep'),
        '9':node('BasicScheduler',model=['1',0],scheduler='simple',steps=20,denoise=1.0),
        '10':node('SamplerCustomAdvanced',noise=['7',0],guider=['6',0],sampler=['8',0],sigmas=['9',0],latent_image=['5',1]),
        '11':node('VAEDecode',samples=['10',0],vae=['3',0]),
        '13':node('CreateVideo',images=['11',0],fps=24,bit_depth=8),
        '14':node('SaveVideo',video=['13',0],filename_prefix='millstone_h3/cast_v1/original',**{'format':'mp4','format.codec':'h264'}),
        '15':node('SaveImage',images=['11',0],filename_prefix='millstone_h3/cast_v1/frames/decoded'),
    }
    write(OUT/'workflow_api.json',graph)


def verify():
    graph=json.loads((OUT/'workflow_api.json').read_text(encoding='utf-8'))
    assert graph['5']['inputs']['first_frame']==graph['5']['inputs']['last_frame']==['4',0]
    assert graph['6']['inputs']['conditioning']==['17',0]
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
        boundary='----MillstoneH3H3'
        data=(f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="millstone_cast_{filename}"\r\nContent-Type: image/png\r\n\r\n'.encode()+(OUT/filename).read_bytes()+f'\r\n--{boundary}--\r\n'.encode())
        req=urllib.request.Request(URL+'/upload/image',data=data,headers={'Content-Type':'multipart/form-data; boundary='+boundary})
        with urllib.request.urlopen(req,timeout=60) as response:r=json.load(response)
        uploaded[key]=r;graph[key]['inputs']['image']='/'.join(s for s in [r.get('subfolder',''),r['name']] if s)
    write(OUT/'workflow_api.json',graph)
    started=time.time();r=request(URL,'/prompt',dict(prompt=graph,client_id='millstone_cast_h3'))
    write(OUT/'submission.json',dict(**r,started_unix=started,url=URL,uploaded=uploaded));print(json.dumps(r))


def key(rgb):
 a=np.asarray(rgb,dtype=np.float32)
 tiles=[a[:24,:24],a[:24,-24:],a[-24:,:24],a[-24:,-24:]]
 corners=np.array([np.median(t.reshape(-1,3),axis=0) for t in tiles]);bg=np.median(corners,axis=0)
 spread=float(np.max(np.linalg.norm(corners-bg,axis=1)))
 if spread>10:raise ValueError(f'unsafe spatially varying plate {bg}; spread={spread}')
 if max(bg)-min(bg)<80 or max(bg)<180:raise ValueError(f'unsafe nondistinct background {bg}')
 dist=np.linalg.norm(a-bg,axis=2)
 subject=dist>=90
 interior=distance_transform_edt(subject)>=3
 nearest=distance_transform_edt(~interior,return_distances=False,return_indices=True)
 fg=a[nearest[0],nearest[1]]
 # Solve edge alpha using the measured plate's two high channels minus its
 # low channel, relative to nearest three-pixel-deep original foreground.
 # This removes plate-color fringe without recoloring solid character pixels.
 order=np.argsort(bg);lo=int(order[0]);hi=[int(order[1]),int(order[2])]
 chroma=lambda v:np.minimum(v[...,hi[0]],v[...,hi[1]])-v[...,lo]
 bc=chroma(bg);c=chroma(a);fc=chroma(fg)
 alpha=np.clip((bc-c)/np.maximum(bc-fc,1),0,1)
 alpha[interior]=1;alpha[dist<=12]=0
 color=np.clip((a-(1-alpha[:,:,None])*bg)/np.maximum(alpha[:,:,None],.001),0,255)
 out=np.dstack([color,alpha*255]).astype('uint8');out[out[:,:,3]<8]=0
 mask=out[:,:,3]>=8;labels,n=label(mask,structure=np.ones((3,3),dtype=np.uint8));confident=np.unique(labels[out[:,:,3]>=128]);keep=np.zeros(n+1,dtype=bool);keep[confident]=True;keep[0]=False;out[~keep[labels]]=0
 assert np.array_equal(out[interior,:3],a[interior].astype('uint8'))
 return Image.fromarray(out,'RGBA'),dict(background_rgb=[round(float(v),3) for v in bg],corner_median_spread=round(spread,3),mode='flat_plate_local_chroma_edge_unmix',solid_interior_rgb_preserved=True,interior_depth=3,subject_distance=90,background_distance=12,component_rule='alpha>=8 components retained only with alpha>=128 source pixels')


def process():
    (OUT/'matte').mkdir(exist_ok=True);hashes=[];meta=[]
    with av.open(str(OUT/'original_lossless.mkv')) as video:
        for i,frame in enumerate(video.decode(video=0)):
            im,details=key(frame.to_image().convert('RGB'))
            p=OUT/'matte'/f'rgba_{i:03}.png';im.save(p);hashes.append(sha(p));meta.append(details)
    assert len(hashes)==124
    write(OUT/'matte.json',dict(frames=124,fps=24,rgba_sha256=hashes,background_frames=meta,recipe='Per-frame flat-plate four-corner verification spread<=10 and distinct saturated background. RGB distance>=90 subject mask; three-pixel-deep interior pixels preserved exactly; distance<=12 removed; edge alpha solved from measured plate high-pair-minus-low chroma relative to nearest original interior RGB, followed by plate unmix. Opaque-rooted component cleanup, no geometry editing/alignment. Handles observed magenta/yellow/cyan plate changes without shifting or recoloring solid clothing.'))


def review():
    target=ROOT/'.artifacts/millstone_h3/cast_v1';target.mkdir(parents=True,exist_ok=True)
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
    entry=dict(unit_id=UNIT,reference_height=256,source_facing='right',frames=frames,alpha_noise_cutoff=0,clips={'cast':dict(indices=list(range(len(frames))),frame_msec=selection['frame_msec'],loop=False,static_frame=0)},source_scale_reason='Original source anatomical scales retained per painting: accepted ready .59, walk .57, support .6, hit .55, ranged .58. Input scale is source scale/.6; extraction fixed .6, anatomical anchors mapped to480,475. No per-frame normalization.',provenance=provenance,visual_review=dict(status='pending',notes=selection['review_note']))

    if 'contact_frame' in selection: entry['clips']['cast']['contact_frame']=selection['contact_frame']
    if 'projectile_travel_msec' in selection: entry['clips']['cast']['projectile_travel_msec']=selection['projectile_travel_msec']
    write(OUT/'handoff.json',dict(schema_version=1,units=[entry]))
    previous=json.loads((ROOT/'art/animation/source/fluid'/UNIT/'reviewed_handoff.json').read_text(encoding='utf-8'))['units'][0];candidate=combine(previous,entry);candidate['preserved_accepted_clips']=previous.get('preserved_accepted_clips',[])
    target=ROOT/'.artifacts/millstone_h3/cast_v1';target.mkdir(parents=True,exist_ok=True);write(target/'combined_handoff.json',dict(schema_version=1,units=[candidate]))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('verb',choices=['prepare','verify','submit','status','collect','process','review','build']);args=p.parse_args()
    if args.verb=='prepare':prepare();verify()
    elif args.verb=='status':status(OUT,URL)
    elif args.verb=='collect':collect(OUT,URL)
    else:globals()[args.verb]()
