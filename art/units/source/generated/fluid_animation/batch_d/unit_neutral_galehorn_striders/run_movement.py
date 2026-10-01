"""One authorized movement take; release GPU before any CPU matte/review."""
import json,time,datetime
from pathlib import Path
import produce as p
import stage_video as stage
take='move_h3_v1';out=p.SOURCE_DIR/take
q=p.request(p.URL,'/queue');assert not q['queue_running'] and not q['queue_pending']
old=p.ROOT/'art/units/source/generated/fluid_animation/batch_d/unit_neutral_flaremast_crews/move_h3_v2/runtime_profile.json'
inherited=json.loads(old.read_bytes());models=Path('H:/ai/minimax-h3/ComfyUI/models')
sizes={f['file']:(models/f['file']).stat().st_size for f in inherited['model_manifest']['files']}
assert all(sizes[f['file']]==f['bytes'] for f in inherited['model_manifest']['files'])
classes=['MiniMaxH3ImageToVideo','MiniMaxH3AddGuide','SamplerCustomAdvanced','LTXVSeparateAVLatent','SaveLatent','LoadLatent','VAEDecodeTiled']
log=p.ROOT/'.artifacts/creature_sets_20261001/server-reserve4-stderr.log';log_offset=log.stat().st_size
profile=dict(unit_id='unit_neutral_galehorn_striders',captured_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),model_manifest=inherited['model_manifest'],hash_source=dict(path=old.relative_to(p.ROOT).as_posix(),sha256=p.sha(old),rule='Inherited full model hashes, current installed byte sizes independently verified; no fresh full-model hashing.'),installed_sizes=sizes,current_service=p.request(p.URL,'/system_stats'),current_node_schemas={name:p.request(p.URL,'/object_info/'+name) for name in classes},service_pid=28064,reserve_vram_gb=4,service_setting_source='Coordinator current PID and reserve4; same authorized local service, no service restart/config mutation.',server_log=log.relative_to(p.ROOT).as_posix(),server_log_start_offset=log_offset,settings=dict(width=960,height=640,length=124,fps=24,steps=20,sampler='res_multistep',scheduler='simple',turbo_lora=False),decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
p.write(out/'runtime_profile.json',profile);p.write(p.SOURCE_DIR/'runtime_profile.json',profile)
c=json.loads((out/'config.json').read_bytes());p.verify(out,c)
started=time.time();stage.release_models();sample_started=time.time();stage.run(take,phase='sample',release=False);sample_finished=time.time()
stage.release_models();decode_started=time.time();stage.run(take,release=False,prepare_review=False);decode_finished=time.time()
release=stage.release_models();q=p.request(p.URL,'/queue');assert not q['queue_running'] and not q['queue_pending']
with log.open('rb') as f:f.seek(log_offset);captured=f.read().decode('utf-8',errors='replace')
lines=[line for line in captured.replace('\r','\n').splitlines() if any(t in line.lower() for t in ['loaded completely','loaded partially','prompt executed','it/s','s/it'])]
p.write(out/'gpu_timing.json',dict(sample_wall_seconds=sample_finished-sample_started,decode_collect_wall_seconds=decode_finished-decode_started,total_wall_seconds=time.time()-started,reserve_vram_gb=4,actual_loader_and_sampler_lines=lines,release=release,terminal_queue_running=0,terminal_queue_pending=0,rule='Sampling preserves latent; grouped release precedes separate tiled VAE-only decode; collection verifies124 RGB, then GPU released before CPU review.'))
print('GPU_RELEASED queue0/0,124 original RGB verified; sample',round(sample_finished-sample_started,2),'decode/collect',round(decode_finished-decode_started,2),flush=True)
