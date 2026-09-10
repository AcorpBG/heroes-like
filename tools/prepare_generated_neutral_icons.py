#!/usr/bin/env python3
"""Reuse exact original transparent paintings; no matting, redrawing or resizing."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]

def validate_assets(install=False):
    manifest=json.loads((ROOT/'art/overworld/manifest.json').read_text())
    checked=[]
    for asset,row in manifest['object_assets'].items():
        if row.get('presentation_role')!='generated_neutral_primary_unit': continue
        source=ROOT/row['source_generated'].removeprefix('res://')
        runtime=ROOT/row['path'].removeprefix('res://')
        assert source.is_file(),source
        expected=row['runtime_sha256']
        assert hashlib.sha256(source.read_bytes()).hexdigest()==expected,source
        if install and not runtime.exists():
            runtime.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(source,runtime)
        assert runtime.is_file(),runtime
        assert hashlib.sha256(runtime.read_bytes()).hexdigest()==expected,runtime
        checked.append(asset)
    assert checked,'No generated neutral original-source rows'
    catalog=json.loads((ROOT/'content/generated_neutral_encounter_profiles.json').read_text())
    profiles=catalog['profiles']
    expected_sites={'site_aetherglass_lens_house','site_embergrain_warm_granary','site_peatwax_reed_yard','site_verdant_graft_nursery','site_brass_scrip_mint','site_memory_salt_pan','site_generated_town_required_source_cache'}
    assert set(catalog['supplemental_sites'])==expected_sites,'Incomplete supplemental guard coverage'
    assert set(catalog['supplemental_sites'].values()) <= {p['encounter_id'] for p in profiles}
    armies={a['id']:a for a in json.loads((ROOT/'content/army_groups.json').read_text())['items']}
    encounters={e['id']:e for e in json.loads((ROOT/'content/encounters.json').read_text())['items']}
    units={u['id']:u for u in json.loads((ROOT/'content/units.json').read_text())['items']}
    assert len({p['encounter_id'] for p in profiles})==len(profiles)
    assert {p['tier'] for p in profiles}==set(range(1,8))
    for p in profiles:
        encounter=encounters[p['encounter_id']]
        army=armies[p['army_group_id']]
        assert encounter.get('affiliation')=='neutral'
        assert encounter['enemy_group_id']==army['id']
        assert p['tier']==units[army['stacks'][0]['unit_id']]['tier']
        row=manifest['object_assets'][p['asset_id']]
        unit=army['stacks'][0]['unit_id']
        assert row['source_generated']=='res://art/units/source/curated/'+unit+'.png',p
        assert not row.get('atlas_region'),p
        assert (ROOT/row['path'].removeprefix('res://')).is_file(),p
    return {'ok':True,'byte_exact_original_icons':len(checked),'profiles':len(profiles),'pixel_operations':[]}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install',action='store_true',help='Copy new original-source rasters to their registered runtime paths')
    args=parser.parse_args()
    print(json.dumps(validate_assets(args.install)))

if __name__=='__main__': main()
