"""Bogplate's original H3 walk cycle; source preparation never publishes assets."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import av
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import label

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').exists())
OUT = Path(__file__).resolve().parent
BASE = OUT
sys.path.insert(0, str(ROOT / 'tools'))
from trial_video_creature_animation import collect, request, status, submit, node, write
from integrate_fluid_creature_animation import source_pose
from publish_fluid_creature_animation import combine

UNIT = 'unit_mireclaw_bogplate_maulers'
URL = 'http://127.0.0.1:8189'
ANCHOR = [480, 490]
INPUT_SCALE = .36
RUNTIME_SCALE = .17 / INPUT_SCALE
PROMPT = '''Locked orthographic three-quarter RIGHT-facing fantasy strategy sprite camera. Animate this exact bulky bearded male Bogplate Mauler WALKING IN PLACE in a complete continuous reciprocal two-leg gait. The first frame is near boot forward and far boot behind. Transfer weight onto the near boot, lift the far heel, bend the far knee and swing the FAR boot past the planted near boot into a forward heel contact. Then transfer weight to the far boot, bend and pass the NEAR knee, and bring the near boot forward to its original contact. Repeat this natural heavy walk twice, ending in exactly the original near-boot-forward stride. Exactly two anatomically distinct legs and boots; each leg alternates forward contact, weight bearing, push-off, bent-knee passing and swing. Do not shuffle only one leg or slide boots without stepping. Keep hips centered at the same horizontal location; no travel or turning. Armor, layered mossy metal shoulders, yellow reed bindings, dark beard and squared helmet remain identical and rigid. The same two hands ALWAYS grip the same two places on the single long straight hammer shaft, with the same rectangular block hammer head on image RIGHT. The hammer remains rigid at constant size and length; arms absorb its weight with subtle elbow articulation, without swinging to attack. Keep head/torso/weapon scale unchanged, only anatomically appropriate vertical weight transfer. Entire helmet, hammer and both boots remain inside the image. Every pixel outside the subject remains perfectly flat uniform pure magenta RGB(255,0,255). No ground plane, floor, shadow, particles, other equipment, extra limbs, motion blur, camera movement, text or background change.'''


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def prepare(guided=False):
    OUT.mkdir(exist_ok=True)
    if (OUT / 'submission.json').exists():
        raise RuntimeError('Submitted original must not be overwritten')
    source_dir = ROOT / 'art/animation/source/poses' / UNIT
    recipe = json.loads((source_dir / 'packing.json').read_text())
    frame = next(f for f in recipe['frames'] if f['name'] == 'move_contact_a').copy()
    frame['source'] = (source_dir / frame['source']).relative_to(ROOT).as_posix()
    frame['scale'] = INPUT_SCALE
    painted, (x, y) = source_pose(frame)
    canvas = Image.new('RGBA', (960, 544))
    canvas.alpha_composite(painted, (ANCHOR[0] + x, ANCHOR[1] + y))
    canvas.save(OUT / 'reference_rgba.png')
    keyed = Image.new('RGBA', canvas.size, (255, 0, 255, 255))
    keyed.alpha_composite(canvas)
    keyed.convert('RGB').save(OUT / 'input_magenta.png')
    row = next(r for r in json.loads((ROOT / 'content/unit_animation_manifest.json').read_text())['items'] if r['unit_id'] == UNIT)
    write(OUT / 'accepted_baseline.json', row)
    write(OUT / 'reference.json', dict(unit_id=UNIT, source_frame=frame, source_sha256=sha(ROOT / frame['source']), input_sha256=sha(OUT / 'input_magenta.png'), input_source_scale=INPUT_SCALE, runtime_source_scale=.17, output_scale=RUNTIME_SCALE, ground_anchor=ANCHOR, canvas=[960,544]))
    prompt = PROMPT
    if guided:
        prompt = prompt.replace('Repeat this natural heavy walk twice, ending in exactly the original near-boot-forward stride.', 'Complete exactly ONE full walk cycle: reach the supplied opposite FAR-boot-forward contact at the middle frame, then return to exactly the original NEAR-boot-forward contact at the end. Both legs must visibly exchange leading roles. The background is an unchanging solid magenta plate; only the man moves, never the background hue.')
    (OUT / 'prompt.txt').write_text(prompt + '\n', encoding='utf-8')
    graph = {
        '1': node('UNETLoader', unet_name='minimax_h3_fl2va_pruned_int8_convrot.safetensors', weight_dtype='default'),
        '2': node('CLIPLoader', clip_name='qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors', type='minimax', device='default'),
        '3': node('VAELoader', vae_name='minimax_h3_video_vae_int8_convrot.safetensors'),
        '4': node('LoadImage', image='bogplate_move_input.png'),
        '5': node('MiniMaxH3ImageToVideo', clip=['2',0], vae=['3',0], prompt=prompt, width=960, height=544, length=124, first_frame=['4',0], last_frame=['4',0]),
        '6': node('BasicGuider', model=['1',0], conditioning=['5',0]),
        '7': node('RandomNoise', noise_seed=2026092406 if guided else 2026092405),
        '8': node('KSamplerSelect', sampler_name='res_multistep'),
        '9': node('BasicScheduler', model=['1',0], scheduler='simple', steps=20, denoise=1.0),
        '10': node('SamplerCustomAdvanced', noise=['7',0], guider=['6',0], sampler=['8',0], sigmas=['9',0], latent_image=['5',1]),
        '11': node('VAEDecode', samples=['10',0], vae=['3',0]),
        '13': node('CreateVideo', images=['11',0], fps=24, bit_depth=8),
        '14': node('SaveVideo', video=['13',0], filename_prefix='bogplate_move_h3/original', **{'format':'mp4','format.codec':'h264'}),
        '15': node('SaveImage', images=['11',0], filename_prefix='bogplate_move_h3/frames/decoded'),
    }
    if guided:
        source = BASE / 'opposed_contact_v2.png'
        mid_frame = dict(source=source.relative_to(ROOT).as_posix(),name='opposed_contact',rects=[[0,0,1210,1300]],anchor=[600,1260],scale=INPUT_SCALE)
        painted,(x,y) = source_pose(mid_frame)
        middle = Image.new('RGBA',(960,544),(255,0,255,255));middle.alpha_composite(painted,(ANCHOR[0]+x,ANCHOR[1]+y))
        middle.convert('RGB').save(OUT/'middle_magenta.png')
        write(OUT/'middle_reference.json',dict(source_frame=mid_frame,source_sha256=sha(source),input_sha256=sha(OUT/'middle_magenta.png'),ground_anchor=ANCHOR))
        graph['16']=node('LoadImage',image='bogplate_opposed_contact.png')
        graph['17']=node('MiniMaxH3AddGuide',positive=['5',0],latent=['5',1],vae=['3',0],frame_idx=61,image=['16',0])
        graph['6']['inputs']['conditioning']=['17',0]
        graph['14']['inputs']['filename_prefix']='bogplate_move_h3/'+OUT.name+'/original'
        graph['15']['inputs']['filename_prefix']='bogplate_move_h3/'+OUT.name+'/frames/decoded'
    write(OUT / 'workflow_api.json', graph)


def verify():
    g = json.loads((OUT / 'workflow_api.json').read_text())
    assert g['5']['inputs']['first_frame'] == g['5']['inputs']['last_frame'] == ['4',0]
    guided = (OUT/'middle_reference.json').exists()
    assert g['6']['inputs']['conditioning'] == (['17',0] if guided else ['5',0])
    assert g['10']['inputs']['latent_image'] == ['5',1]
    assert sum(n['class_type']=='MiniMaxH3AddGuide' for n in g.values()) == int(guided)
    if guided:
        assert g['17']['inputs']==dict(positive=['5',0],latent=['5',1],vae=['3',0],frame_idx=61,image=['16',0])
        assert sha(OUT/'middle_magenta.png')==json.loads((OUT/'middle_reference.json').read_text())['input_sha256']
    assert g['5']['inputs']['prompt'] == (OUT / 'prompt.txt').read_text().strip()
    assert sha(OUT / 'input_magenta.png') == json.loads((OUT / 'reference.json').read_text())['input_sha256']


def process():
    folder = OUT / 'matte'
    folder.mkdir(exist_ok=True)
    hashes = []
    with av.open(str(OUT / 'original_lossless.mkv')) as video:
        for i, frame in enumerate(video.decode(video=0)):
            a = np.asarray(frame.to_image().convert('RGB'), dtype=np.float32)
            corners = np.array([np.median(t.reshape(-1,3),axis=0) for t in (a[:24,:24],a[:24,-24:],a[-24:,:24],a[-24:,-24:])])
            bg = np.median(corners, axis=0)
            if np.max(np.linalg.norm(corners-bg,axis=1)) > 10 or min(bg[0],bg[2])-bg[1] < 150:
                raise ValueError(f'Frame {i}: unsafe nonuniform or nonmagenta key')
            alpha = np.clip(1-(np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1])/(min(bg[0],bg[2])-bg[1]),0,1)
            rgb = np.clip((a-(1-alpha[:,:,None])*bg)/np.maximum(alpha[:,:,None],.001),0,255)
            spill = np.maximum(0,np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1])
            rgb[:,:,0]-=spill; rgb[:,:,2]-=spill
            rgba = np.dstack([rgb,alpha*255]).astype('uint8'); rgba[rgba[:,:,3]<8]=0
            labels,n = label(rgba[:,:,3]>=8, structure=np.ones((3,3),dtype=np.uint8))
            keep = np.zeros(n+1,dtype=bool);keep[np.unique(labels[rgba[:,:,3]>=128])]=True;keep[0]=False
            rgba[~keep[labels]]=0
            path=folder/f'rgba_{i:03}.png';Image.fromarray(rgba,'RGBA').save(path);hashes.append(sha(path))
    assert len(hashes)==124
    write(OUT/'matte.json',dict(frames=124,fps=24,rgba_sha256=hashes,recipe='Flat-magenta corner consistency check; chroma alpha unmix; RGB magenta despill (absent from original palette); retain alpha>=8 components containing alpha>=128 pixels; no per-frame rescale or registration.'))


def review():
    target = ROOT / '.artifacts/bogplate_move_h3'
    target.mkdir(parents=True, exist_ok=True)
    for part in range(2):
        sheet = Image.new('RGB', (1440, 1600), (35, 45, 32))
        draw = ImageDraw.Draw(sheet)
        for j, i in enumerate(range(part*62, (part+1)*62)):
            x, y = (j % 8)*180, (j // 8)*200
            if j % 2: sheet.paste((218,211,193), (x,y,x+180,y+200))
            frame = Image.open(OUT/'matte'/f'rgba_{i:03}.png').crop((260,35,730,515))
            frame.thumbnail((174,178), Image.Resampling.LANCZOS)
            sheet.paste(frame, (x+(180-frame.width)//2,y+20), frame)
            draw.text((x+5,y+4), str(i), fill=(140,95,45))
        sheet.save(target/f'{OUT.name}_chronological_{part}.png')


def build():
    selection = json.loads((OUT/'selection.json').read_text())
    indices = selection['source_frames']
    assert len(indices)>=8 and len(indices)==len(set(indices))
    frames=[]
    for i in indices:
        path=OUT/'matte'/f'rgba_{i:03}.png'
        assert path.exists() and 0<=i<124
        frames.append(dict(name=f'move_h3_{i:03}',clip='move',source=path.relative_to(ROOT).as_posix(),rects=[[0,0,960,544]],anchor=ANCHOR,scale=RUNTIME_SCALE,alpha_noise_cutoff=0,video_frame=i,video_time_seconds=i/24))
    provenance={name:dict(path=(OUT/name).relative_to(ROOT).as_posix(),sha256=sha(OUT/name)) for name in ['original_lossless.mkv','original.json','workflow_api.json','prompt.txt','reference.json','matte.json']}
    if (OUT/'middle_reference.json').exists():provenance['middle_reference']=json.loads((OUT/'middle_reference.json').read_text())
    entry=dict(unit_id=UNIT,reference_height=256,source_facing='right',alpha_noise_cutoff=0,frames=frames,clips={'move':dict(indices=list(range(len(frames))),frame_msec=selection['frame_msec'],loop=True,static_frame=0)},source_scale_reason='One source guide scale .36 and runtime original scale .17; every decoded960x544 frame uses .17/.36 with fixed anchor480,490. No per-pose body normalization or synthetic/reversed frames.',provenance=provenance,visual_review=dict(status='pending',notes=selection['review_note']))
    write(OUT/'handoff.json',dict(schema_version=1,units=[entry]))
    previous=json.loads((ROOT/'art/animation/source/fluid'/UNIT/'reviewed_handoff.json').read_text())['units'][0]
    candidate=combine(previous,entry)
    candidate['preserved_accepted_clips']=previous.get('preserved_accepted_clips',[])
    target=ROOT/'.artifacts/bogplate_move_h3';target.mkdir(exist_ok=True,parents=True)
    write(target/'combined_handoff.json',dict(schema_version=1,units=[candidate]))


if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('verb',choices=['prepare','submit','status','collect','process','verify','review','build']);parser.add_argument('--attempt',choices=['guided_v2']);parser.add_argument('--guided',action='store_true');args=parser.parse_args()
    if args.attempt: OUT=BASE/args.attempt
    if args.verb=='prepare':prepare(args.guided);verify()
    elif args.verb=='submit':verify();submit(OUT,URL);verify()
    elif args.verb=='status':status(OUT,URL)
    elif args.verb=='collect':collect(OUT,URL)
    elif args.verb=='process':process()
    elif args.verb=='review':review()
    elif args.verb=='build':build()
    else:verify();print('Verified actual Bogplate graph and original guide.')
