"""Reassessed solo Kitehook gait: opposed contacts and passing, no ready holds."""
import json
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import binary_erosion
import produce as p
from prepare_h3 import IDENTITY

def frame(path,anchor,scale):
 image=Image.open(p.ROOT/path)
 return dict(source=path,rects=[[0,0,image.width,image.height]],anchor=anchor,scale=scale,alpha_noise_cutoff=8)
if __name__=='__main__':
 out=p.SOURCE_DIR/'move_h3_v3';out.mkdir(exist_ok=False)
 base=p.SOURCE_DIR.relative_to(p.ROOT).as_posix()
 references=[frame(base+'/move_h3_v2/guide_0_rgba.png',[470,560],.5),frame(base+'/move_h3_v2/guide_2_rgba.png',[470,560],.5),frame(base+'/guides/passing_near_loaded_v1.png',[785,902],.27),frame(base+'/guides/passing_far_loaded_v1.png',[826,961],.20)]
 c=dict(unit_id='unit_neutral_kitehook_runners',clip='move',canvas=[960,640],anchor=[470,560],scale=.5,key_rgb=[0,255,0],seed=2026100172,tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4),references=references,guides=[[15,2],[31,1],[47,3],[62,0],[78,2],[93,1],[109,3]],last=0,
  prompt=IDENTITY+' Continuous forward jogging IN PLACE through TWO uninterrupted complete gait cycles. Her torso retains the same forward inclination, fixed pelvis position and body size throughout. Begin with the NEAR armored leg reaching forward into contact while the far leg trails behind; the near boot accepts weight and retracts under the hip, while the FAR knee lifts forward with heel tucked, reaching the first supplied passing pose. The far boot then extends into forward ground contact while the near heel lifts and trails. The far leg accepts weight, while the NEAR knee lifts forward and passes in front of it, matching the second distinct passing pose. Continue into the original near-leg-forward contact and repeat. Each thigh keeps its original hip attachment; each round knee guard and boot stays with its own leg. Smooth support, loading, toe-off and swinging feet through all intermediate frames, with both soles taking turns contacting the same invisible ground plane. Never pause in a standing ready pose. Exactly two arms keep both original grips on the compact hook pole with the one rope loop and two curved silver hooks unchanged; slight natural elbow movement, cloth and ponytail follow gait. End in the identical first stride contact. Locked elevated three-quarter orthographic camera facing right, no body turning, no camera movement or root translation, no extra legs or hands. Perfectly uniform pure green RGB0,255,0 background throughout; no floor, shadows, scenery, particles, magic or hue cycling.',
  reassessment='Previous v1/v2 standing interrupts and ambiguous support: replace standing ready guide with independently reviewed opposed near/far loading/passing paintings. Four coherent gait phases guided twice at equal intervals. Keep the accepted six other actions and map idle byte/pixel-exact. No synthetic interpolation/warps/frame-normalization.')
 p.write(out/'config.json',c);p.prepare(out,c)
 bands=[]
 for i in range(len(references)):
  a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(float);mask=binary_erosion(a[:,:,3]>240,iterations=3);bands.append(float((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[mask].max()))
 c['protected_foreground_chroma']=max(0,int(max(bands))+2);c['foreground_measurement']=dict(rule='Three-pixel-eroded opaque green chroma maximum across fixed-scale guides plus2.',per_guide_max=bands,separation=255-c['protected_foreground_chroma']);assert c['foreground_measurement']['separation']>=80
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
 temp=p.ROOT/'.artifacts/kitehook_solo_20261001';im=Image.new('RGB',(1920,640),(34,40,35));draw=ImageDraw.Draw(im)
 for i in range(4):
  guide=Image.open(out/f'guide_{i}_rgba.png');guide=guide.resize((480,320));im.paste(guide,(i*480,160),guide);draw.text((i*480+8,30),['Near forward contact','Far forward contact','Near loaded, far passing','Far loaded, near passing'][i])
 im.save(temp/'registered_guides.png')
 print('Prepared solo pending gait with4 matched guides; measured chroma',c['foreground_measurement'])
