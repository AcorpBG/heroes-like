"""Preserve strict partial extraction; promote complete CPU trial for review."""
import json
from pathlib import Path
import produce as p
if __name__=='__main__':
 out=p.SOURCE_DIR/'defend_h3_v2';trial=out/'matte_local_plate_cpu'
 recipe=json.loads((out/'matte_local_plate_cpu.json').read_bytes())
 assert len(recipe['rgba_sha256'])==124 and len(list(trial.glob('rgba_*.png')))==124
 for i,h in enumerate(recipe['rgba_sha256']):assert p.sha(trial/f'rgba_{i:03}.png')==h
 original=out/'matte';archive=out/'matte_strict_partial';assert not archive.exists()
 files=sorted(original.glob('rgba_*.png'));assert len(files)==53
 p.write(out/'strict_partial_preservation.json',dict(reason='Strict original uniform-plate extractor stopped at frame53; preserve all53 original alpha/color exports. Full local trial pending personal visual review.',files=[dict(file=f.name,sha256=p.sha(f)) for f in files]))
 original.rename(archive);trial.rename(original)
 p.write(out/'matte.json',recipe)
 p.write(out/'segmentation_recipe.json',dict(method='Pinned unchanged NN alpha plus CPU original local boundary plate recovery',mask_cache_sha256=p.sha(out/'semantic_mask_cache.json'),cpu_recipe_sha256=p.sha(out/'matte_local_plate_cpu.json'),mask_tool_sha256=p.sha(p.SOURCE_DIR/'semantic_mask_cache.py'),cpu_tool_sha256=p.sha(p.SOURCE_DIR/'local_plate_cpu.py'),promote_tool_sha256=p.sha(Path(__file__)),strict_partial_preservation_sha256=p.sha(out/'strict_partial_preservation.json'),status='full_personal_alpha_and_native_review_pending'))
 print('GUARD_FULL_CPU_TRIAL_PROMOTED_FOR_VISUAL_REVIEW_NOT_ACCEPTED',flush=True)
