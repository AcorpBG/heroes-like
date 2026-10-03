"""Recover missing near-leg gait guide; preserve rejected same-leg original take."""
import json
from PIL import Image
import produce as p
if __name__=='__main__':
 master=p.SOURCE_DIR/'near_step_v1.png';image=Image.open(master);assert image.mode=='RGBA'
 f=dict(name='near_leg_extension',source=master.relative_to(p.ROOT).as_posix(),rects=[[0,0,*image.size]],anchor=[770,900],scale=.30,alpha_noise_cutoff=8)
 c=json.loads((p.SOURCE_DIR/'move_h3_v1/config.json').read_bytes());c['references']=[c['references'][0],f,c['references'][2]];c['guides']=[[34,1],[78,2]];c['seed']=2026108711
 c['prompt']=c['prompt'].replace('Near boot swings and plants then far boot swings and plants, with opposite knee bending and passing.','First swing the NEAR leg with prominent bronze kneecap (viewer-front thigh, at screen-left hip) forward to SCREEN RIGHT through the near-step guide. The opposite FAR boot carries support. Plant the near boot, then swing the FAR leg back and forward while the near boot supports, through the original FAR-leg forward-step guide. Both knees alternate bending, passing and planting; never cycle only the far leg while holding near leg straight.')
 out=p.SOURCE_DIR/'move_h3_v2';out.mkdir(exist_ok=True);assert not (out/'sampling_submission.json').exists(),'Submitted take is immutable'
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
