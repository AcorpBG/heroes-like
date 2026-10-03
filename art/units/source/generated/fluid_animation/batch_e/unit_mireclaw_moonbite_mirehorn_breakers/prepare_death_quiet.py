"""Unsubmitted original fall guides, with ordinary joint movement wording."""
import json,shutil
import produce as p
from prepare import IDENTITY
if __name__ == '__main__':
 out=p.SOURCE_DIR/'death_h3_v1';assert not (out/'sampling_submission.json').exists()
 assert not (out/'config_pre_quiet_wording.json').exists()
 shutil.copyfile(out/'config.json',out/'config_pre_quiet_wording.json');shutil.copyfile(out/'prompt.txt',out/'prompt_pre_quiet_wording.txt')
 c=json.loads((out/'config.json').read_bytes())
 c['prompt']=(IDENTITY+'One continuous slow settling movement of both figures, connected by ordinary joint bending and gravity. The beast bends its front paw joints and lowers its shoulders into the supplied kneeling posture. Its near shoulder and hip progressively settle sideways onto the ground, with all four paws folding alongside the body into the supplied original side-lying endpoint. The handler bends both knees beside it, lowers his torso, then settles onto his near side beside the beast with the original staff and rein retained in the supplied endpoint. Each body part moves through smooth intermediate joint positions. Both figures end fully grounded in the supplied original side-lying endpoint and remain still for the final second. The hooked staff, rein, two horns, four paws, handler two legs, reeds, chains and small amber glass pieces remain original and attached throughout. Every amber glass piece retains its small painted appearance. A single plain flat magenta RGB255,0,255 background fills the entire frame throughout. Locked camera and original painting scale, fixed ground reference y576. Whole horns, mantle, staff, paws, feet and chains stay inside generous canvas margins.').strip()
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
 p.write(out/'source_wording_revision.json',dict(status='unsubmitted_preparation_change',reason='Guard original invented broad glow despite negative effect list. Use positive connected joint/settling movement and inert painted glass for still-unsubmitted fall, retaining every original ready/kneel/sidefall/corpse guide, seed, scale, anchor and model/quality setting. Preserve previous config/prompt.'))
 print('ORIGINAL_FALL_GUIDES_QUIET_WORDING_VERIFIED',flush=True)
