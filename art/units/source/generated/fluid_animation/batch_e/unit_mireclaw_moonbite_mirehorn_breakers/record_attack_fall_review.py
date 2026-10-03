"""Record complete personal CPU source review, separate from Godot acceptance."""
import json
import produce as p
if __name__=='__main__':
 path=p.SOURCE_DIR/'source_review.json';r=json.loads(path.read_bytes())
 for take in ['attack_h3_v3','death_h3_v1']:
  out=p.SOURCE_DIR/take;assert len(json.loads((out/'matte.json').read_bytes())['rgba_sha256'])==124
 attack=json.loads((p.SOURCE_DIR/'attack_h3_v3'/'selection.json').read_bytes())
 r['takes']['attack_h3_v3']=dict(original_rgb_reviewed=124,matte_reviewed=124,enlarged_rgb_and_alpha_grips_paws_horns_reviewed=[0,12,18,24,30,38,44,48,54,60,64,68,70,74,78,82,86,90,96,108,123],selected_native_and_reflected_frames=attack['source_frames'],status='source_cpu_visual_pass_native_fixture_pending',notes='Continuous grounded crouch, forward horn/head and shoulder lean, contact and recovery. All four paws, two horns, two handler feet, left staff/right rein grips retained. No connected flash or hard pose replacement. All124 chronological original RGB and alpha,21 enlarged RGB/alpha landmarks and all38 actual128px poses in both facings on light/dark grounds personally inspected. Original fixed registration and scales retained. Godot fixture pending.')
 fall=json.loads((p.SOURCE_DIR/'death_h3_v1'/'selection.json').read_bytes())
 r['takes']['death_h3_v1']=dict(original_rgb_reviewed=124,matte_reviewed=124,enlarged_rgb_and_alpha_grips_paws_horns_reviewed=[0,16,30,38,44,48,52,56,60,64,66,68,70,72,74,75,76,77,78,82,90,108,123],selected_native_and_reflected_frames_reviewed_only=fall['source_frames'],status='rejected_preserved',notes='The beast settles coherently, but a second hooked shaft/leaf rises from the right rein hand52-62; the original left staff curls into a loop64-73, then the original ground-horizontal staff appears abruptly75-77. Rechecked original kneel/sidefall/corpse guides: only one left staff and right rein, original fallen staff horizontal. All124 RGB and alpha,23 enlarged RGB/alpha landmarks and33 historical selected128px poses both facings reviewed. Do not hide defective frames, paint gear or publish this source. Originals and complete matte retained.')
 p.write(path,r)
 print('ATTACK_V3_CPU_PASS_FALL_V1_REJECTED',flush=True)
