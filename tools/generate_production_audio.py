#!/usr/bin/env python3
"""Resumable Stable Audio production jobs, source provenance, and runtime edits.

Requires numpy/soundfile and the native ComfyUI Stable Audio 3 nodes. No model
downloads, custom nodes, simulation RNG, or implicit publishing of manifests.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import time
import urllib.parse
import urllib.request

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art/audio/source/stable_audio_3_v1'
RUNTIME = ROOT / 'art/audio/runtime/production'
MODEL_REPO = 'Comfy-Org/stable-audio-3'
MODEL_REVISION = '96fc663283cde94cb631bc84f6c9ece7bbe2bf25'
MODEL_HASHES = {
    'stable_audio_3_medium.safetensors': '48d9c65e290e7bcd5194e0633bfc2424a59ee9683f5c2d58762d997b7d8ce0b5',
    'stable_audio_3_small_sfx.safetensors': 'ed9cf1b6172f1a8c2921a9560c21109ff3239524563ced9dce6dcdef41e2f515',
    't5gemma_b_b_ul2.safetensors': '1e1eba25be8872edb0d3c6335c6658fd6388e7b14b60da6e454e404cfcd8150e',
}

def json_write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix+'.tmp')
    temp.write_text(json.dumps(value, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
    temp.replace(path)

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def relative(path):
    return path.relative_to(ROOT).as_posix()

def jobs():
    with (ROOT/'docs/audio-generation/generation-queue.csv').open(encoding='utf-8', newline='') as f:
        briefs = list(csv.DictReader(f))
    result = []
    for row in briefs:
        if row['priority'] not in ['P0', 'P1']:
            continue
        category = row['category']
        count = 1 if category == 'music' else int(row['planned_deliverable_files'])
        for i in range(count):
            gesture = ''
            if category == 'unit_body':
                gesture = 'move' if i < 4 else ('attack' if i < 8 else ('hit' if i < 10 else 'defeat'))
            id = row['brief_id'] + (('_'+gesture) if gesture else '') + f'_v{i+1:02}'
            if category in ['music', 'stingers']:
                id = row['brief_id'] + f'_orchestral_v{i+1:02}'
            loop = row['loop'] == 'yes'
            seconds = 124 if category == 'music' else (64 if loop else (8 if category=='stingers' else 5))
            if category=='music' and 'outcome' in row['brief_id']:
                seconds = 44
            prompt = row['sound_brief']
            if category == 'music':
                prompt = prompt.split('Deliver one coherent composition')[0].strip()
                prompt = 'Richly orchestrated original fantasy strategy soundtrack for full symphony orchestra. Expressive massed strings, lyrical woodwinds, warm French horns, carefully voiced brass, harp, timpani and restrained orchestral percussion. ' + prompt
                prompt += ' Broad melodic development and orchestral interplay. One coherent complete stereo instrumental composition, spacious concert-hall arrangement, steady tempo, no vocals, no speech, no sound effects, no drum kit, no electronic beat.'
            elif category == 'stingers':
                prompt = 'Original full-orchestra fantasy stinger: strings, woodwinds, French horns, timpani and orchestral percussion. '+prompt+' No vocals, no electronic instruments. One complete short phrase with a clear natural ending.'
            elif category == 'unit_body':
                prompt = prompt.split('. Deliver move')[0]
                prompt += '. One isolated '+{'move':'single body footstep or body movement', 'attack':'brief attack exertion or physical attack gesture', 'hit':'short hit reaction', 'defeat':'defeat and body collapse'}[gesture]+'. No other action, no speech, no music. Close isolated recording with quiet space before and after.'
            elif not loop:
                prompt = prompt.replace('Four ', 'One ').replace('four ', 'one ').replace('Two ', 'One ').replace('two ', 'one ')
                prompt += ' A single isolated event, not a repeating sequence. Quiet space before and after. No background ambience.'
            seed = int.from_bytes(hashlib.sha256(id.encode()).digest()[:6], 'big')
            result.append(dict(id=id, brief_id=row['brief_id'], priority=row['priority'], category=category,
                targets=row['target_cue_ids_or_content'].split(';'), variant=i, gesture=gesture,
                loop=loop, source_seconds=seconds, prompt=prompt, seed=seed,
                model='stable_audio_3_medium.safetensors' if row['generation_model']=='Medium' else 'stable_audio_3_small_sfx.safetensors'))
    return result

def workflow(job):
    return {
        '25': {'class_type':'CheckpointLoaderSimple','inputs':{'ckpt_name':job['model']}},
        '26': {'class_type':'CLIPLoader','inputs':{'clip_name':'t5gemma_b_b_ul2.safetensors','type':'stable_audio','device':'default'}},
        '6': {'class_type':'CLIPTextEncode','inputs':{'clip':['26',0],'text':job['prompt']}},
        '7': {'class_type':'CLIPTextEncode','inputs':{'clip':['26',0],'text':''}},
        '11': {'class_type':'EmptyLatentAudio','inputs':{'seconds':job['source_seconds'],'batch_size':1}},
        '3': {'class_type':'KSampler','inputs':{'model':['25',0],'positive':['6',0],'negative':['7',0],
            'latent_image':['11',0],'seed':job['seed'],'steps':8,'cfg':1.0,'sampler_name':'lcm','scheduler':'simple','denoise':1.0}},
        '12': {'class_type':'VAEDecodeAudio','inputs':{'samples':['3',0],'vae':['25',2]}},
        '59': {'class_type':'AudioAdjustVolume','inputs':{'audio':['12',0],'volume':-12}},
        '58': {'class_type':'SaveAudioAdvanced','inputs':{'audio':['59',0],'filename_prefix':'production-v1/'+job['id'],'format':'flac'}},
    }

def api(base, path, payload=None):
    req = urllib.request.Request(base+path, data=None if payload is None else json.dumps(payload).encode(), headers={'Content-Type':'application/json'})
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.load(response)

def generate(base, job, source):
    graph = workflow(job)
    reply = api(base, '/prompt', {'prompt':graph,'client_id':'aurelion-production-audio'})
    prompt_id = reply['prompt_id']
    start=time.monotonic(); report=start
    while True:
        history=api(base,'/history/'+prompt_id).get(prompt_id)
        if history:
            break
        if time.monotonic()-start>1800:
            raise TimeoutError('Generation timed out: '+job['id'])
        if time.monotonic()-report>30:
            print(job['id'], 'generating', round(time.monotonic()-start),'seconds', flush=True); report=time.monotonic()
        time.sleep(1)
    if history['status']['status_str']!='success':
        json_write(source.with_suffix('.failure.json'),history)
        raise RuntimeError('ComfyUI generation failed: '+job['id'])
    audio=history['outputs']['58']['audio'][0]
    query=urllib.parse.urlencode({k:audio[k] for k in ['filename','subfolder','type']})
    with urllib.request.urlopen(base+'/view?'+query,timeout=120) as response:
        source.write_bytes(response.read())
    return {'workflow':graph,'prompt_id':prompt_id,'generation_seconds':round(time.monotonic()-start,3)}

def signal_stats(wave, sr):
    return {'seconds':round(len(wave)/sr,6),'frames':len(wave),'sample_rate_hz':sr,'channels':wave.shape[1],
        'peak':float(np.max(np.abs(wave))),'rms':float(np.sqrt(np.mean(wave*wave))),
        'dc':float(np.max(np.abs(np.mean(wave,axis=0)))),'finite':bool(np.isfinite(wave).all()),
        'clipping_fraction':float(np.mean(np.abs(wave)>=0.999))}

def edit(job, source, master, runtime):
    wave,sr=sf.read(source,always_2d=True,dtype='float32')
    initial=signal_stats(wave,sr)
    if sr!=44100 or wave.shape[1]!=2 or not initial['finite'] or initial['rms']<0.00001 or initial['clipping_fraction']>0:
        raise ValueError(('Unusable source',job['id'],initial))
    wave -= np.mean(wave,axis=0,keepdims=True)
    edits={'recipe':'aurelion_audio_edit_v1','source_statistics':initial}
    if job['loop']:
        # Circular splice: head overlaps tail, then the middle follows it.
        # The internal seam continues naturally from head to middle, and the
        # wrap continues naturally from middle/tail to the start of the splice.
        n=int(sr*2)
        wave=wave[sr:]
        alpha=np.linspace(0,1,n,dtype=np.float32)[:,None]
        overlap=wave[-n:]*(1-alpha)+wave[:n]*alpha
        wave=np.concatenate([overlap,wave[n:-n]])
        edits.update(loop_crossfade_seconds=2.0,leading_trim_seconds=1.0)
    else:
        # Locate the strongest gesture using a smoothed energy envelope and
        # retain its lead-in and decay rather than assuming generation at t=0.
        hop=441
        frames=len(wave)//hop
        envelope=np.sqrt(np.mean(wave[:frames*hop].reshape(frames,hop,2)**2,axis=(1,2)))
        peak=int(np.argmax(envelope)); threshold=max(0.0002,float(envelope[peak])*0.06)
        start=peak
        while start>0 and (envelope[start-1]>threshold or (start>1 and envelope[start-2]>threshold)):
            start-=1
        start=max(0,start*hop-int(.02*sr))
        end=peak
        while end+1<len(envelope) and (envelope[end+1]>threshold or (end+2<len(envelope) and envelope[end+2]>threshold)):
            end+=1
        end=min(len(wave),(end+1)*hop+int(.10*sr))
        maximum=.28 if job['category']=='ui' else (8 if job['category']=='stingers' else (2.5 if job['gesture']=='defeat' else 1.5))
        if job['category']=='stingers':
            start=0;end=len(wave)
        end=min(end,start+int(maximum*sr))
        end=max(end,min(len(wave),start+int(.10*sr)))
        wave=wave[start:end].copy()
        attack=min(len(wave)//4,int(.003*sr)); release=min(len(wave)//4,int(.04*sr))
        wave[:attack]*=np.linspace(0,1,attack,dtype=np.float32)[:,None]
        wave[-release:]*=np.linspace(1,0,release,dtype=np.float32)[:,None]
        edits.update(trim_start_frame=start,trim_end_frame=end,attack_fade_frames=attack,release_fade_frames=release)
    stats=signal_stats(wave,sr)
    target_rms=.12 if job['category']=='music' else (.08 if job['loop'] else .16)
    gain=min(target_rms/max(stats['rms'],1e-9),.70/max(stats['peak'],1e-9),8.0)
    wave*=gain
    edits['gain_db']=20*math.log10(gain)
    sf.write(master,wave,sr,subtype='PCM_24',format='FLAC')
    if job['loop']:
        # libsndfile's Windows Vorbis writer can overflow its native stack on
        # long stereo arrays. FFmpeg streams the edited FLAC into Vorbis.
        ffmpeg=shutil.which('ffmpeg')
        if not ffmpeg:
            raise RuntimeError('FFmpeg is required for OGG runtime encoding')
        subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-i',str(master),
            '-c:a','libvorbis','-q:a','5',str(runtime)],check=True)
    else:
        sf.write(runtime,wave,sr,subtype='PCM_16',format='WAV')
    decoded,rate=sf.read(runtime,always_2d=True,dtype='float32')
    stats=signal_stats(decoded,rate)
    if not stats['finite'] or stats['rms']<0.00001 or stats['peak']>=.98:
        raise ValueError(('Invalid edited runtime audio',job['id'],stats))
    edits['runtime_statistics']=stats
    return edits

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--comfy-url',default='http://127.0.0.1:8188')
    parser.add_argument('--only',default='',help='Comma-separated brief IDs; empty means all required jobs')
    parser.add_argument('--limit',type=int,default=0)
    parser.add_argument('--prepare-only',action='store_true')
    args=parser.parse_args()
    for folder in [SOURCE/'raw',SOURCE/'masters',SOURCE/'provenance',RUNTIME]: folder.mkdir(parents=True,exist_ok=True)
    (SOURCE/'.gdignore').write_text('')
    all_jobs=jobs()
    json_write(SOURCE/'jobs.json',{'schema':'aurelion_audio_jobs_v1','model_repository':MODEL_REPO,'model_revision':MODEL_REVISION,
        'model_hashes':MODEL_HASHES,'jobs':all_jobs})
    if args.prepare_only:
        print('Prepared',len(all_jobs),'required jobs');return
    api(args.comfy_url,'/system_stats')
    selected=[j for j in all_jobs if not args.only or j['brief_id'] in args.only.split(',')]
    if args.limit: selected=selected[:args.limit]
    completed=0
    for index,job in enumerate(selected):
        source=SOURCE/'raw'/(job['id']+'.flac');master=SOURCE/'masters'/(job['id']+'.flac')
        runtime=RUNTIME/(job['id']+('.ogg' if job['loop'] else '.wav'))
        record_path=SOURCE/'provenance'/(job['id']+'.json')
        if record_path.exists():
            record=json.loads(record_path.read_text(encoding='utf-8'))
            if record.get('status')=='technical_checks_passed' and all(p.exists() and sha(p)==record[k] for p,k in [(source,'source_sha256'),(master,'master_sha256'),(runtime,'runtime_sha256')]):
                completed+=1;continue
        print(f'[{index+1}/{len(selected)}] {job["id"]}',flush=True)
        generation=generate(args.comfy_url,job,source) if not source.exists() else {'workflow':workflow(job),'resumed_source':True}
        edit_record=edit(job,source,master,runtime)
        record={**job,'status':'technical_checks_passed','listening_review':'pending','model_repository':MODEL_REPO,
            'model_revision':MODEL_REVISION,'model_sha256':MODEL_HASHES[job['model']],
            'text_encoder_sha256':MODEL_HASHES['t5gemma_b_b_ul2.safetensors'],
            'source_path':relative(source),'master_path':relative(master),'runtime_path':'res://'+relative(runtime),
            'source_sha256':sha(source),'master_sha256':sha(master),'runtime_sha256':sha(runtime),
            'generation':generation,'edit':edit_record}
        json_write(record_path,record);completed+=1
        print('saved',relative(runtime),f'{edit_record["runtime_statistics"]["seconds"]:.2f}s',flush=True)
    print('Completed/resumed',completed,'of',len(selected),'jobs; listening review remains separate.',flush=True)

if __name__=='__main__':
    main()
