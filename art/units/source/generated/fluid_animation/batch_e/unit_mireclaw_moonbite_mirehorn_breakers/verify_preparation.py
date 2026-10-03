import json,hashlib
from pathlib import Path
from PIL import Image,ImageDraw
import produce as p
ART=p.ROOT/'.artifacts/parallel_animation_20261002/unit_mireclaw_moonbite_mirehorn_breakers';ART.mkdir(exist_ok=True)
nodes=p.request(p.URL,'/object_info');stats=p.request(p.URL,'/system_stats')
required=['UNETLoader','CLIPLoader','VAELoader','MiniMaxH3ImageToVideo','MiniMaxH3AddGuide','SamplerCustomAdvanced','LTXVSeparateAVLatent','SaveLatent','LoadLatent','VAEDecodeTiled','CreateVideo','SaveVideo','SaveImage']
assert all(n in nodes for n in required)
p.write(p.SOURCE_DIR/'service_nodes.json',{n:nodes[n] for n in required});p.write(p.SOURCE_DIR/'service_stats.json',stats)
models=[]
for sub,name in [('diffusion_models','minimax_h3_fl2va_pruned_int8_convrot.safetensors'),('text_encoders','qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors'),('vae','minimax_h3_video_vae_int8_convrot.safetensors')]:
 file=Path('H:/ai/minimax-h3/ComfyUI/models')/sub/name;assert file.is_file()
 models.append(dict(path=str(file),bytes=file.stat().st_size,sha256=hashlib.file_digest(file.open('rb'),'sha256').hexdigest()))
p.write(p.SOURCE_DIR/'checkpoints.json',dict(models=models,steps=20,length=124,sampler='res_multistep',scheduler='simple',rule='Current installed int8/offload H3 files verified read-only; unchanged model/quality settings.'))
allguides=[]
for take in json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())['takes']:
 out=p.SOURCE_DIR/take;c=json.loads((out/'config.json').read_bytes());p.verify(out,c)
 allguides.extend((take,i,out/f'guide_{i}_rgba.png') for i in range(len(c['references'])))
for page in range((len(allguides)+7)//8):
 sheet=Image.new('RGB',(960,1360),(38,43,44));d=ImageDraw.Draw(sheet)
 for j,(take,index,f) in enumerate(allguides[page*8:(page+1)*8]):
  x=(j%2)*480;y=(j//2)*340;im=Image.open(f).convert('RGBA');im=im.resize((480,320),Image.Resampling.LANCZOS);sheet.paste(im,(x,y+20),im);d.text((x+5,y+4),f'{take} guide{index}',fill='white')
 sheet.save(ART/f'prepared_guides_{page}.png')
print('PREPARATION_VERIFIED',len(allguides),'guides',len(models),'model hashes',flush=True)
