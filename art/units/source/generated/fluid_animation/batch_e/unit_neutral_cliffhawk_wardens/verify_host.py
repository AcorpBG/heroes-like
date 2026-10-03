"""Read live installed H3 capabilities before any own submission."""
from pathlib import Path
import urllib.request,json,shutil
S=Path(__file__).parent;URL='http://127.0.0.1:8189'
def get(path):return json.load(urllib.request.urlopen(URL+path,timeout=60))
stats=get('/system_stats');nodes={}
for name in ['MiniMaxH3ImageToVideo','MiniMaxH3AddGuide','KSamplerSelect','BasicScheduler','LTXVSeparateAVLatent','SaveLatent','LoadLatent','VAEDecodeTiled']:
 nodes[name]=get('/object_info/'+name)[name]
assert len(stats['devices'])==1 and '5090' in stats['devices'][0]['name']
assert 'first_frame' in nodes['MiniMaxH3ImageToVideo']['input']['optional'] and 'last_frame' in nodes['MiniMaxH3ImageToVideo']['input']['optional']
assert 'frame_idx' in nodes['MiniMaxH3AddGuide']['input']['required']
models=[]
for folder,name in [('diffusion_models','minimax_h3_fl2va_pruned_int8_convrot.safetensors'),('text_encoders','qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors'),('vae','minimax_h3_video_vae_int8_convrot.safetensors')]:
 p=Path('H:/ai/minimax-h3/ComfyUI/models')/folder/name;assert p.is_file();models.append(dict(path=str(p),bytes=p.stat().st_size,mtime_ns=p.stat().st_mtime_ns))
record=dict(system_stats=stats,node_schemas=nodes,models=models,free_disk_bytes={drive:shutil.disk_usage(drive).free for drive in ['D:/','H:/']},queue_observed=get('/queue'),quality=dict(canvas=[960,544],frames=124,fps=24,steps=20,sampler='res_multistep',schedule='simple',turbo_lora=False))
(S/'host_verification.json').write_text(json.dumps(record,indent=2)+'\n');print('CLIFFHAWK_H3_HOST_VERIFIED',record['free_disk_bytes'],flush=True)
