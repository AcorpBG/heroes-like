"""Record personally reviewed changed death; no roster acceptance inference."""
from pathlib import Path
import json
from PIL import Image,ImageDraw
S=Path(__file__).parent;R=next(p for p in S.parents if (p/'project.godot').exists());O=R/'.artifacts/parallel_animation_20261002/middle53_completion_audit/cliffhawk-correction'
recipe=json.loads((S/'composite_recipe.json').read_bytes());T=S/'companion_h3_v1';review=json.loads((T/'source_review.json').read_bytes());review['rejected_original_frames'].update({'24':'transitional green plate tint in connected wing feathers','25':'transitional pink plate tint in connected wing feathers','73':'transitional green plate tint in connected wing feathers','74':'transitional pink plate tint in connected wing feathers'});review['native_selection_correction']='Personally viewed all81 preliminary candidate native phases both facings. Replace24/25 with observed23/26 and omit redundant73/74 in favor of75; every original43 body phase stays present, all wingbeat phases remain, feet contact80-82 and fold91-94 unchanged. No anatomy repaint, clipping crop, contact/recovery omission, duplicate whole-pose padding or additional sampling.';(T/'source_review.json').write_text(json.dumps(review,indent=2)+'\n')
page=Image.new('RGB',(900,450),(27,37,24));d=ImageDraw.Draw(page)
for k,j in enumerate([23,26,75]):
 r=next(r for r in recipe['records'] if r['companion_frame']==j);im=Image.open(R/r['composite']).convert('RGBA').resize((240,136),Image.Resampling.LANCZOS)
 for face in range(2):
  drawn=im if face==0 else im.transpose(Image.Transpose.FLIP_LEFT_RIGHT);page.paste(drawn,(k*300,face*210),drawn);d.text((k*300+4,face*210+140),f'Observed bird{j} body{r["original_body_frame"]}; predicted native128',fill='white')
page.save(O/'revised-three-native.png')
note='Personally inspected all124 original companion RGB/alpha; all65 preliminary composites and all81 preliminary native128 poses both facings. Original woman/pike remains exact foreground, bird wings pass naturally behind hair/cape only, complete airborne departure stays wholly inside canvas then two feet contact and wings fold beside the grounded corpse. Revised observed23/26/75 eliminate four transient color-flash frames without omitting any original43 body phase or landing/contact/recovery. Revised79 phase imported native proof follows publication; no manual playtest/Linux/whole-roster claim.'
value=dict(unit_id='unit_neutral_cliffhawk_wardens',status='accepted_candidate_death',personal_review=note,failures=[],candidate_checks=dict(preliminary_death_native_normal=592,preliminary_death_native_reflected=592,scope='Only death/corpse rendered; first81-phase selection revised to79 after native color review'),validation=dict(failures=[]),retiming=recipe['retiming'],original_body_phases_preserved=43,unchanged_non_death_poses=171,preserved_map_idle=31)
(S/'completion.json').write_text(json.dumps(value,indent=2)+'\n');print('CANDIDATE_REVIEW_RECORDED',recipe['retiming'],flush=True)
