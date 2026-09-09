#!/usr/bin/env python3
"""Embercourt variant art: two authored orders, six fixture builds, five towns.

Reuses the accepted variant probe's complete rule, input, save and package
controls. Developed/isolated fixtures never count as earned progression.
"""
import json
import sys

import town_mireclaw_variant_regression as shared

ROOT, OUTPUT = shared.ROOT, shared.OUTPUT
SAVE_SHA256 = 'a3c565cc299de08f2970be3456b07d97a8fba628c288162f12c5360e7c89d6fe'
IDS = ['building_signal_citadel', 'building_charter_bastion',
       'building_embercourt_beaconline_charter_house',
       'building_embercourt_rainwrit_stormseal_treasury',
       'building_embercourt_amberweir_sluiceguard_lock',
       'building_embercourt_amberweir_counterweight_foundry']
AUTHORED_ORDERS = {'rainledger-amberweir-lockpike-trial': IDS[4],
                   'rainledger-amberweir-sluicebrand-works': IDS[5]}

RELIEF_OVERLAP = r'''
		if id=="building_embercourt_relief_quay":
			for foreground_id in ["building_embercourt_amberweir_counterweight_foundry","building_embercourt_rainwrit_stormseal_treasury"]:
				if not stage.validation_building_hotspot_summary(foreground_id).get("visible",false): continue
				var overlap: Vector2=button.get_global_transform_with_canvas()*(body*button.size)
				var front=stage._building_hotspots[foreground_id]
				var front_painted: bool=front._has_point(front.get_global_transform_with_canvas().affine_inverse()*overlap)
				check(front_painted or button._has_point(body*button.size),"Relief/quay overlap has no painted owner")
				var expected_owner: String=foreground_id if front_painted else id
				await layer_click(overlap)
				var foreground: Dictionary=shell.validation_building_information_snapshot(expected_owner)
				check(presses[0]==(0 if front_painted else 1) and foreground.open and foreground.mode=="building_info" and foreground.title==foreground.expected_title,"Relief quay overlap did not follow actual foreground paint")
				shell._close_town_catalog(false)
				presses[0]=0
				body=Vector2(0.35,0.12) # Exposed warehouse roof above the new permanent-quay buildings.
'''


def script_text():
    script = shared.script_text()
    for old, new in ((json.dumps(shared.IDS), json.dumps(IDS)),
                     (json.dumps(shared.AUTHORED_ORDERS), json.dumps(AUTHORED_ORDERS)),
                     ('faction_mireclaw', 'faction_embercourt'),
                     ('town_moonbite_reedshrine', 'town_amberweir_granary'),
                     ('unchanged_earned_duskfen', 'unchanged_earned_riverwatch')):
        assert old in script, 'shared variant contract changed: ' + old
        script = script.replace(old, new)
    needle = '\t\tif id=="building_quartermasters_depot" and stage._town_faction_id()=="faction_embercourt":'
    assert script.count(needle)==1, 'shared opaque-body input control changed'
    return script.replace(needle, RELIEF_OVERLAP+needle)


def script_for_resolution(resolution):
    return shared.script_for_resolution(resolution, script=script_text())


def main():
    return shared.main(expected_save_sha256=SAVE_SHA256,
                       save_description='exact earned Day-46 Riverwatch control save',
                       script_factory=script_for_resolution,
                       additional_owners=['tests/town_embercourt_variant_regression.py'],
                       description=__doc__)


if __name__ == '__main__':
    if '--platform' in sys.argv:
        import packaged_town_scene_layer_regression as packaged
        packaged.layers.main = main
        raise SystemExit(packaged.main())
    raise SystemExit(main())
