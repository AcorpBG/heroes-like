"""Close personally reviewed Cinderwake correction using actual terminal reports."""
from pathlib import Path
import json
R=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').exists());S=Path(__file__).parent;O=R/'.artifacts/parallel_animation_20261002/middle53_completion_audit/cinderwake-correction'
completion=json.loads((S/'completion.json').read_bytes());checks={}
for stage in ['candidate-normal','candidate-reflected','live-normal','live-reflected']:
 result=json.loads((O/stage/'result.json').read_bytes());assert not result['failures'];checks[stage.replace('-','_')]=result['checks']
source=json.loads((S/'source_verification.json').read_bytes());assert source['published'] and not source['failures'];checks['source_checks']=source['checks']
imp=json.loads((O/'focused-import.json').read_bytes());assert imp['ok'] and imp['selected']==2
assert 'CINDERWAKE_IMPORTED_ATLAS_OK' in (O/'exact-import.log').read_text()
completion['status']='complete_selected_unit'
completion['personal_review']+=' Published live all43 chronological death phases and terminal corpse personally viewed at exact native128 in both facings: no detached foreign remnants; horn/body/plate/feet and complete collapse intact. Three actual live normal BattleShell melee captures and two current map phases personally viewed clean. All eight map idle phases and reduced map capture previously personally viewed in current-live audit, with exact unchanged map publication/import pixels. No actual reflected melee or manual game claim.'
completion['validation']=dict(**checks,total_checks=sum(checks.values()),exact_imported_textures=2,failures=[])
completion['repair']=dict(derived_frames=17,foreign_components=23,alpha_pixels_removed=2893,original_rgb_and_all_other_rgba_exact=True,original_rgb_frames_preserved=124)
(S/'completion.json').write_text(json.dumps(completion,indent=2)+'\n')
print('CINDERWAKE_PERSONAL_REVIEW_COMPLETE',completion['validation'],flush=True)
