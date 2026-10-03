"""Prepare still-unsubmitted physical gestures without magical scene cues."""
import json
import produce as p

def main():
    corrected=json.loads((p.SOURCE_DIR/'attack_h3_v2/config.json').read_bytes())
    identity=corrected['prompt'].split('The upper forward pincer draws back')[0]
    beats={
        'defend_h3_v1':'An anatomical lowering and folding study. Walking legs spread slightly and load at the same ground origin while the torso lowers modestly; the two original pincer arms fold in front of the torso to the provided crossed protective pose. Maintain two independently attached pincers and original joints throughout. The last pose remains firmly braced and STILL; do not unfold to ready.',
        'cast_h3_v1':'One calm physical affirmation gesture using only original joints. Keep six walking feet planted and the torso upright. Raise the upper forward pincer with jaws CLOSED beside the back arch to the provided salute guide, pause deliberately, then lower the SAME closed pincer to the original ready pose. The lower foreground closed pincer stays separate and counterbalances quietly. Nothing is emitted or materializes anywhere. Original bronze rings only hang from their unchanged arch cords.',
        'death_h3_v1':'One continuous slow loss of support: the walking knees buckle and all six walking legs fold naturally, the armored torso lowers then rolls gently toward the provided grounded final pose. Both original pincers loosen and settle down with the same body; original back arch and its three bronze rings/moss cords settle under gravity. Maintain every original joint, plate and ornament throughout the transition. Reach the supplied low final pose on the SAME ground and remain completely STILL to the end. No fade, dissolve, disintegration, raised corpse, recovery or return to ready.'}
    for name,beat in beats.items():
        folder=p.SOURCE_DIR/name
        assert not (folder/'sampling_submission.json').exists(),name
        c=json.loads((folder/'config.json').read_bytes());c['prompt']=identity+beat
        p.write(folder/'config.json',c);p.prepare(folder,c)
    print('THREE UNSUBMITTED PHYSICAL GUIDE SETS REFINED; NO ACCEPTANCE OR GPU REQUEST')

if __name__=='__main__':main()
