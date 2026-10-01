"""Replace the rejected kneel-to-corpse jump with an original side-fall guide."""
import json
from PIL import Image
import produce as p
def prepare():
 master=p.SOURCE_DIR/'side_fall_v2.png';im=Image.open(master)
 c=json.loads((p.SOURCE_DIR/'death_h3_v1/config.json').read_bytes());c['seed']=2026100421
 mid=dict(name='side_fall_original',source=master.relative_to(p.ROOT).as_posix(),rects=[[0,0,*im.size]],anchor=[850,715],scale=.27,alpha_noise_cutoff=8)
 c['references'].insert(3,mid);c['guides']=[[24,1],[44,2],[64,3],[88,4]];c['last']=4
 c['prompt']=c['prompt'].replace('Lower hip and shoulder into the side fall','Do not pause or jump from kneeling to prone. Lower the grounded pelvis while the upper body leans continuously to screen left through the supplied seated and diagonal side-fall guides. Right forearm supports the lowering head/shoulder, left arm retains the shield as it leans on its bottom rim. Lower hip and shoulder into the side fall')
 out=p.SOURCE_DIR/'death_h3_v2';out.mkdir(exist_ok=False)
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
if __name__=='__main__':prepare()
