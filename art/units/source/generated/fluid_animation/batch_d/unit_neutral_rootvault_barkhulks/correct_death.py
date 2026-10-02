"""Correct physical guide contacts before generating a grounded collapse."""
import json
import produce as p
from prepare import IDENTITY,PLATE,reference

def grounded(index):
    f=reference(index)
    if index in [9,10]:
        image,offset=p.source_pose(f,8)
        f['anchor']=[f['anchor'][0],round(f['anchor'][1]+(offset[1]+image.height)/f['scale'])]
    return f

if __name__=='__main__':
    c=json.loads((p.SOURCE_DIR/'death_h3_v1/config.json').read_bytes())
    c['seed']=2026108106
    c['references']=[grounded(i) for i in [12,9,10,11]]
    c['last']=3;c['guides']=[[42,1],[72,2],[94,3]]
    c['prompt']=(IDENTITY+'One slow continuous collapse under heavy weight. Rear knees fold while both broad root fists remain on the ground. Lower the chest and head between the supported arms, then let the original body lean gently onto its side through the supplied intermediate resting pose. Keep at least one broad root fist, knee or resting side in ground contact throughout; no jump, airborne roll, flailing hands or upward bounce. Preserve all four attached root limbs and the original heartwood disk at its original size. Shift weight down rather than lifting the body. Settle crown and beard into the original corpse guide, all visible roots resting naturally beside the torso. End completely still and grounded. No effects, debris, shrinking, disappearing limbs or standing up. '+PLATE).strip()
    out=p.SOURCE_DIR/'death_h3_v2';out.mkdir(exist_ok=False)
    p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
    path=p.SOURCE_DIR/'rejected_takes.json';rejected=json.loads(path.read_bytes())
    rejected['death_h3_v1']=dict(status='rejected',reason='Original kneeling guide contact sat above the common ground; generated collapse flung root fists and overshot the contact plane before settling. Full124-frame and enlarged collapse review.',affected_frames=list(range(64,77)),correction='Register physical kneeling/side-rest contacts once in the original guide metadata; add original side-rest guide. Generate slow continuously supported collapse. No per-frame stabilization.')
    p.write(path,rejected)
