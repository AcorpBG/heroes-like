"""Verify actual local runtime before creating any original H3 job."""
import json,shutil
from pathlib import Path
import produce as p
from creature_animation_lock import exclusive

COMFY=Path('H:/ai/minimax-h3/ComfyUI')
if __name__=='__main__':
    models=[]
    for kind,name in [('diffusion_models','minimax_h3_fl2va_pruned_int8_convrot.safetensors'),('text_encoders','qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors'),('vae','minimax_h3_video_vae_int8_convrot.safetensors')]:
        file=COMFY/'models'/kind/name
        assert file.is_file() and file.stat().st_size>1024**2,file
        models.append(dict(kind=kind,path=str(file),bytes=file.stat().st_size))
    for mount in ['D:/','H:/']:assert shutil.disk_usage(mount).free>15*1024**3,mount
    nodes={}
    for name in ['MiniMaxH3ImageToVideo','MiniMaxH3AddGuide','VAEDecodeTiled','LTXVSeparateAVLatent','SaveLatent']:
        info=p.request(p.URL,'/object_info/'+name)[name]
        nodes[name]=dict(required_inputs=list(info['input']['required']),outputs=info['output'])
    runtime=p.request(p.URL,'/system_stats')
    assert '--reserve-vram' in runtime['system']['argv']
    p.write(p.SOURCE_DIR/'runtime_profile.json',dict(url=p.URL,system=runtime['system'],devices=runtime['devices'],model_files=models,nodes=nodes,matting_manifest=p.sha(p.SOURCE_DIR/'matting_model.json'),unit_id='unit_neutral_cindervane_censerwings',immutable_source_policy='Original124-frame RGB/latent/video retained; bounded two-action shared leases. Full temporal and native acceptance required before publication.'))
    # Prefix only the selected active-slice note. Preserve the large operations
    # tracker and all other concurrent worker edits byte for byte.
    with exclusive('content'):
        file=p.ROOT/'ops/progress.json';text=file.read_text(encoding='utf-8')
        start=text.index('"id": "art-fluid-creature-animation-20260923"')
        note=text.index('"notes": "',start)+len('"notes": "')
        prefix='COORDINATOR ACTIVE: Cindervane Censerwings; seven original four-winged H3 actions, full solo source/native acceptance and integration in progress. Original eight idle phases under native review; all232 roster goal remains in_progress. | '
        if prefix not in text: file.write_text(text[:note]+prefix+text[note:],encoding='utf-8')
    print('LOCAL_MODELS_NODES_DISK_GUIDES_VERIFIED',flush=True)
