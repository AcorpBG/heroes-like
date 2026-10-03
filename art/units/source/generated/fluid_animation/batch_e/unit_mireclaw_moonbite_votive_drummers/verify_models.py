"""Read-only current H3 model/schema verification, without loading GPU models."""
import datetime,hashlib,json
from pathlib import Path
import produce as p

def run():
 expected={
  'diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors':(20970379616,'e889202c41dafb67b10d67b97f0d8541508036a6090af23425a5c2615d03c47a'),
  'text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors':(15687142551,'35a88d51044231fe332301d7a62aa81e3f2cba62febeb446e2c1e3e0ef76f2c6'),
  'vae/minimax_h3_video_vae_int8_convrot.safetensors':(2811065184,'52a2c8c73583c86e4f41cdcce3a6ad0ea562987bc0bf3d60a0cef5f5c8e60c0e')}
 records={};root=Path('H:/ai/minimax-h3/ComfyUI/models')
 for name,(size,expected_hash) in expected.items():
  path=root/name;assert path.stat().st_size==size
  with path.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
  assert digest==expected_hash,name
  records[name]=dict(bytes=size,sha256=digest)
  print('MODEL_VERIFIED',name,flush=True)
 stats=p.request(p.URL,'/system_stats')
 assert stats['system']['comfyui_version']=='0.37.0'
 assert any('RTX 5090' in device['name'] for device in stats['devices'])
 argv=stats['system']['argv'];assert argv[argv.index('--reserve-vram')+1]=='4' and '--disable-dynamic-vram' in argv
 for name in ['MiniMaxH3ImageToVideo','MiniMaxH3AddGuide','SaveLatent','LTXVSeparateAVLatent','VAEDecodeTiled']:
  assert name in p.request(p.URL,'/object_info/'+name)
 p.write(p.SOURCE_DIR/'h3_models.json',dict(verified_on=datetime.datetime.now().astimezone().isoformat(),models=records,service_url=p.URL,comfyui_version=stats['system']['comfyui_version'],argv=argv,rule='Read-only full model byte/SHA verification and live schemas; no model, environment or service setting changes.'))

if __name__=='__main__':run()
