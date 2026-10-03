"""Record personally reviewed continuous original collapse; do not publish."""
import json,hashlib
import produce as p
import build_delivery as delivery

if __name__=='__main__':
    folder=p.SOURCE_DIR/'death_h3_v1'
    inventory=json.loads((p.ROOT/'.artifacts/fenmirror_gallowshell_h3/death_h3_v1/review_inventory.json').read_bytes())
    assert inventory['all_rgb_frames']==inventory['all_alpha_frames']==inventory['all_native_frames_each_facing']==124
    assert not inventory['border_issues']
    selection=dict(source_frames=[0,12,16,20]+list(range(22,98,2)),frame_msec=50,
        review_note='Personally reviewed all124 original RGB, all124 enlarged RGBA and all124 native128px poses in each facing chronologically against light/dark. Original ready lowers through six walking-knee folds20-32, jointed shell tilt35-76 and quiet grounded claw/arch/ring settling80-96. Both pincers retain serrated jaws, walking-leg identity and far-side occlusion remain coherent, all three attached hanging rings lower with the arch rather than flying. No cuts at guide boundaries32/74, fade, FX, replacement anatomy or recovery. Fixed original anatomical scale/ground anchor retained through crouch and low corpse; opaque tips remain complete and alpha8 border count is zero. Forty-two observed original poses shorten prolonged initial/terminal still holds, retain successive collapse phases and end in settled dim-eyed corpse. Provisional50ms cadence requires native timing review. No per-frame fitting, reverse duplication, interpolation or continuous-playback claim.')
    p.write(folder/'selection.json',selection)
    part=delivery.build('death_h3_v1')
    pixels=[hashlib.sha256(p.source_pose(f)[0].tobytes()).hexdigest() for f in part['frames']]
    assert len(pixels)==len(set(pixels))==42
    p.write(folder/'visual_review.json',dict(status='source_qualified_native_runtime_pending',all_original_rgb_frames_reviewed=124,all_original_alpha_frames_reviewed=124,all_native_frames_reviewed_each_facing=124,normal_and_reflected_dark_light=True,continuous_playback_reviewed=False,original_lossless_sha256=p.sha(folder/'original_lossless.mkv'),matte_sha256=p.sha(folder/'matte.json'),selected_original_pose_count=42,selected_original_pixels_unique=True,notes=selection['review_note']))
    delivery.build('death_h3_v1')
    takes=['move_h3_v1','attack_h3_v2','hit_h3_v1','defend_h3_v1','cast_h3_v1','death_h3_v1']
    p.write(p.SOURCE_DIR/'delivery.json',dict(unit_id=p.SOURCE_DIR.name,takes=takes,rejected_takes=['attack_h3_v1'],preserved_accepted_clips=['idle'],visual_review=dict(status='pending',all_original_takes_personally_reviewed=True,continuous_playback_reviewed=False,notes='Six original source-qualified H3 actions;204 new poses. All selected-source124 RGB/alpha/native both-facing chronologies personally reviewed, original connected-effect attack rejected/preserved. Dedicated gait40, pincer strike28/contact12/source34 and recovery, recoil24, crossed guard30, physical salute40 and grounded collapse42. Preserve eight original accepted270ms idle poses and melee ranged fallback; candidate/native timing and runtime acceptance pending.')))
    delivery.assemble()
    print('SIX_SOURCE_QUALIFIED_ACTIONS_ONLY;204_NEW_POSES;NATIVE_REVIEW_PENDING')
