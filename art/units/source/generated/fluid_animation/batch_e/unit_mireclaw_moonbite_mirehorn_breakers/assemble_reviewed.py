"""Assemble six source-qualified physical actions, retaining authentic idle."""
import argparse,json
import produce as p
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('takes',nargs=6);args=a.parse_args()
 review=json.loads((p.SOURCE_DIR/'source_review.json').read_bytes());clips=[]
 for take in args.takes:
  out=p.SOURCE_DIR/take;c=json.loads((out/'config.json').read_bytes());clips.append(c['clip'])
  r=review['takes'][take]
  assert r['status']=='source_cpu_visual_pass_native_fixture_pending',(take,r['status'])
  assert r['original_rgb_reviewed']==r['matte_reviewed']==124
  selection=json.loads((out/'selection.json').read_bytes())
  assert r['selected_native_and_reflected_frames']==selection['source_frames']
  assert min(selection['source_frames'])==0 and max(selection['source_frames'])==123
  assert not selection.get('runtime_projectile_separation') and not selection.get('original_pixel_exclusions')
  p.build(out,c)
 assert set(clips)=={'move','attack','hit','defend','cast','death'}
 p.write(p.SOURCE_DIR/'delivery.json',dict(takes=args.takes,preserved_accepted_clips=['idle'],visual_review=dict(status='pending',notes='Six physical Mirehorn Breaker sources passed complete original chronological RGB and alpha, enlarged grip/anatomy and actual128px both-facing CPU review. Preserve authentic four-paw beast, two-horn faceplate, two-legged handler, left single staff/right rein and original attached gear. Fixed inherited painting scales and ground registration, no pose synthesis or per-frame adjustment. Preserve original eight-pose battle/map idle260ms exactly. Melee ranged-to-attack fallback is retained; no authored ranged animation. Candidate/import/live Godot verification and personal capture review pending.')))
 p.assemble();print('ASSEMBLED_SIX_CPU_QUALIFIED_ACTIONS_NATIVE_PENDING',args.takes,flush=True)
