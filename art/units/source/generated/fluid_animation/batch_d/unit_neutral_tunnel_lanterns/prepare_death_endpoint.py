"""Reassess guide-phase cuts with the ordinary FL2VA first/last route."""
import json
import produce as p
def prepare():
 c=json.loads((p.SOURCE_DIR/'death_h3_v1/config.json').read_bytes());c['seed']=2026100422
 c['references']=[c['references'][0],c['references'][3]];c['guides']=[];c['last']=1
 identity=c['prompt'].split('One continuous heavy armored collapse.')[0]
 c['prompt']=identity+'One continuous natural heavy collapse, occurring smoothly in the first half of the video. Knees buckle, hips lower, torso tips sideways toward screen left. Right forearm supports the fall while loosely keeping the same short spear; left-arm lantern shield tilts with the body and comes to rest on its side. Head and shoulder lower toward the ground through real articulated intermediate positions, then body settles into the supplied head-left horizontal corpse. Both original legs and boots fold naturally behind torso. One intact spear lies beside the relaxed right hand, one intact shield and its caged lamp rest with the body. The lamp dims INSIDE its cage. Remain completely dead for the second half. Locked elevated three-quarter orthographic camera and same anatomical body/equipment scale, root in place. Exactly two arms and legs. Uniform pure magenta RGB255,0,255 background, no floor, shadow, text, new objects or external effects. Smooth continuous bodily lowering, no pose cuts, instant transformation, stiff freeze, standing up or repeated collapse.'
 out=p.SOURCE_DIR/'death_h3_v3';out.mkdir(exist_ok=False)
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
if __name__=='__main__':prepare()
