"""CPU conditioning corrections after personal original-source review."""
import json
import produce as p
S=p.SOURCE_DIR
old=S/'attack_h3_v1'
p.write(old/'review.json',dict(status='rejected',original_sha256=p.sha(old/'original_lossless.mkv'),review='Personally viewed all124 original RGB and semantic RGBA chronologically, both facings at actual128px game scale, and enlarged punch36/60 and burst66. Same attached right fist articulates correctly, but a baked cup discharge at65..75 interrupts recovery, empties stone cup and relights crew. Cannot accept a complete punch by erasing or splicing this shot. Preserve complete original and provenance.'))
move=S/'move_h3_v1'
note='All124 original RGB/RGBA chronology and both actual128px facings personally reviewed; enlarged20/24/40/48/66/72/84/85/104 and fixed-original-pixel registration comparison20/40/50/65/66/80/84/85/104. Initial provisional20..65 range rejected on closer seam review because chassis drifts left before40. Selected uninterrupted complete gait cycle40..84: original two crew alternate bent-knee boot support/lift and recover matching lifted-leg phase, with three attached rotating wheels and matching hub/ground registration at40/84. Minor natural crew/chassis articulation remains; no translation stabilization, warps, duplicate padding or anatomy painting. Excluded early settling and later baked cup discharge107..114; complete original remains unchanged. Actual Godot full-unit acceptance pending.'
p.write(move/'selection.json',dict(source_frames=list(range(40,85)),matte_directory='matte_v3',frame_msec=42,review_note=note))
p.write(move/'review.json',dict(status='source_interval_accepted_pending_runtime',source_interval=[40,84],excluded_defect_interval=[107,114],original_sha256=p.sha(move/'original_lossless.mkv'),review=note))
p.build(move,json.loads((move/'config.json').read_bytes()))
out=S/'attack_h3_v2';out.mkdir(exist_ok=True)
assert not (out/'sampling_submission.json').exists()
c=json.loads((old/'config.json').read_bytes())
c['seed']=2026110321
c['guides']=[[25,1],[45,2],[65,2],[84,1],[103,0],[115,0]]
c['prompt']=c['prompt'].replace('No firing, throwing-arm swing, cannon barrel, invented weapon or effects; raised arm/cup/stone stay loaded and unchanged.','Throughout ALL124 frames the raised throwing arm, brass counterweight and claw cup remain locked in their exact original position and the SAME orange-fissured stone remains firmly seated and intact. The sole moving attack limb is the viewer-right human outer fist: retract beside shoulder25, extend straight45, hold contact65, withdraw by bending the same elbow84, resume original rope grip103, remain ready115 through end. Other worker stays at pump. Constant original lighting and loaded mechanism throughout.')
p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
for name,guides in [('hit',[[45,1],[82,0],[108,0]]),('defend',[[45,1],[78,1],[108,1]]),('cast',[[50,1],[66,1],[87,0],[110,0]]),('death',[[38,1],[82,2],[110,3]]),('ranged',[[20,1],[42,2],[68,3],[96,4],[113,1]])]:
 t=S/f'{name}_h3_v1';assert not (t/'sampling_submission.json').exists()
 cfg=json.loads((t/'config.json').read_bytes());cfg['guides']=guides
 if name in ['hit','defend','cast']:cfg['prompt']+=' The SAME stone stays firmly seated in the original cup throughout all124 frames. Constant original lighting.'
 if name=='hit':cfg['prompt']+=' Loaded arm gently lowers with chassis recoil to the original impact reference45, then returns to original loaded ready82; brass counterweight stays on its original pivot, without release.'
 if name=='defend':cfg['prompt']+=' Loaded arm settles to the original guarded reference angle as both operators lower behind the frame; brass counterweight stays on its original pivot and stone remains seated.'
 p.write(t/'config.json',cfg);p.prepare(t,cfg);p.verify(t,cfg)
d=json.loads((S/'delivery.json').read_bytes());d['takes']=['attack_h3_v2' if t=='attack_h3_v1' else t for t in d['takes']];d['failed_takes']=['attack_h3_v1'];d.pop('rejected_takes',None);p.write(S/'delivery.json',d)
print('CORRECTED_ORIGINAL_GUIDES_CPU; MOVE45_UNIQUE; ATTACK_V1_REJECTED')
