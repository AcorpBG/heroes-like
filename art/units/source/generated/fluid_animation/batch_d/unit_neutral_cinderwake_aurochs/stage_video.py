"""Save H3 sampling before releasing models and decoding the preserved latent.

The two jobs preserve the same generation parameters and decoded source pixels;
this avoids retaining the large text encoder/denoiser through VAE decoding.
"""
import argparse,hashlib,json,shutil,time,urllib.error,urllib.request
from pathlib import PurePosixPath
import produce as p
from trial_video_creature_animation import fetch_bytes

def read(path):return json.loads(path.read_bytes())

def wait_job(job,evidence_path):
 observations=[]
 while True:
  try:
   h=p.request(p.URL,'/history/'+job)
   stats=p.request(p.URL,'/system_stats')
   observations.append(dict(recorded_unix=time.time(),devices=stats['devices'],job_terminal=job in h))
   p.write(evidence_path,dict(prompt_id=job,observations=observations,scope='Actual periodic VRAM snapshots; model residency/offload must be established separately from server log, not inferred from free memory.'))
   if job in h:
    result=h[job]
    assert result['status']['status_str']=='success',result['status']
    return result
  except (TimeoutError,urllib.error.URLError) as e:
   print('OBSERVATION',type(e).__name__,flush=True)
  time.sleep(10)

def log_start(out,c,phase):
 if 'residency_log' not in c:return
 path=p.ROOT/c['residency_log'];assert path.exists(), 'Expected active server log missing'
 p.write(out/(phase+'_log_start.json'),dict(path=c['residency_log'],byte_offset=path.stat().st_size,recorded_unix=time.time()))

def log_finish(out,phase,job):
 if (out/(phase+'_residency.json')).exists():return
 start=out/(phase+'_log_start.json')
 if not start.exists():return
 record=read(start);path=p.ROOT/record['path']
 with path.open('rb') as stream:
  stream.seek(record['byte_offset']);segment=stream.read()
 lines=segment.decode('utf-8',errors='replace').splitlines()
 relevant=[line for line in lines if any(term in line.lower() for term in ['requested to load','loaded completely','loaded partially','offloaded','lowvram','vram','unloaded','prompt executed','loading model'])]
 p.write(out/(phase+'_residency.json'),dict(prompt_id=job,server_log=record['path'],byte_start=record['byte_offset'],byte_end=record['byte_offset']+len(segment),observed_segment_sha256=hashlib.sha256(segment).hexdigest(),observed_loader_lines=relevant,scope='Actual server log between submission and observed terminal; shared clients may also appear. Job history determines execution time; these lines do not independently attribute residency to a queued job.'))

def release_models():
 q=p.request(p.URL,'/queue')
 assert not q['queue_running'] and not q['queue_pending'],'Another job owns the service'
 req=urllib.request.Request(p.URL+'/free',data=json.dumps(dict(unload_models=True,free_memory=True)).encode(),headers={'Content-Type':'application/json'})
 urllib.request.urlopen(req,timeout=30).close()
 for _ in range(30):
  time.sleep(1)
  stats=p.request(p.URL,'/system_stats')
  free=max((d.get('vram_free',0) for d in stats['devices']),default=0)
  if free>=16*1024**3:return dict(free_vram_bytes=free,required_free_vram_bytes=16*1024**3)
 raise RuntimeError('Large models have not released sufficient VRAM; no decode submitted')

def run(take,phase="all",release=True,queue_behind=False):
 if queue_behind:assert not release,'Shared queue cannot explicitly unload models'
 out=p.SOURCE_DIR/take;c=read(out/'config.json')
 if not (out/'sampling_submission.json').exists():
  assert not (out/'submission.json').exists(),'Do not overwrite an existing single-stage attempt'
  if release:release_models()
  p.prepare(out,c)
  graph=read(out/'workflow_api.json')
  for k in ['11','13','14','15']:graph.pop(k)
  # H3 samples a nested video/audio pair. This installed generic AV splitter
  # returns the unmodified video tensor, as VAEDecodeTiled itself would do.
  graph['17']=p.node('LTXVSeparateAVLatent',av_latent=['10',0])
  graph['16']=p.node('SaveLatent',samples=['17',0],filename_prefix=f'aurochs_h3_20261001/{take}/sampled')
  p.write(out/'workflow_api.json',graph)
  log_start(out,c,'sampling')
  p.submit(out,c,queue_behind=queue_behind)
  shutil.copyfile(out/'workflow_api.json',out/'sampling_workflow_api.json')
  shutil.copyfile(out/'submission.json',out/'sampling_submission.json')
 sample=read(out/'sampling_submission.json')
 print('SAMPLING',take,sample['prompt_id'],flush=True)
 if not (out/'sampling_history.json').exists():
  p.write(out/'sampling_history.json',wait_job(sample['prompt_id'],out/'sampling_observations.json'))
 log_finish(out,'sampling',sample['prompt_id'])
 h=read(out/'sampling_history.json')
 loc=h['outputs']['16']['latents'][0]
 assert loc['type']=='output' and loc['subfolder'].replace('\\','/').startswith(f'aurochs_h3_20261001/{take}')
 relative=PurePosixPath(loc['subfolder'].replace('\\','/'))/loc['filename']
 assert '..' not in relative.parts and relative.is_relative_to(PurePosixPath('aurochs_h3_20261001')/take)
 raw=fetch_bytes(p.URL,loc)
 if not (out/'original.latent').exists():(out/'original.latent').write_bytes(raw)
 assert hashlib.sha256(raw).hexdigest()==p.sha(out/'original.latent')
 print('LATENT_PRESERVED',take,flush=True)
 if phase=='sample':return
 if not (out/'decode_submission.json').exists():
  released=release_models() if release else (dict(shared_queue=True,explicit_unload=False,rule='Separate original-latent VAE-only job appended behind shared jobs; ComfyUI manages model residency without explicit unload.') if queue_behind else dict(reused_decoding_session=True,rule="All sampling finished and models released before the grouped VAE-only decode pass"))
  graph={
   '3':p.node('VAELoader',vae_name='minimax_h3_video_vae_int8_convrot.safetensors'),
   '10':p.node('LoadLatent',latent=f"{loc['subfolder']}/{loc['filename']} [output]".replace('\\','/')),
   '11':p.node('VAEDecodeTiled',samples=['10',0],vae=['3',0],**c['tiled_decode']),
   '13':p.node('CreateVideo',images=['11',0],fps=24,bit_depth=8),
   '14':p.node('SaveVideo',video=['13',0],filename_prefix=f'aurochs_h3_20261001/{take}/original',**{'format':'mp4','format.codec':'h264'}),
   '15':p.node('SaveImage',images=['11',0],filename_prefix=f'aurochs_h3_20261001/{take}/frames/decoded')}
  q=p.request(p.URL,'/queue')
  if not queue_behind:assert not q['queue_running'] and not q['queue_pending']
  else:p.write(out/'queue_at_decode_submission.json',dict(running=[j[1] for j in q['queue_running']],pending=[j[1] for j in q['queue_pending']],rule='Append original-latent decode; never cancel, interrupt or unload shared work.'))
  p.write(out/'workflow_api.json',graph)
  log_start(out,c,'decode')
  result=p.request(p.URL,'/prompt',dict(prompt=graph,client_id='aurochs_h3_20261001'))
  submission=dict(**result,started_unix=time.time(),url=p.URL,uploaded=sample['uploaded'],sampling_prompt_id=sample['prompt_id'])
  p.write(out/'decode_submission.json',submission);p.write(out/'submission.json',submission)
  rule=('Save original sampler latent and append separate VAE-only decode behind shared work without explicit unload; ComfyUI manages residency. No new motion, resizing or interpolation.' if queue_behind else 'Save original sampler latent, release encoder and denoiser plus execution cache, then decode only the original latent with VAE. No new motion, resizing or interpolation.')
  p.write(out/'staged_generation.json',dict(sampling_workflow_sha256=p.sha(out/'sampling_workflow_api.json'),latent_sha256=p.sha(out/'original.latent'),decode_workflow_sha256=p.sha(out/'workflow_api.json'),latent_output=loc,model_release=released,rule=rule))
 decoded=read(out/'decode_submission.json')
 print('DECODING',take,decoded['prompt_id'],flush=True)
 if not (out/'generation_history.json').exists():p.write(out/'generation_history.json',wait_job(decoded['prompt_id'],out/'decode_observations.json'))
 log_finish(out,'decode',decoded['prompt_id'])
 timing={}
 for phase,submission,history_path in [('sampling',sample,out/'sampling_history.json'),('decode',decoded,out/'generation_history.json')]:
  messages=read(history_path)['status']['messages']
  start=next(v['timestamp'] for k,v in messages if k=='execution_start');end=next(v['timestamp'] for k,v in messages if k=='execution_success')
  timing[phase]=dict(prompt_id=submission['prompt_id'],started_unix=submission['started_unix'],service_elapsed_seconds=round((end-start)/1000,3))
 p.write(out/'timing.json',timing)
 if not (out/'original.json').exists():p.collect(out,p.URL)
 if not (out/'matte.json').exists():
  try:p.process(out,c)
  except ValueError as error:
   p.write(out/'extraction_failure.json',dict(error=str(error),status='requires_original_frame_review',rule='No fallback matte or acceptance; preserve originals for review.'))
   print('RAW_REVIEW_REQUIRED',take,str(error),flush=True);return
 p.review(out,c)
 print('REVIEW_READY',take,flush=True)

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('takes',nargs='+');args=parser.parse_args()
 for take in args.takes:run(take)
