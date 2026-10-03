"""Personal original RGB decisions; extraction and native acceptance stay separate."""
import json
import produce as p
if __name__ == '__main__':
 path=p.SOURCE_DIR/'source_review.json';r=json.loads(path.read_bytes())
 r['takes']['defend_h3_v1']=dict(original_rgb_reviewed=124,partial_matte_preserved=121,status='rejected_preserved',notes='Invented expanding white/yellow sparks and lantern glows obscure the original mantle and lamps around6-52; a giant yellow disk grows behind the group64-70 and replaces the plate. The low brace itself is coherent, but this original effect is not accepted or painted away. Strict extraction stopped at121; partial alpha was preserved, not personally reviewed.')
 support=p.SOURCE_DIR/'cast_h3_v1';selection=json.loads((support/'selection.json').read_bytes());assert len(json.loads((support/'matte.json').read_bytes())['rgba_sha256'])==124
 r['takes']['cast_h3_v1']=dict(original_rgb_reviewed=124,matte_reviewed=124,enlarged_rgb_and_alpha_grips_paws_horns_reviewed=[0,16,20,26,30,38,44,52,60,66,70,75,79,90,108,116,123],selected_native_and_reflected_frames=selection['source_frames'],status='source_cpu_visual_pass_native_fixture_pending',notes='Continuous grounded group bow, original held staff lift, rise and return, handler left staff/right rein grips, two feet, four beast paws and two horns retained. Existing lamps remain contained and gear stays coherent. All124 original RGB and alpha, enlarged whole group and17 detailed RGB/alpha grip/anatomy landmarks inspected. All30 selected poses pass actual128 both facings on light/dark grounds. Thirty50ms chronological originals shorten source holds; no synthesized poses or per-frame registration change. Godot fixture pending.')
 p.write(path,r)
 f=p.SOURCE_DIR/'defend_h3_v1'/'extraction_failure.json';v=json.loads(f.read_bytes());v['status']='rejected_original_motion_preserved';v['original_motion_rejection']=r['takes']['defend_h3_v1']['notes'];p.write(f,v)
 print('GUARD_REJECTED_SUPPORT_RGB_QUALIFIED',flush=True)
