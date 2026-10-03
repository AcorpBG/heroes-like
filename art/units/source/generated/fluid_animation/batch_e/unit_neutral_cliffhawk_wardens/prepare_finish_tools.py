"""Adapt the successful bounded publication/Git recipe to this exact unit."""
from pathlib import Path
S=Path(__file__).parent;R=next(p for p in S.parents if (p/'project.godot').exists());C=R/'art/units/source/generated/fluid_animation/batch_e/unit_neutral_cinderwake_aurochs_matte_correction'
t=(C/'publish.py').read_text().replace('unit_neutral_cinderwake_aurochs','unit_neutral_cliffhawk_wardens').replace('CINDERWAKE','CLIFFHAWK')
t=t.replace("record=read(S/'extraction_recipe.json')","record=read(S/'composite_recipe.json')")
t=t.replace("assert sha(R/f['original'])==f['original_sha256'];assert sha(R/f['derived'])==f['derived_sha256']","assert sha(R/f['body'])==f['body_sha256'];assert sha(R/f['companion'])==f['companion_sha256'];assert sha(R/f['composite'])==f['composite_sha256']")
(S/'publish.py').write_text(t.rstrip()+'\n')
for name in ['commit_selected_unit.py','resume_scoped_commit.py']:
 t=(C/name).read_text().replace('unit_neutral_cinderwake_aurochs_matte_correction','unit_neutral_cliffhawk_wardens').replace('unit_neutral_cinderwake_aurochs','unit_neutral_cliffhawk_wardens').replace('Remove detached foreign matte fragments from Cinderwake death','Keep Cliffhawk companion flight inside the death canvas').replace('Correct Cinderwake detached death matte fragments','Keep Cliffhawk companion flight inside the death canvas').replace('Cinderwake','Cliffhawk')
 t=t.replace("+UID+'_matte_correction'","+UID").replace('Remove foreign Cliffhawk death alpha fragments','Keep Cliffhawk companion flight inside the death canvas')
 (S/name).write_text(t.rstrip()+'\n')
print('PREPARED_SCOPED_FINISH_TOOLS',flush=True)
