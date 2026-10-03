"""Add an original chest-salute guide before the support take is submitted."""
import json
from PIL import Image
import produce as p

if __name__=='__main__':
 out=p.SOURCE_DIR/'cast_h3_v1';assert not (out/'sampling_submission.json').exists(),'Submitted original is immutable'
 master=p.SOURCE_DIR/'salute_v1.png';im=Image.open(master);assert im.mode=='RGBA' and im.size==(1536,1024)
 f=dict(name='near_hand_chest_salute',source=master.relative_to(p.ROOT).as_posix(),rects=[[0,0,*im.size]],anchor=[768,934],scale=.229,alpha_noise_cutoff=8)
 c=json.loads((out/'config.json').read_bytes());c['references']=[c['references'][0],f];c['guides']=[[52,1]];c['last']=0
 c['prompt']=c['prompt'].replace('Near right hand keeps stock/trigger grip; far left hand supports forward barrel.','At the ready endpoints the near right hand grips stock/trigger and the far left hand supports the barrel. During this physical acknowledgement only, the near hand releases stock and rises to the chest-salute guide; the far hand keeps supporting the same rigid rifle.').replace('exact two grips','the original two hands and endpoint grips')
 record=lambda path:dict(path=path.relative_to(p.ROOT).as_posix(),sha256=p.sha(path))
 p.write(master.with_suffix('.generation.json'),dict(image=record(master),prompt=record(p.SOURCE_DIR/'salute_v1.prompt.txt'),references=[record(out/'guide_0_rgba.png')],tool='built-in image_gen',original_tool_path='C:/Users/acorp/.codex/generated_images/01a0fd4e-7754-7a91-8e06-2b328cba8526/exec-d318c474-9527-4e69-9128-a1b533ac3cb5.png',registration=f,review='Personally inspected complete master: exactly two arms/hands and two planted legs; near glove rises at chest, far hand supports same rifle, no third stock hand or magic. Face/hair/ribbons/court coat/knee armor/boots and orange glass muzzle/tag retained. Fixed anatomical head-to-ground extent matches original ready using one .229 whole-source scale and [768,934] ground origin.'))
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
