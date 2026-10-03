"""Read-only current H3 service/model verification; no environment mutation."""
import hashlib,json,time,urllib.request,shutil
from pathlib import Path
S=Path(__file__).resolve().parent
def get(path):
    with urllib.request.urlopen('http://127.0.0.1:8189'+path,timeout=30) as response:return json.load(response)
def main():
    stats=get('/system_stats');assert any('5090' in d['name'] for d in stats['devices'])
    models=[('diffusion_models','minimax_h3_fl2va_pruned_int8_convrot.safetensors',20970379616),('text_encoders','qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors',15687142551),('vae','minimax_h3_video_vae_int8_convrot.safetensors',2811065184)]
    verified=[]
    for folder,name,size in models:
        path=Path('H:/ai/minimax-h3/ComfyUI/models')/folder/name
        assert path.stat().st_size==size
        with path.open('rb') as source:digest=hashlib.file_digest(source,'sha256').hexdigest()
        verified.append(dict(kind=folder,filename=name,bytes=size,sha256=digest))
        print('MODEL_VERIFIED',name,flush=True)
    nodes={name:get('/object_info/'+name)[name] for name in ['MiniMaxH3ImageToVideo','MiniMaxH3AddGuide','SaveLatent','LoadLatent','LTXVSeparateAVLatent','VAEDecodeTiled']}
    available={drive:shutil.disk_usage(drive).free for drive in ['D:/','H:/']}
    assert all(size>10*1024**3 for size in available.values()),available
    manifest=json.loads((S/'matting_model.json').read_bytes())
    for name,record in manifest['files'].items():
        file=Path('H:/ai/minimax-h3/matting')/('dependencies' if name.endswith('.whl') else 'BiRefNet-matting')/name
        assert file.stat().st_size==record['bytes']
        with file.open('rb') as source:assert hashlib.file_digest(source,'sha256').hexdigest()==record['sha256'],name
    data=dict(url='http://127.0.0.1:8189',verified_unix=time.time(),system=stats['system'],devices=stats['devices'],model_files=verified,nodes=nodes,free_disk_bytes=available,settings='124 original frames24fps;20 res_multistep/simple;960x704 fixed canvas; saved latent then separate16-frame tiled VAE decode; pinned original-scale BiRefNet matte; no LoRA or hosted API')
    (S/'runtime_profile.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
    print('SERVICE MODELS SIX NODE SCHEMAS PINNED MATTE AND DISK VERIFIED; QUEUE UNTOUCHED')
if __name__=='__main__':main()
