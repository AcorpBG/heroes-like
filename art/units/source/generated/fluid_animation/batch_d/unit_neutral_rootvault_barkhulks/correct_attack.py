"""One targeted correction: original slam anatomy without baked impact graphics."""
import json
import produce as p
from prepare import IDENTITY,PLATE

if __name__=='__main__':
    c=json.loads((p.SOURCE_DIR/'attack_h3_v1/config.json').read_bytes())
    c['seed']=2026108102
    c['guides']=[[32,1],[55,2],[65,2],[102,0]]
    c['prompt']=(IDENTITY+'One deliberate heavy downward root-fist strike, performed as a controlled physical hammer motion. Raise the SAME near root arm to the supplied windup pose, slowly bring that root fist down onto its invisible contact plane and hold the supplied contact pose briefly, then recover the fist and shoulder to exact ready. The other arm and two rear legs support the mass continuously. Render ONLY the original creature on the flat plate: absolutely no white curves, swooshes, speed lines, impact flashes, fragments, dust, rocks, debris, shockwaves or effects at any time. The downward root fist itself supplies all visible impact. No second strike, no shoulder duplication, no extra limbs or glowing chest. '+PLATE).strip()
    out=p.SOURCE_DIR/'attack_h3_v2';out.mkdir(exist_ok=False)
    p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
    p.write(p.SOURCE_DIR/'rejected_takes.json',dict(attack_h3_v1=dict(status='rejected',reason='White impact arc overlaps creature and invented detached debris during contact/recovery. All124 original frames reviewed; no attempt to erase subject-overlapping effects.',affected_frames=list(range(38,58)),correction='attack_h3_v2: held original contact guides, controlled downward fist and explicit absence of baked graphics. Preserve entire original take and provenance.')))
