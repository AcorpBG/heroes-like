"""Personally inspected original guard/support frames; runtime review remains pending."""
import json
import hashlib
import produce as p
import build_delivery as delivery

SELECTIONS = {
    'defend_h3_v1': {
        'source_frames': [0,24,28,30] + list(range(32,57)) + [58],
        'frame_msec': 50,
        'review_note': 'Personally reviewed all124 original RGB, all124 enlarged RGBA and all124 fixed128px native poses in each facing chronologically on dark/light backgrounds. Legs widen and torso loads before both pincer joints rotate inward32-53 into a readable crossed protective guard48-58. Retain every32-56 transition frame; compress the long initial/terminal still holds. Two pincers remain separately attached, six walking legs retain support with natural far-side occlusion, arch and three suspended bronze rings stay coherent. No sparks, disk, incoming object, clipping, invented anatomy, reversed frames or interpolation. Thirty original poses at provisional50ms cadence; final pose is held guard. Source24fps retained losslessly. Candidate/native timing and actual gameplay review pending; chronological sheets are not continuous playback.'
    },
    'cast_h3_v1': {
        'source_frames': [0,8,10,12,14,16,18,20,22,24,26,28,30,32,34,35,40,42,43,44,45,46,47,48,56,62,64,66,68,70,72,74,76,78,80,82,84,86,88,90],
        'frame_msec': 50,
        'review_note': 'Personally reviewed all124 original RGB, all124 enlarged RGBA and all124 fixed128px native poses in each facing chronologically on dark/light. Actual physical support salute: the upper pincer lifts and extends12-35 while open, closes43-47, holds upright48-63, then lowers and reopens64-90 to ready. The generated motion differs from the requested closed-jaw throughout guide but remains coherent and appropriate; no claim of closed jaw throughout. Retain every closure frame43-48, reciprocal lift/lower joints and full recovery, shorten prolonged still holds. Lower foreground pincer remains separate counterbalance, walking feet remain planted, three attached rings and arch retain identity. No emission, unattached ring, extra limb, clipping or magic. Forty observed poses at provisional50ms cadence; dedicated support replaces idle alias after actual native review. No per-pose fitting, reverse copies or interpolation. Source24fps preserved; continuous playback and runtime acceptance remain pending.'
    }
}

def main():
    for take, selection in SELECTIONS.items():
        folder=p.SOURCE_DIR/take
        inventory=json.loads((p.ROOT/'.artifacts/fenmirror_gallowshell_h3'/take/'review_inventory.json').read_bytes())
        assert inventory['all_rgb_frames']==inventory['all_alpha_frames']==inventory['all_native_frames_each_facing']==124
        assert not inventory['border_issues']
        p.write(folder/'selection.json',selection)
        part=delivery.build(take)
        pixels=[hashlib.sha256(p.source_pose(frame)[0].tobytes()).hexdigest() for frame in part['frames']]
        assert len(pixels)==len(set(pixels)), 'Duplicate packed poses are not motion'
        p.write(folder/'visual_review.json',dict(status='source_qualified_native_runtime_pending',all_original_rgb_frames_reviewed=124,all_original_alpha_frames_reviewed=124,all_native_frames_reviewed_each_facing=124,normal_and_reflected_dark_light=True,continuous_playback_reviewed=False,original_lossless_sha256=p.sha(folder/'original_lossless.mkv'),matte_sha256=p.sha(folder/'matte.json'),selected_original_pose_count=len(selection['source_frames']),selected_original_pixels_unique=True,notes=selection['review_note']))
        delivery.build(take)
        print('SOURCE_QUALIFIED_ONLY',take,len(pixels),flush=True)

if __name__=='__main__':main()
