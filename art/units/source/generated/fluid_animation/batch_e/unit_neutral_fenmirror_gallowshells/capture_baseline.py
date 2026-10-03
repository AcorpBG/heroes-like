"""Snapshot this unit's unchanged live atlas/idle under the content mutex."""
import json, shutil
import produce as p
from creature_animation_lock import exclusive
from integrate_fluid_creature_animation import resolve

if __name__=='__main__':
    out=p.ROOT/'.artifacts/parallel_animation_20261003'/p.SOURCE_DIR.name;out.mkdir(parents=True,exist_ok=True)
    with exclusive('content'):
        battle=json.loads((p.ROOT/'content/unit_animation_manifest.json').read_bytes())
        row=next(r for r in battle['items'] if r['unit_id']==p.SOURCE_DIR.name)
        assert row==json.loads((p.SOURCE_DIR/'original_unit_baseline.json').read_bytes()),'Own row changed; preserve and investigate'
        mapping=json.loads((p.ROOT/'art/overworld/creature_idle.json').read_bytes())
        for name,data in [('manifest',battle),('map',mapping)]:
            file=out/f'initial_baseline_{name}.json'
            if not file.exists():p.write(file,data)
            assert (json.loads(file.read_bytes())['items'] if name=='manifest' else json.loads(file.read_bytes())['units']) is not None
        for dest,src in [('baseline_atlas.png',resolve(row['pose_sheet'])),('baseline_map_idle.png',resolve(mapping['units'][p.SOURCE_DIR.name]['path']))]:
            file=out/dest
            if file.exists():assert p.sha(file)==p.sha(src)
            else:shutil.copyfile(src,file)
    print('OWN ORIGINAL BATTLE AND EIGHT-PHASE MAP IDLE PRESERVED')
