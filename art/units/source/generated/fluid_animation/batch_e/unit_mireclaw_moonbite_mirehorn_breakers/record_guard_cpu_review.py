"""Record personally inspected full source guard and selected game-scale poses."""
import json
import produce as p
if __name__=='__main__':
 out=p.SOURCE_DIR/'defend_h3_v2';s=json.loads((out/'selection.json').read_bytes());assert len(s['source_frames'])==24
 m=json.loads((out/'matte.json').read_bytes());assert len(m['rgba_sha256'])==124
 for i,h in enumerate(m['rgba_sha256']):assert p.sha(out/'matte'/f'rgba_{i:03}.png')==h
 review=json.loads((p.SOURCE_DIR/'source_review.json').read_bytes())
 review['takes']['defend_h3_v2']=dict(original_rgb_reviewed=124,matte_reviewed=124,enlarged_rgb_and_alpha_grips_paws_horns_reviewed=[0,6,16,24,30,38,42,48,54,58,60,62,70,94,121,123],selected_native_and_reflected_frames=s['source_frames'],status='source_cpu_visual_pass_native_fixture_pending',notes='Complete chronological original RGB124 reviewed, complete final transparent124 and nine enlarged whole poses, sixteen enlarged RGB/alpha grip/paw/horn landmarks and all24 actual128px selected poses both facings inspected. Connected lowering to the authentic grounded held brace; four paws, two horns, two handler feet, distinct left staff and right rein stay coherent. No invented bursts or guide-cut replacement. Strict global plate method stopped53, preserved separately. Unchanged pinned NN float alpha cached for all124; CPU source-observed local soft boundary recovery and protected original-palette plate-channel despill used without alpha/geometry changes, all53 prior strict alpha byte-identical. Fine original reeds and equipment remain visible; no detached matte plate/rectangular residue at128px. Original motion, inherited painting scale and fixed ground anchor retained. Godot native rendering remains pending.')
 p.write(p.SOURCE_DIR/'source_review.json',review);print('GUARD_CPU_VISUAL_PASS_GODOT_PENDING',flush=True)
