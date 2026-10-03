"""Correct guide compositing plate; never remove opaque generated subject pixels."""
import json
import numpy as np
from PIL import Image
import produce as p

if __name__ == '__main__':
 old=p.SOURCE_DIR/'move_h3_v2'
 c=json.loads((old/'config.json').read_bytes())
 evidence=[]
 for i,r in enumerate(c['references']):
  a=np.array(Image.open(old/f'guide_{i}_rgba.png').convert('RGBA'))
  magenta=np.minimum(a[:,:,0].astype(float),a[:,:,2])-a[:,:,1]
  opaque=int(((a[:,:,3]>=250)&(magenta>32)).sum())
  assert opaque==0,'Original guide subject needs separate review'
  evidence.append(dict(index=i,original_source_sha256=p.sha(p.ROOT/r['source']),original_rgba_sha256=p.sha(old/f'guide_{i}_rgba.png'),opaque_magenta_pixels=opaque,soft_edge_pixels=int(((a[:,:,3]>8)&(a[:,:,3]<250)).sum())))
 c['key_rgb']=[128,128,128]
 repaired=p.SOURCE_DIR/'far_step_clean_v1.png'
 assert repaired.exists(),'Retain the original image-tool far-step guide repair first'
 im=Image.open(repaired);assert im.mode=='RGBA' and im.size==(1069,1472)
 c['references'][2]=dict(c['references'][2],name='far_leg_extension_clean',source=repaired.relative_to(p.ROOT).as_posix())
 c['prompt']=c['prompt'].replace('Flat magenta RGB255,0,255 background','Flat neutral gray RGB128,128,128 background. Natural brown hair and boots with clean painted contours, no colored rim lighting')
 out=p.SOURCE_DIR/'move_h3_v3';out.mkdir(exist_ok=True)
 assert not (out/'sampling_submission.json').exists(),'Submitted original is immutable'
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
 for i in range(2):
  assert (out/f'guide_{i}_rgba.png').read_bytes()==(old/f'guide_{i}_rgba.png').read_bytes()
 a=np.array(Image.open(out/'guide_2_rgba.png'));rgb=a[:,:,:3].astype(float)
 assert not ((a[:,:,3]>=250)&(rgb[:,:,1]-np.maximum(rgb[:,:,0],rgb[:,:,2])>16)).any()
 assert not ((a[:,:,3]>=250)&(np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]>32)).any()
 p.write(p.SOURCE_DIR/'movement_plate_correction.json',dict(rejected_take='move_h3_v2',replacement_take='move_h3_v3',evidence=evidence,old_plate_rgb=[255,0,255],corrected_plate_rgb=c['key_rgb'],far_step_repair=dict(original_prepared_opaque_green_pixels_above32=18,original_green_max=114,corrected_source_sha256=p.sha(repaired),corrected_prepared_opaque_green_pixels_above16=0,imagegen_provenance='far_step_clean_v1.generation.json'),reason='Actual native movement review shows opaque magenta rim on hair/boots despite green/yellow video plates. Prepared original RGBA has no opaque magenta; magenta compositing colors its soft edges and H3 inherits that rim as subject. Original far-step guide additionally has18 opaque green pixels and visible green hair/weapon spill; use a retained image-tool guide repair. Recompose ready/nearstep unchanged RGBA and repaired far-step over neutral gray, then regenerate only movement. Preserve original v2; never threshold/recolor its opaque subject.',unchanged=['ready and near-step source RGBA pixels','anchors','anatomical scale','guide schedule','seed','sampler','steps','models','resolution','decode settings','matting tool']))
 rejected=json.loads((p.SOURCE_DIR/'rejected_takes.json').read_bytes())
 if not any(r['take']=='move_h3_v2' for r in rejected['takes']):
  rejected['takes'].append(dict(take='move_h3_v2',reason='Reciprocal gait passes, but actual Godot native/mirrored full-strip review reveals opaque magenta hair/boot rim inherited from guide plate. The affected original video frames have green/yellow backgrounds; opaque artwork cannot be repaired by chroma extraction.',correction='move_h3_v3, original ready/near-step RGBA and retained image-tool clean far-step guide re-composited over neutral gray; complete movement regenerated'))
 p.write(p.SOURCE_DIR/'rejected_takes.json',rejected)
 d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());d['takes']=['move_h3_v3' if t=='move_h3_v2' else t for t in d['takes']];p.write(p.SOURCE_DIR/'delivery.json',d)
