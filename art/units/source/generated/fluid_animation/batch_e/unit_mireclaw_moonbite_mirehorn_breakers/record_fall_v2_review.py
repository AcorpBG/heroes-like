"""Complete personal source review of the corrected original connected fall."""
import json
import produce as p
if __name__=='__main__':
 out=p.SOURCE_DIR/'death_h3_v2';selection=json.loads((out/'selection.json').read_bytes());assert len(selection['source_frames'])==33
 assert len(json.loads((out/'matte.json').read_bytes())['rgba_sha256'])==124
 path=p.SOURCE_DIR/'source_review.json';review=json.loads(path.read_bytes())
 review['takes']['death_h3_v2']=dict(original_rgb_reviewed=124,matte_reviewed=124,enlarged_rgb_and_alpha_grips_paws_horns_reviewed=[0,16,24,28,32,36,38,40,42,44,46,48,50,52,54,56,58,62,70,94,123],selected_native_and_reflected_frames=selection['source_frames'],status='source_cpu_visual_pass_native_fixture_pending',notes='Connected two-body lowering into authentic original side-lying corpse, with gradual equipment lowering instead of v1 hard horizontal-staff replacement. All124 RGB and alpha,21 enlarged RGB/alpha grip/paw/horn landmarks and33 selected actual128px poses both facings on light/dark ground inspected. Rechecked exact original kneel/sidefall/corpse guides: original sidefall includes a raised rear curved appendage behind the handler, which appears during this transition and settles with the original mantle. Distinct left held staff and right rein remain readable at actual game scale; original four paws, two horns, handler two legs and attached lamps retained. All original poses/projection and fixed inherited scales/anchor retained; no masking out transition frames or gear painting. Godot fixture pending.')
 p.write(path,review);print('FALL_V2_CPU_SOURCE_REVIEW_COMPLETE_NATIVE_PENDING',flush=True)
