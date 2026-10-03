"""Personally reviewed original action intervals; native engine review pending."""
import json
import produce as p

SELECTIONS = {
    'attack_h3_v2': {
        'source_frames': [0,6,8,10,12,14,18,26,28,30,32,33,34,36,40,52,60,61,62,63,64,65,66,67,68,70,74,78],
        'frame_msec': 50,
        'contact_frame': 12,
        'review_note': 'All124 original RGB frames, all124 enlarged RGBA and all124 fixed128px poses in each facing personally inspected in chronological order on alternating dark/light backgrounds. The same upper pincer opens and extends toward RIGHT, jaws close over frames32-34, hold empty, then retract over61-78. Lower pincer stays separate; walking feet brace, arch and three attached bronze rings remain coherent. No incoming ring, beam, flash, particles, copied reverse or interpolated motion. Contact is selected pose12/source34, the first fully closed jaw. Twenty-eight observed poses retain fast closure and continuous recovery; long still source holds are shortened with a provisional50ms gameplay cadence. Source24fps remains losslessly retained. Candidate engine timing and live acceptance pending; continuous playback is not claimed.'
    },
    'hit_h3_v1': {
        'source_frames': [0,6,7,8,9,10,11,12,13,14,16,20,36,48,49,50,51,52,53,54,55,56,58,60],
        'frame_msec': 50,
        'review_note': 'All124 original RGB, all124 enlarged RGBA and all124 fixed128px poses in each facing personally inspected chronologically on dark/light. A sudden articulated torso recoil and two-pincer lift occurs6-16, attached rings swing with the arch, then both joints lower and torso settles49-60. Six walking-leg identity is preserved with far-side occlusion and stable support; no attacker, impact effect, red pulse, fall or invented ornament. Twenty-four observed poses retain every rapid rise/recovery frame, shorten the long held recoil, and end in matching ready. Provisional50ms cadence still requires native engine review. No stabilization, per-frame fitting, reversed poses or interpolation; no continuous-playback claim.'
    }
}

def main():
    for take, selection in SELECTIONS.items():
        folder = p.SOURCE_DIR/take
        inventory=json.loads((p.ROOT/'.artifacts/fenmirror_gallowshell_h3'/take/'review_inventory.json').read_bytes())
        assert inventory['all_rgb_frames']==inventory['all_alpha_frames']==inventory['all_native_frames_each_facing']==124
        assert not inventory['border_issues']
        p.write(folder/'selection.json',selection)
        p.write(folder/'visual_review.json',dict(status='source_qualified_native_runtime_pending',all_original_rgb_frames_reviewed=124,all_original_alpha_frames_reviewed=124,all_native_frames_reviewed_each_facing=124,normal_and_reflected_dark_light=True,continuous_playback_reviewed=False,original_lossless_sha256=p.sha(folder/'original_lossless.mkv'),matte_sha256=p.sha(folder/'matte.json'),selected_original_pose_count=len(selection['source_frames']),notes=selection['review_note']))
        print('SOURCE_QUALIFIED_ONLY',take,len(selection['source_frames']),flush=True)

if __name__=='__main__':main()
