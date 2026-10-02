"""Publish six reviewed Charcoal Mauls actions; preserve accepted idle."""
import sys,json
import produce as p
sys.path.insert(0,str(p.ROOT/'tools'))
from publish_fluid_creature_animation import publish

NOTE=('Solo reviewed all124 chronological original frames in each of ten original H3 takes, enlarged hands/hammer/legs/collapse and every selected native128px pose in normal and mirrored rendering. '
      'Accepted reciprocal two-leg walk, two-handed hammer anticipation/contact/recovery, backward recoil, dedicated maul guard, diagonal shoulder-height physical rally salute and gradual grounded collapse with persistent corpse. '
      'Initial attack ghosted lifting hands are excluded; corrected windup and recovery retain original pixels. Corrected attack34/35 lose the hammer head and are excluded; first-take27-30 supply the physically matching overhead-to-forward release, with both grips and head intact. Native joins preserve posture, scale, camera and weapon arc. '
      'Initial salute enlarged/clipped the hammer and is rejected. Both intermediate-guided collapses held then jumped between postures and are rejected; endpoint-only third collapse supplies continuous knee descent, side roll and original weapon settling on the ground. '
      'Selected active motion runs42ms per observed original frame; shorten unchanged holds only. No synthetic interpolation, reversal, duplicate padding, sprite warping or per-pose normalization. '
      '807 candidate and807 reflected focused checks pass, including actual shell clock showing all51 strike poses and simulation/save invariance. Preserve eight accepted articulated idle poses and all overworld pixels/timing. '
      'Review used chronological stills, enlarged details and native clock-driven captures; no claim of continuous manual movie playback or manual game playtest. No full suite.')

if __name__=='__main__':
    d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
    d['visual_review']={'status':'accepted','notes':NOTE}
    p.write(p.SOURCE_DIR/'delivery.json',d)
    p.assemble()
    result=publish(p.SOURCE_DIR/'handoff.json',['move','attack','hit','defend','cast','death'],NOTE,['idle'])
    print(json.dumps(result))
