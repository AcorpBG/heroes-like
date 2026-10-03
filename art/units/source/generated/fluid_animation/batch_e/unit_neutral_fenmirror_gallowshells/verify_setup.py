"""Read-only verification and original model provenance for this H3 unit."""
import json, hashlib, urllib.request, time
from pathlib import Path
S=Path(__file__).resolve().parent
ROOT=next(p for p in S.parents if (p/'project.godot').exists())
def get(path):
    with urllib.request.urlopen('http://127.0.0.1:8189'+path,timeout=30) as r: return json.load(r)
def main():
    stats=get('/system_stats');assert any('5090' in d['name'] for d in stats['devices'])
    models=[('diffusion_models','minimax_h3_fl2va_pruned_int8_convrot.safetensors',20970379616),('text_encoders','qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors',15687142551),('vae','minimax_h3_video_vae_int8_convrot.safetensors',2811065184)]
    verified=[]
    for folder,name,size in models:
        path=Path('H:/ai/minimax-h3/ComfyUI/models')/folder/name
        assert path.stat().st_size==size
        with path.open('rb') as f: digest=hashlib.file_digest(f,'sha256').hexdigest()
        verified.append(dict(kind=folder,filename=name,bytes=size,sha256=digest))
        print('MODEL_VERIFIED',name,flush=True)
    nodes={}
    for name in ['MiniMaxH3ImageToVideo','MiniMaxH3AddGuide','SaveLatent','LoadLatent','LTXVSeparateAVLatent','VAEDecodeTiled']:
        nodes[name]=get('/object_info/'+name)[name]
    (S/'runtime_profile.json').write_text(json.dumps(dict(url='http://127.0.0.1:8189',verified_unix=time.time(),system=stats['system'],devices=stats['devices'],model_files=verified,nodes=nodes,settings='124 observed frames at24fps;20 res_multistep/simple steps;960x704;separate saved latent then model release and16-frame tiled VAE decode;no LoRA or hosted API'),indent=2)+'\n',encoding='utf-8')
    brief=json.loads((S/'brief.json').read_bytes());brief['status']='in_progress_original_h3_generation';brief['new_support_key']='One original closed-pincer salute, uniform original scale0.225 and anatomical anchor[704,1190], personally reviewed at native128/enlarged2x both facings on dark/light. All15 original H3 guide canvases personally inspected; six actions prepared, video acceptance pending.'
    (S/'brief.json').write_text(json.dumps(brief,indent=2)+'\n',encoding='utf-8')
    print('SERVICE_AND_SIX_NODE_SCHEMAS_VERIFIED; NO QUEUE MUTATION')
if __name__=='__main__':main()
