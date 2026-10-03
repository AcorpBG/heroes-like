"""Record personal complete source review without claiming native acceptance."""
import json
import produce as p
if __name__ == '__main__':
 path=p.SOURCE_DIR/'source_review.json';review=json.loads(path.read_bytes())
 for take,indices,status,notes in [
  ('attack_h3_v2',[0,12,18,30,44,45,46,47,48,49,50,51,54,58,62,66,70,75,90,96,102,123],'rejected_preserved','The quiet wording removes the invented starburst and preserves horns, paws and grips, but repeated windup/contact guides freeze those poses then produce an abrupt full-pose replacement at47-48. Both original and128px reflected chronology expose the cut. This take is not accepted; continuous thrust needs another correction with fewer repeated guide holds.'),
  ('hit_h3_v1',[0,20,32,40,44,48,52,60,64,70,74,78,86,100,123],'source_cpu_visual_pass_native_fixture_pending','Continuous original raised-front-paw recoil supported by hind paws, two intact horns and the original foreshortened faceplate/muzzle from guide7. Both handler grips, one staff, one rein and two boots stay coherent. Complete original RGB/alpha, enlarged whole group and15 raw grip/anatomy landmarks inspected; all28 selected poses inspected at128px both facings. No invented effect, clipping, new limbs or per-frame registration change. Godot fixture pending.'),
 ]:
  out=p.SOURCE_DIR/take
  assert json.loads((out/'original.json').read_bytes())['frames']==124
  assert len(json.loads((out/'matte.json').read_bytes())['rgba_sha256'])==124
  selection=json.loads((out/'selection.json').read_bytes())
  review['takes'][take]=dict(original_rgb_reviewed=124,matte_reviewed=124,enlarged_grips_paws_horns_reviewed=indices,selected_native_and_reflected_frames=selection['source_frames'],status=status,notes=notes)
 p.write(path,review)
 print('SOURCE_ACTION_REVIEW_RECORDED',flush=True)
