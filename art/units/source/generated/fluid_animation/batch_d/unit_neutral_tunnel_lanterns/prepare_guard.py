"""Original intermediate brace guide prevents the rejected spear-length sweep."""
import json
from PIL import Image
import produce as p
def prepare():
 master=p.SOURCE_DIR/'guard_half_brace_v1.png';im=Image.open(master)
 c=json.loads((p.SOURCE_DIR/'defend_h3_v1/config.json').read_bytes());c['seed']=2026100420
 mid=dict(name='half_guard_original',source=master.relative_to(p.ROOT).as_posix(),rects=[[0,0,*im.size]],anchor=[850,815],scale=.28,alpha_noise_cutoff=8)
 c['references']=[c['references'][0],mid,c['references'][1]];c['guides']=[[18,1],[38,2]];c['last']=2
 c['prompt']=c['prompt'].replace('Raise left-arm lantern shield forward','Keep right elbow close to hip, never sweep spear sideways or change its short length. Raise left-arm lantern shield forward')
 out=p.SOURCE_DIR/'defend_h3_v2';out.mkdir(exist_ok=False)
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
if __name__=='__main__':prepare()
