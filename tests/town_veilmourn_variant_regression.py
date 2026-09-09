#!/usr/bin/env python3
"""Veilmourn variant paintings: two real authored orders and labeled fixtures.

Preserves the accepted complete input/rule/save/package controls. Five developed
views and five isolated ledger builds are fixtures, not earned progression.
"""
import json
import sys

import town_mireclaw_variant_regression as shared

ROOT, OUTPUT = shared.ROOT, shared.OUTPUT
SAVE_SHA256 = '9d20f5cefc788faa88686fc1cabc46cc410997dda83be0c99066db3a5452e9e2'
IDS = ['building_veilmourn_wakeglass_chart_house',
       'building_veilmourn_saltwake_eulogy_house',
       'building_veilmourn_pale_sounding_last_memory_beacon',
       'building_veilmourn_dreamwake_tideglass_oratory',
       'building_veilmourn_dreamwake_foganchor_slip']
AUTHORED_ORDERS = {'wakeoracle-dreamwake-tideglass-trial': IDS[3],
                   'wakeoracle-dreamwake-foganchor-works': IDS[4]}


def script_text():
    script = shared.script_text()
    for old, new in ((json.dumps(shared.IDS), json.dumps(IDS)),
                     (json.dumps(shared.AUTHORED_ORDERS), json.dumps(AUTHORED_ORDERS)),
                     ('faction_mireclaw', 'faction_veilmourn'),
                     ('town_moonbite_reedshrine', 'town_dreamwake_oracle_harbor'),
                     ('unchanged_earned_duskfen', 'unchanged_earned_bellwake'),
                     ('exercised.size()==6,"not all six variant identities exercised"',
                      'exercised.size()==5,"not all five variant identities exercised"')):
        assert old in script, 'shared variant contract changed: ' + old
        script = script.replace(old, new)
    return script


def script_for_resolution(resolution):
    return shared.script_for_resolution(resolution, script=script_text())


def main():
    return shared.main(expected_save_sha256=SAVE_SHA256,
                       save_description='exact earned Day-30 Bellwake control save',
                       script_factory=script_for_resolution,
                       additional_owners=['tests/town_veilmourn_variant_regression.py'],
                       description=__doc__)


if __name__ == '__main__':
    if '--platform' in sys.argv:
        import packaged_town_scene_layer_regression as packaged
        packaged.layers.main = main
        raise SystemExit(packaged.main())
    raise SystemExit(main())
