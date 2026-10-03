"""Publish this reviewed unit only; retain a temporary exact comparison baseline."""
import json
import shutil
import produce as p
from creature_animation_lock import exclusive
from publish_fluid_creature_animation import publish

OUT=p.ROOT/'.artifacts/parallel_animation_20261003'/p.SOURCE_DIR.name

def main():
    baseline=OUT/'publication_baseline';baseline.mkdir(exist_ok=True)
    with exclusive('content'):
        assert not (baseline/'baseline_manifest.json').exists(), 'Do not overwrite original publication comparison'
        manifest=p.ROOT/'content/unit_animation_manifest.json'
        mapping=p.ROOT/'art/overworld/creature_idle.json'
        row=next(r for r in json.loads(manifest.read_bytes())['items'] if r['unit_id']==p.SOURCE_DIR.name)
        assert row==json.loads((p.SOURCE_DIR/'original_unit_baseline.json').read_bytes())
        m=json.loads(mapping.read_bytes())['units'][p.SOURCE_DIR.name]
        for source,target in [(manifest,'baseline_manifest.json'),(mapping,'baseline_map.json'),
                              (p.ROOT/row['pose_sheet'].removeprefix('res://'),'baseline_atlas.png'),
                              (p.ROOT/m['path'].removeprefix('res://'),'baseline_map_idle.png')]:
            shutil.copyfile(source,baseline/target)
        h=json.loads((p.SOURCE_DIR/'handoff.json').read_bytes())['units'][0]
        assert h['visual_review']['status']=='accepted_candidate_pending_import'
        result=publish(p.SOURCE_DIR/'handoff.json',list(h['clips']),h['visual_review']['notes'],['idle'])
    print(json.dumps(result),flush=True)

if __name__=='__main__':main()
