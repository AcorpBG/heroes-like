"""Bounded local ComfyUI I2V trial; never edits the live animation catalogs.

Prepare a reproducible chroma-backed first/last-frame workflow, submit once,
and retrieve generated originals for comparison with accepted artwork.
"""
import argparse
import hashlib
import io
import json
import time
import urllib.request
import urllib.parse
from pathlib import Path

import numpy as np
from PIL import Image
from PIL import ImageDraw

ROOT = Path(__file__).resolve().parents[1]
UNIT = 'unit_thornwake_seedshield_wardens_veteran'
DEFAULT_OUTPUT = ROOT / 'art/units/source/generated/video_trials/heartseed_h3_idle'
PROMPT = (
    'A locked-camera fantasy strategy game character idle animation on a perfectly flat '
    'solid magenta RGB(255,0,255) background. The supplied first and last images show the '
    'same original Heartseed Warden. Preserve this exact painted wooden creature, antlered '
    'ivory mask, bark limbs, overlapping green leaf armor, white blossoms, amber seedbud '
    'staff in its near RIGHT hand on image LEFT, and amber heart-shaped shield on its '
    'far LEFT arm on image RIGHT. Exactly two arms and two legs throughout. Animate one '
    'controlled idle cycle: the shield arm visibly lifts the shield from waist to chest '
    'then lowers it; the staff wrist gently rolls the staff a few degrees and regrips it; '
    'shoulders breathe softly and small leaves settle. Hands, wrists and elbows really '
    'articulate. Return smoothly to precisely the starting ready pose at the end. '
    'Both root feet stay planted on the exact same pixels. Staff remains a rigid single '
    'straight shaft of constant length, held by the same hand; shield stays attached to '
    'the same forearm. No walking, turning, attack, pose flip, extra limbs or equipment '
    'morphing. Fixed three-quarter right-facing orthographic camera; no pan, zoom, cuts, '
    'perspective change or whole-body sliding. Entire antlers, staff and root feet remain '
    'inside frame. Uniform flat magenta only, no ground, cast shadow, haze, particles, '
    'scenery, gradients, text, music or speech.'
)


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def request(url, route, data=None):
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(url + route, data=body, headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=120) as response:
        return json.load(response)


def node(kind, **inputs):
    return {'class_type': kind, 'inputs': inputs}


def prepare(out,mid_guide=False):
    out.mkdir(parents=True, exist_ok=True)
    if (out/'submission.json').exists():
        raise RuntimeError('Keep submitted provenance intact; choose a new output directory')
    manifest = json.loads((ROOT / 'content/unit_animation_manifest.json').read_text(encoding='utf-8'))
    row = next(r for r in manifest['items'] if r['unit_id'] == UNIT)
    source = ROOT / 'art/units/source/generated/fluid_animation/batch_b' / UNIT
    handoff = json.loads((source / 'handoff.json').read_text(encoding='utf-8'))['units'][0]
    frame = handoff['frames'][handoff['clips']['idle']['indices'][0]]
    original = Image.open(ROOT / frame['source']).convert('RGBA')
    selected = Image.new('RGBA', original.size)
    for x0, y0, x1, y1 in frame['rects']:
        selected.paste(original.crop((x0,y0,x1,y1)), (x0,y0))
    rgba = np.array(selected)
    rgba[rgba[:,:,3] < frame['alpha_noise_cutoff']] = 0
    selected = Image.fromarray(rgba)
    # A single source-wide scale; exact anatomy and framing preserved thereafter.
    scale = 1.12
    subject = selected.resize((round(selected.width*scale), round(selected.height*scale)), Image.Resampling.LANCZOS)
    anchor = [480, 486]
    offset = [round(anchor[0]-frame['anchor'][0]*scale), round(anchor[1]-frame['anchor'][1]*scale)]
    rgba_frame = Image.new('RGBA', (960,544))
    rgba_frame.alpha_composite(subject, offset)
    rgba_frame.save(out/'reference_rgba.png')
    backed = Image.new('RGBA', rgba_frame.size, (255,0,255,255))
    backed.alpha_composite(rgba_frame)
    backed.convert('RGB').save(out/'input_magenta.png')
    prompt=PROMPT
    if mid_guide:
        prompt+=' Important prop continuity: the staff has ONLY ONE glowing amber seedbud at the TOP. Its BOTTOM is a plain blunt dark wooden end, never a second seedbud, blade, flame or light. Never turn it into a double-ended staff. Preserve the supplied middle guide pose exactly at the midpoint, with raised shield and the same straight staff silhouette. Smooth physical motion between the three supplied poses.'
    (out/'prompt.txt').write_text(prompt+'\n', encoding='utf-8')
    write(out/'accepted_baseline.json', row)
    write(out/'reference.json', dict(unit_id=UNIT,source=frame['source'],source_sha256=hashlib.sha256((ROOT/frame['source']).read_bytes()).hexdigest(),source_frame=frame,canvas=[960,544],input_source_scale=scale,ground_anchor=anchor,runtime_source_scale=frame['scale'],input_sha256=hashlib.sha256((out/'input_magenta.png').read_bytes()).hexdigest()))
    graph = {
        '1':node('UNETLoader',unet_name='minimax_h3_fl2va_pruned_int8_convrot.safetensors',weight_dtype='default'),
        '2':node('CLIPLoader',clip_name='qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors',type='minimax',device='default'),
        '3':node('VAELoader',vae_name='minimax_h3_video_vae_int8_convrot.safetensors'),
        '4':node('LoadImage',image='heartseed_h3_idle_input.png'),
        '5':node('MiniMaxH3ImageToVideo',clip=['2',0],vae=['3',0],prompt=prompt,width=960,height=544,length=124,first_frame=['4',0],last_frame=['4',0]),
        '6':node('BasicGuider',model=['1',0],conditioning=['5',0]),
        '7':node('RandomNoise',noise_seed=24092484),
        '8':node('KSamplerSelect',sampler_name='res_multistep'),
        '9':node('BasicScheduler',model=['1',0],scheduler='simple',steps=20,denoise=1.0),
        '10':node('SamplerCustomAdvanced',noise=['7',0],guider=['6',0],sampler=['8',0],sigmas=['9',0],latent_image=['5',1]),
        '11':node('VAEDecode',samples=['10',0],vae=['3',0]),
        '13':node('CreateVideo',images=['11',0],fps=24,bit_depth=8),
        '14':node('SaveVideo',video=['13',0],filename_prefix='heartseed_h3_idle_trial/original',**{'format':'mp4','format.codec':'h264'}),
        '15':node('SaveImage',images=['11',0],filename_prefix='heartseed_h3_idle_trial/frames/decoded'),
    }
    if mid_guide:
        middle=handoff['frames'][handoff['clips']['idle']['indices'][2]]
        original_mid=Image.open(ROOT/middle['source']).convert('RGBA')
        selected_mid=Image.new('RGBA',original_mid.size)
        for x0,y0,x1,y1 in middle['rects']:
            selected_mid.paste(original_mid.crop((x0,y0,x1,y1)),(x0,y0))
        rgba_mid=np.array(selected_mid);rgba_mid[rgba_mid[:,:,3]<middle['alpha_noise_cutoff']]=0
        resized=Image.fromarray(rgba_mid).resize((round(selected_mid.width*scale),round(selected_mid.height*scale)),Image.Resampling.LANCZOS)
        canvas=Image.new('RGBA',(960,544),(255,0,255,255))
        canvas.alpha_composite(resized,(round(anchor[0]-middle['anchor'][0]*scale),round(anchor[1]-middle['anchor'][1]*scale)))
        canvas.convert('RGB').save(out/'middle_magenta.png')
        graph['16']=node('LoadImage',image='heartseed_h3_idle_middle.png')
        graph['17']=node('MiniMaxH3AddGuide',positive=['5',0],latent=['5',1],vae=['3',0],frame_idx=61,image=['16',0])
        graph['6']['inputs']['conditioning']=['17',0]
        graph['14']['inputs']['filename_prefix']='heartseed_h3_idle_guided_trial/original'
        graph['15']['inputs']['filename_prefix']='heartseed_h3_idle_guided_trial/frames/decoded'
        write(out/'middle_reference.json',dict(source_frame=middle,canvas=[960,544],input_source_scale=scale,ground_anchor=anchor,input_sha256=hashlib.sha256((out/'middle_magenta.png').read_bytes()).hexdigest()))
    write(out/'workflow_api.json',graph)
    print('Prepared 960x544, 124-frame, 20-step first/last-frame trial:',out)


def submit(out,url):
    if (out/'submission.json').exists():
        raise RuntimeError('Already submitted; inspect status instead of enqueueing a duplicate')
    queue=request(url,'/queue')
    if queue['queue_running'] or queue['queue_pending']:
        raise RuntimeError('ComfyUI is busy; leave other work untouched')
    def upload(path,name):
        boundary='----HeartseedH3AnimationTrial'
        data=(f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="{name}"\r\nContent-Type: image/png\r\n\r\n'.encode()+path.read_bytes()+f'\r\n--{boundary}--\r\n'.encode())
        req=urllib.request.Request(url+'/upload/image',data=data,headers={'Content-Type':'multipart/form-data; boundary='+boundary})
        with urllib.request.urlopen(req,timeout=60) as response:return json.load(response)
    uploaded=upload(out/'input_magenta.png',out.name+'_input.png')
    graph=json.loads((out/'workflow_api.json').read_text(encoding='utf-8'))
    graph['4']['inputs']['image']='/'.join(x for x in [uploaded.get('subfolder',''),uploaded['name']] if x)
    if '16' in graph:
        mid_upload=upload(out/'middle_magenta.png',out.name+'_middle.png')
        graph['16']['inputs']['image']='/'.join(x for x in [mid_upload.get('subfolder',''),mid_upload['name']] if x)
        uploaded['middle']=mid_upload
    write(out/'workflow_api.json',graph)
    started=time.time();result=request(url,'/prompt',{'prompt':graph,'client_id':'heartseed_h3_idle_trial'})
    write(out/'submission.json',dict(**result,started_unix=started,url=url,uploaded=uploaded))
    print(json.dumps(result))


def status(out,url):
    submitted=json.loads((out/'submission.json').read_text(encoding='utf-8'))
    pid=submitted['prompt_id'];history=request(url,'/history/'+pid)
    if pid not in history:
        queue=request(url,'/queue')
        print(json.dumps(dict(state='running',elapsed_seconds=round(time.time()-submitted['started_unix']),running=len(queue['queue_running']),pending=len(queue['queue_pending']))))
        return
    result=history[pid];write(out/'generation_history.json',result)
    print(json.dumps(dict(status=result['status'],outputs={k:{t:len(v) if isinstance(v,list) else v for t,v in val.items()} for k,val in result['outputs'].items()})))


def fetch_bytes(url, item):
    query=urllib.parse.urlencode({k:item[k] for k in ('filename','subfolder','type') if k in item})
    with urllib.request.urlopen(url+'/view?'+query,timeout=120) as response:
        return response.read()


def collect(out,url):
    """Keep decoded original pixels losslessly, independently of MP4 compression."""
    import av
    result=json.loads((out/'generation_history.json').read_text(encoding='utf-8'))
    if result['status']['status_str']!='success':raise RuntimeError('Generation has not succeeded')
    images=result['outputs']['15']['images']
    assert len(images)==124,len(images)
    target=out/'original_lossless.mkv'
    if target.exists():raise RuntimeError('Original already collected; use process')
    with av.open(str(target),'w') as container:
        stream=container.add_stream('ffv1',rate=24)
        stream.width=960;stream.height=544;stream.pix_fmt='bgr0'
        decoded_hashes=[]
        for item in images:
            im=Image.open(io.BytesIO(fetch_bytes(url,item))).convert('RGB')
            decoded_hashes.append(hashlib.sha256(im.tobytes()).hexdigest())
            frame=av.VideoFrame.from_image(im)
            for packet in stream.encode(frame):container.mux(packet)
        for packet in stream.encode():container.mux(packet)
    # Preserve the service's original viewing copy too.
    for items in result['outputs'].get('14',{}).values():
        if isinstance(items,list):
            for item in items:
                if isinstance(item,dict) and str(item.get('filename','')).endswith('.mp4'):
                    (out/'original.mp4').write_bytes(fetch_bytes(url,item))
    write(out/'original.json',dict(frames=124,fps=24,size=[960,544],lossless_codec='ffv1/bgr0',sha256=hashlib.sha256(target.read_bytes()).hexdigest(),decoded_rgb_sha256=decoded_hashes,workflow_sha256=hashlib.sha256((out/'workflow_api.json').read_bytes()).hexdigest(),source='ComfyUI decoded PNG frames, encoded losslessly'))
    print('Collected 124 original frames losslessly')


def matte(rgb):
    """Chroma matte + unmix; no invented motion or per-frame repositioning.

    Magenta is absent from this creature. Dark/green/amber/ivory material remains
    opaque; the matte removes the deliberately supplied background and spill.
    """
    a=np.asarray(rgb,dtype=np.float32)
    corners=np.concatenate([a[:20,:20].reshape(-1,3),a[:20,-20:].reshape(-1,3),a[-20:,:20].reshape(-1,3),a[-20:,-20:].reshape(-1,3)])
    bg=np.median(corners,axis=0)
    chroma=np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1]
    bg_chroma=min(bg[0],bg[2])-bg[1]
    if bg_chroma<150:raise ValueError('Background is no longer a usable magenta key')
    alpha=np.clip((bg_chroma-chroma-5)/(bg_chroma-29),0,1)
    color=np.clip((a-(1-alpha[:,:,None])*bg)/np.maximum(alpha[:,:,None],.001),0,255)
    excess=np.maximum(0,np.minimum(color[:,:,0],color[:,:,2])-color[:,:,1]-8)
    edge=(alpha<.98)
    color[:,:,0]-=excess*edge;color[:,:,2]-=excess*edge
    result=np.dstack([np.clip(color,0,255),alpha*255]).astype('uint8')
    result[result[:,:,3]<3]=0
    # This idle has one connected subject and no detached props or particles.
    # Remove isolated key noise, retaining a 3px feather around the subject.
    from scipy import ndimage
    labels,count=ndimage.label(result[:,:,3]>38)
    if count:
        areas=np.bincount(labels.ravel());areas[0]=0
        subject=labels==areas.argmax()
        keep=ndimage.binary_dilation(subject,iterations=3)
        result[~keep]=0
    return Image.fromarray(result)


def accepted_frames(row):
    atlas=Image.open(ROOT/row['pose_sheet'].removeprefix('res://')).convert('RGBA')
    w=row['pose_frame_size']['width'];h=row['pose_frame_size']['height'];cols=row['pose_columns']
    return [atlas.crop(((i%cols)*w,(i//cols)*h,(i%cols+1)*w,(i//cols+1)*h)) for i in row['pose_clips']['idle']['indices']]


def preview_pose(im,anchor,scale,size=(240,184)):
    result=Image.new('RGBA',size)
    resized=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS)
    result.alpha_composite(resized,(round(size[0]/2-anchor[0]*scale),round(158-anchor[1]*scale)))
    return result


def process(out):
    import av
    with av.open(str(out/'original_lossless.mkv')) as video:
        originals=[frame.to_image().convert('RGB') for frame in video.decode(video=0)]
    assert len(originals)==124
    reference=json.loads((out/'reference.json').read_text(encoding='utf-8'))
    keyed=[matte(im) for im in originals]
    # Retain 12fps observed samples. No interpolation or last-to-first crossfade.
    samples=list(range(0,len(keyed),2));frames=[keyed[i] for i in samples]
    folder=out/'frames';folder.mkdir(exist_ok=True)
    for i,frame in zip(samples,frames):frame.save(folder/f'idle_{i:03d}.png')
    row=json.loads((out/'accepted_baseline.json').read_text(encoding='utf-8'))
    accepted=accepted_frames(row)
    old_anchor=[row['pose_frame_size']['width']/2,row['pose_frame_size']['height']-row['pose_ground_margin']]
    ratio=reference['runtime_source_scale']/reference['input_source_scale']
    a=[preview_pose(im,old_anchor,.5) for im in accepted]
    b=[preview_pose(im,reference['ground_anchor'],ratio*.5) for im in frames]
    # Lossless animated viewing deliverables, including original speed and 2x.
    def panel(left,right,label):
        canvas=Image.new('RGBA',(480,220),(34,44,28,255));d=ImageDraw.Draw(canvas)
        d.text((10,8),'ACCEPTED: 8 poses / 1.24s',fill='white')
        d.text((250,8),label,fill='white')
        canvas.alpha_composite(left,(0,26));canvas.alpha_composite(right,(240,26))
        d.line((15,184,225,184),fill=(85,100,61));d.line((255,184,465,184),fill=(85,100,61))
        return canvas.convert('RGB')
    for speed in (1,2):
        sequence=[panel(a[int((i/12/speed)/.155)%8],b[i],f'H3: 62 frames / {len(b)/12/speed:.2f}s') for i in range(len(b))]
        sequence[0].save(out/f'comparison_{speed}x.webp',save_all=True,append_images=sequence[1:],duration=round(1000/12/speed),loop=0,lossless=True)
    # At actual duration, full 24fps alpha output for temporal edge inspection.
    keyed[0].save(out/'transparent_full.webp',save_all=True,append_images=keyed[1:],duration=42,loop=0,lossless=True)
    stride=max(1,len(b)//12);sheet=Image.new('RGB',(960,660),(34,44,28))
    for n,i in enumerate(range(0,len(b),stride)):
        if n>=12:break
        cell=Image.new('RGBA',(240,220),(34,44,28,255));cell.alpha_composite(b[i],(0,26))
        ImageDraw.Draw(cell).text((8,8),f'frame {samples[i]} / {samples[i]/24:.2f}s',fill='white')
        sheet.paste(cell.convert('RGB'),((n%4)*240,(n//4)*220))
    sheet.save(out/'phase_comparison.png')
    bbox=[im.getchannel('A').point(lambda x:255 if x>127 else 0).getbbox() for im in keyed]
    rgba=np.array(Image.open(out/'reference_rgba.png').convert('RGBA'),dtype=np.int16)
    keyed_reference=np.array(matte(Image.open(out/'input_magenta.png').convert('RGB')),dtype=np.int16)
    mask=rgba[:,:,3]>240
    checks=dict(frame_count=len(keyed),selected_frames=samples,source_fps=24,candidate_fps=12,body_scale_fixed=ratio,ground_anchor=reference['ground_anchor'],opaque_bounds=bbox,reference_opaque_rgb_mae=float(np.abs(rgba[:,:,:3]-keyed_reference[:,:,:3])[mask].mean()),reference_opaque_alpha_mae=float(np.abs(rgba[:,:,3]-keyed_reference[:,:,3])[mask].mean()),loop_rgba_mae=float(np.abs(np.asarray(keyed[0],dtype=float)-np.asarray(keyed[-1],dtype=float)).mean()),live_catalogs_modified=False,acceptance='pending_visual_review')
    write(out/'extraction.json',checks)
    frame_specs=[dict(name=f'idle_video_{i:03d}',clip='idle',source=(folder/f'idle_{i:03d}.png').resolve().relative_to(ROOT).as_posix(),rects=[[0,0,960,544]],anchor=reference['ground_anchor'],scale=ratio,alpha_noise_cutoff=0,video_frame=i,video_time_seconds=i/24) for i in samples]
    entry=dict(unit_id=UNIT,reference_height=row['pose_reference_height'],source_facing=row['pose_source_facing'],frames=frame_specs,clips={'idle':dict(indices=list(range(len(samples))),frame_msec=83,loop=True,static_frame=0)},source_scale_reason='Constant input-to-runtime anatomical scale and one fixed ground anchor for every observed video frame. No stabilization, warping, synthesized frames or per-pose normalization.',provenance=dict(tool='local_comfyui_minimax_h3',source=(out/'original_lossless.mkv').resolve().relative_to(ROOT).as_posix(),source_sha256=hashlib.sha256((out/'original_lossless.mkv').read_bytes()).hexdigest(),workflow=(out/'workflow_api.json').resolve().relative_to(ROOT).as_posix(),matte_recipe='tools/trial_video_creature_animation.py:matte'),visual_review=dict(status='pending',notes='Experimental video candidate; frame count and structural checks do not establish identity continuity. Never publish without explicit visual acceptance.'))
    write(out/'handoff.json',dict(schema_version=1,units=[entry]))
    print(json.dumps({k:v for k,v in checks.items() if k not in ('opaque_bounds','selected_frames')},indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['prepare','submit','status','collect','process'])
    parser.add_argument('--output',type=Path,default=DEFAULT_OUTPUT)
    parser.add_argument('--url',default='http://127.0.0.1:8189')
    parser.add_argument('--mid-guide',action='store_true',help='Pin accepted raised-shield pose at frame61')
    args=parser.parse_args()
    if args.action=='prepare':prepare(args.output,args.mid_guide)
    elif args.action=='submit':submit(args.output,args.url)
    elif args.action=='status':status(args.output,args.url)
    elif args.action=='collect':collect(args.output,args.url)
    else:process(args.output)
