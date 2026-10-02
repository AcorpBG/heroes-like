"""Install this unit's scoped native/import proof helpers, preserving originals."""
import json,shutil
from pathlib import Path
import produce as p

UID='unit_neutral_noonshard_prism_kites'
OLD=p.SOURCE_DIR.parent/'unit_neutral_quenchbell_ironbacks'
OUT=p.ROOT/'.artifacts/parallel_animation_20261002'/UID
if __name__=='__main__':
    for name in ['capture_clock.py','run_native_review.py','run_mirrored_native.py','run_candidate_review.py','run_live_review.py','verify_imported_atlas.gd','verify_delivery.py','publish_selected.py']:
        target=p.SOURCE_DIR/name;assert not target.exists(),target
        text=(OLD/name).read_text(encoding='utf-8').replace('unit_neutral_quenchbell_ironbacks',UID).replace('quenchbell_ironback','noonshard_prism_kite').replace('Quenchbell Ironback','Noonshard Prism Kite').replace('QUENCHBELL_IRONBACK','NOONSHARD_PRISM_KITE').replace('ironback-import','noonshard-import').replace('Ironback texture','Noonshard texture')
        text=text.replace("['move','attack','hit','defend','cast','death']","['move','attack','ranged','hit','defend','cast','death']")
        text=text.replace("{'idle','move','attack','hit','defend','cast','death'}","{'idle','move','attack','ranged','hit','defend','cast','death'}")
        text=text.replace('Clipped original hoof/horn','Clipped original wing/tail')
        target.write_text(text,encoding='utf-8')
    ranged=p.ROOT/'art/units/source/generated/fluid_animation/batch_d/unit_neutral_sunscale_lanternmoths/run_ranged_native.py'
    (p.SOURCE_DIR/'run_ranged_native.py').write_text(ranged.read_text(encoding='utf-8').replace('LANTERNMOTH','NOONSHARD'),encoding='utf-8')
    rows=json.loads((OUT/'initial_baseline_manifest.json').read_bytes())['items']
    row=next(row for row in rows if row['unit_id']==UID)
    maprow=json.loads((OUT/'initial_baseline_map.json').read_bytes())['units'][UID]
    for name,path in [('baseline_atlas.png',row['pose_sheet']),('baseline_map_idle.png',maprow['path'])]:
        target=OUT/name;assert not target.exists(),target
        shutil.copyfile(p.ROOT/path.removeprefix('res://'),target)
    print('SCOPED_NATIVE_REFLECTED_RANGED_IMPORT_PROOFS_READY',flush=True)
