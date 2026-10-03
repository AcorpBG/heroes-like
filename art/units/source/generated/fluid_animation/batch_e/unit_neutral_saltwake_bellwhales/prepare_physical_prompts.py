"""Keep unsubmitted action prompts anatomical after the obscuring-effect failure."""
import json,shutil
import produce as p
from prepare import IDENTITY, PLATE
actions={
 'hit':'One sudden physical backward startle. The intact closed-mouth head and torso jerk backward once, the two original pectoral fins fold closer to the belly, the same tail flukes lag and the five attached bells swing forward once. Recover smoothly to exact hovering ready. The whole original animal remains clearly visible throughout on a uniform stationary magenta field. Only the body, fins, flukes and original attached bells move. ',
 'defend':'One continuous compact hovering brace. Bow the original closed-mouth head slightly, fold both original pectoral fins toward the belly into the supplied compact pose, and angle the paired flukes to counterbalance. Keep the same intact torso hovering at its original height, hold this compact pose for the final second. Only the body, two fins, paired flukes and five attached original bells move. The whole animal stays clearly visible on a stationary uniform magenta field. ',
 'cast':'One slow physical head-bow and fin-fold salutation. Lift the intact closed-mouth head, draw both original pectoral fins inward toward the chest, bow the head deliberately while the attached original bells swing gently together, then spread the same two fins and lower the head back into exact hovering ready. Only the body, fins, flukes and five attached bells move. The original animal remains clearly visible, fixed body size, on a completely stationary uniform magenta field. ',
 'death':'One continuous physical sinking and side settling. The same intact whale stops its fin strokes, moves downward in place at constant body size, rolls gently onto its near side, and settles with its ventral body touching the fixed invisible ground plane in the supplied original side-resting pose. The original two pectoral fins fold and paired tail flukes settle beside the body. Five original bells and chains remain attached and settle naturally beside the intact torso. Final closed eye and mouth, grounded intact body, final second motionless. Only the animal and attached original bells move; the uniform magenta field remains completely stationary and the whole animal remains visible throughout. '
}
for clip,action in actions.items():
 out=p.SOURCE_DIR/(clip+'_h3_v1');assert not (out/'sampling_submission.json').exists()
 assert not (out/'config_initial.json').exists()
 for name in ['config.json','prompt.txt','workflow_api.json']:
  shutil.copyfile(out/name,out/(name.rsplit('.',1)[0]+'_initial.'+name.rsplit('.',1)[1]))
 c=json.loads((out/'config.json').read_bytes());before={f.name:p.sha(f) for f in out.glob('guide_*.png')}
 c['prompt']=(IDENTITY+action+PLATE).strip();p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
 assert before=={f.name:p.sha(f) for f in out.glob('guide_*.png')},'Original guide pixels changed'
 print('UNSUBMITTED_PHYSICAL_PROMPT_PREPARED',clip,flush=True)
