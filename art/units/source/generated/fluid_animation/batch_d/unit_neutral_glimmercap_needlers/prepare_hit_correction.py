"""Recoil without the legacy hit painting's overlong loaded point."""
import json
import produce as p
from prepare import ref
from prepare_corrections import prepare

if __name__=='__main__':
    c=json.loads((p.SOURCE_DIR/'hit_h3_v1/config.json').read_bytes())
    c.update(seed=2026100813,references=[ref(17)],guides=[],last=0)
    c['prompt']=('Brief impact recoil and balance recovery of the supplied young teal-hooded human scout. Both knees bend, chest leans backward about15degrees, original left hand keeps its three short spare needles and draws them close to chest. Original right hand retains the same short rigid wooden blowpipe angled down-left beside the hip. Its brass shaft and tiny attached cyan point never change length or become a blade. Recover balance through knees and torso, return both hands and shoulders to the supplied standing ready pose, then hold ready. Two original arms, two hands, two legs, unchanged hood, face, quiver, armor and cyan belt vials. Fixed elevated orthographic camera facing right with unchanged anatomical size and centered root inside960x544. Uniform pure saturated magenta RGB255,0,255 background throughout. No firing, magical effects, color cycling, shadows, added people or objects.').strip()
    prepare('hit_h3_v2',c)
    path=p.SOURCE_DIR/'correction_review.json'
    review=json.loads(path.read_bytes())
    review['rejected']['hit_h3_v1']='Enlarged review shows the loaded point becoming an overlong blade during recoil26-50. Use the original ready equipment guide alone for corrected recoil.'
    review['preserved'].remove('hit_h3_v1')
    p.write(path,review)
