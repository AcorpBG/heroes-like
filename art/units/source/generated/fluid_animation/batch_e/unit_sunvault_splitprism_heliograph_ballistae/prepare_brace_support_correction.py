"""Reject real source defects, then adjust guide control rather than accept them."""
import copy
import json
import produce as p


def main():
    S=p.SOURCE_DIR
    p.write(S/'defend_h3_v1/visual_review.json',dict(status='rejected_at_original_transition_review',reviewer='coordinator',examined='All124 original RGB chronologically, alpha0..63 on dark/light, original-size34..37 transition details.',defect='Source35..36 abruptly changes the mirror attitude and operator position together. The supplied brace is reached as a pose jump, rather than a readable articulated transition; later small cape/operator settling does not repair the missing entrance.',selection=[],alpha_native_acceptance='Alpha64..123 and whole native acceptance were not performed or claimed after rejection.',correction='Use ready and terminal brace guides only, removing both interior guide constraints; request a continuous crank/torso/mirror brace transition and held finish. Same original body scale and ground origin retained.',preservation='All originals, latents, guide pixels,124 full source mattes and provenance retained.'))
    p.write(S/'cast_h3_v1/visual_review.json',dict(status='rejected_at_original_RGB_review',reviewer='coordinator',examined='All124 original RGB chronologically.',defect='Blue concentric glowing ring appears13..31 around the mirror and operator; physical support should not bake a magic circle into the sprite. Source48..49 also sharply changes the tilted mirror back to ready.',selection=[],alpha_native_acceptance='Not performed or claimed after RGB rejection.',correction='Describe the actual manual crank adjustment without casting/relay/calibration language. Use fewer endpoint controls for coherent lean/arm-turn/recovery; preserve source identity and empty background.',preservation='All originals, latents, guide pixels,124 full source mattes and provenance retained.'))
    for name,parent,seed in [('defend_h3_v2','defend_h3_v1',2026100385),('cast_h3_v2','cast_h3_v1',2026100386)]:
        c=copy.deepcopy(json.loads((S/parent/'config.json').read_bytes()))
        identity=c['prompt'].split('Use the same flat pale blue-gray background')[0]
        if c['action']=='defend':
            c['references']=[c['references'][0],c['references'][2]]
            c['guides']=[];c['last']=1
            beats='Slow continuous protective brace followed by a held finish. The operator bends both knees and elbows while lowering his torso behind the original round mirror, keeping both hands on the crank. The mirror gradually pivots from its initial tilt into the supplied upright cover angle through visibly intermediate angles. Three original star-foot struts flex slightly while keeping their feet planted; both wheels retain the same axle and diameter. Complete the transition by the middle of the video, then remain braced through its end. Smoothly articulated joints throughout, no pose replacement, sudden camera change or return to ready.'
        else:
            c['guides']=[[60,1]];c['last']=0
            beats='One manual rear handle adjustment and recovery. The operator leans forward and visibly turns the existing rear crank with both hands, bending shoulders, elbows and knees. The round mirror gently tilts along its existing mount as he adjusts the handle. Then he smoothly restores the original mirror angle and ready stance. Both solid crystal rods remain inert and attached. All three original star feet remain planted, both wheels stay still. Empty uniform background throughout. The only movement is the operator arms/torso, control handle, small mirror angle and trailing cape. Continuous slow approach and return, no pose jump.'
        c.update(seed=seed,prompt=identity+'Use the same flat pale blue-gray background over the entire image in every frame. '+beats,correction_of=parent,visual_review='pending original video; original guides personally rechecked',selection='not_selected')
        folder=S/name;folder.mkdir(exist_ok=True)
        assert not (folder/'sampling_submission.json').exists()
        p.write(folder/'config.json',c);p.prepare(folder,c);p.verify(folder,c)
    print('BRACE_AND_SUPPORT_V1_REJECTED; TWO_NARROW_CORRECTIONS_PREPARED_UNSUBMITTED',flush=True)


if __name__=='__main__':main()
