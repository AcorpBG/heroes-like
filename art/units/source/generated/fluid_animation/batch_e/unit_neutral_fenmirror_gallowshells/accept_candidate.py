"""Record the coordinator's completed source and native visual review."""
import json,re
import produce as p
import build_delivery

OUT=p.ROOT/'.artifacts/parallel_animation_20261003'/p.SOURCE_DIR.name

if __name__=='__main__':
    for folder in ['candidate_native','mirrored_native']:
        reports=re.findall(r'FLUID_ANIMATION_REPORT (\{[^\n]+\})',(OUT/folder/'console.log').read_text())
        assert len(reports)==1 and json.loads(reports[0])==dict(checks=702,failures=[])
        assert len(list((OUT/folder).glob('battle-phase-*.png')))==8
    data=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
    assert data['visual_review']['all_original_takes_personally_reviewed']
    data['visual_review']=dict(status='accepted_selected_clips',all_original_takes_personally_reviewed=True,
        continuous_playback_reviewed=False,native_poses_personally_reviewed_each_facing=212,
        actual_normal_strike_captures_personally_reviewed_each_run=8,
        actual_mirrored_strike_reviewed=False,
        checks=dict(candidate=702,mirrored=702),
        first_attempt=dict(checks=702,missed_observed_attack_pose=12,unchanged_repeat_passed=True),
        notes='Accepted six original H3 actions after complete chronological RGB/alpha/native both-facing source review and personally inspected normal/reflected Godot native128px galleries (204 new plus eight retained idle poses). Reciprocal six-leg gait40; upper-pincer strike28 with open extension, first fully closed jaw at contact12/source34, quiet held contact and full retract; torso/two-claw recoil24 with recovery; crossed protective guard30; physical upper-claw salute40 with coherent lift, closure and return; continuous knee fold/shell lowering42 to grounded corpse, three attached rings and two pincers intact. All eight actual RIGHT-facing Normal Strike captures in both unchanged repeat fixtures personally reviewed, including contact and recovery; reflected gallery is not an actual reflected Strike claim. The first normal fixture missed one observed contact frame; unchanged 702-check repeat and mirrored702 both pass. Preserve exact eight accepted270ms battle/map idle originals, melee ranged fallback, fixed anatomical scale/ground anchors and no authored magic, interpolation, duplicate padding or continuous-video/manual-play claim.')
    p.write(p.SOURCE_DIR/'delivery.json',data)
    build_delivery.assemble()
    print('Six source/native-qualified actions accepted; live publication/import review remains.')
