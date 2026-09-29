"""Decode the unchanged original latent with one complete temporal window."""
import json,shutil,sys,time
import produce as p
import stage_video as stage

for name in sys.argv[1:]:
 src=p.SOURCE_DIR/name
 dst=p.SOURCE_DIR/(name+'_decode128')
 dst.mkdir(exist_ok=False)
 for f in src.iterdir():
  if f.is_file() and (f.name.startswith('guide_') or f.name.startswith('sampling_') or f.name in ['original.latent','reference.json','accepted_baseline.json','prompt.txt']):shutil.copyfile(f,dst/f.name)
 c=json.loads((src/'config.json').read_bytes());c['tiled_decode']['temporal_size']=128
 p.write(dst/'config.json',c)
 graph=json.loads((src/'workflow_api.json').read_bytes())
 graph['11']['inputs']['temporal_size']=128
 for k,kind in [('14','original'),('15','frames/decoded')]:graph[k]['inputs']['filename_prefix']=f'tidepool_h3/{dst.name}/{kind}'
 released=stage.release_models()
 p.write(dst/'workflow_api.json',graph)
 result=p.request(p.URL,'/prompt',dict(prompt=graph,client_id='tidepool_h3'))
 sample=json.loads((dst/'sampling_submission.json').read_bytes())
 p.write(dst/'decode_submission.json',dict(**result,started_unix=time.time(),url=p.URL,uploaded=sample['uploaded'],sampling_prompt_id=sample['prompt_id']))
 shutil.copyfile(dst/'decode_submission.json',dst/'submission.json')
 p.write(dst/'decode_recovery.json',dict(source_take=name,latent_sha256=p.sha(dst/'original.latent'),source_latent_sha256=p.sha(src/'original.latent'),model_release=released,reason='Inspect repeated color shifts at 12-frame temporal tile boundaries. Decode the identical latent with one 128-frame window, retaining spatial tiling and all original failed outputs. No resampling or interpolation.'))
 print('DECODING',dst.name,result['prompt_id'],flush=True)
 p.write(dst/'generation_history.json',stage.wait_job(result['prompt_id']))
 p.collect(dst,p.URL)
 try:p.process(dst,c)
 except ValueError as error:
  p.write(dst/'extraction_failure.json',dict(error=str(error),status='requires_original_frame_review'))
  print('RAW_REVIEW_REQUIRED',dst.name,str(error),flush=True)
 else:p.review(dst,c);print('REVIEW_READY',dst.name,flush=True)
