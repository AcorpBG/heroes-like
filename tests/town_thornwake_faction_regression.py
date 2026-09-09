#!/usr/bin/env python3
"""Whole Thornwake art batch: real Large opening, authored orders, small fixtures.

The generated opening and two authored purchases are uninjected. Five developed
views and 28 isolated construction controls use the 66-tile Rootgate scenario
and are explicitly not earned progression or Large-map performance evidence.
Reuse the complete paid-rule, saved-state, alpha/input and package assertions.
"""
import json
import sys

import town_mireclaw_variant_regression as shared

ROOT, OUTPUT = shared.ROOT, shared.OUTPUT
SAVE_SHA256 = '3b42437d341d8e27b806c2fea5751fa362e02e836b5b311c79c51e99dd7c83a4'
BRIEFS_PATH = 'art/towns/source/generated/scene_layers/faction_thornwake/scene_briefs.json'
IDS = list(json.loads((ROOT / BRIEFS_PATH).read_text()))
AUTHORED_ORDERS = {
    'greenbarrow-woundroot-hearthseed-trial': 'building_thornwake_woundroot_hearthseed_nursery',
    'greenbarrow-woundroot-rootmaul-works': 'building_thornwake_woundroot_rootmaul_hollow',
}

UPGRADES = r'''
func thornwake_exposed_body(stage, button) -> Vector2:
	# Select a genuinely exposed painted patch, never alter z-order, controls,
	# opacity or input routing to accommodate a test. A fully hidden layer fails.
	var layout: Dictionary=get_tree().current_scene.validation_owner_town_layout_snapshot()
	for y in [0.35,0.45,0.55,0.25,0.65,0.15,0.75,0.85]:
		for x in [0.5,0.6,0.4,0.7,0.3,0.8,0.2,0.9,0.1]:
			var center: Vector2=Vector2(x,y)*button.size
			var exposed := true
			for offset in [Vector2.ZERO,Vector2(-3,0),Vector2(3,0),Vector2(0,-3),Vector2(0,3)]:
				var point: Vector2=center+offset
				var screen: Vector2=button.get_global_transform_with_canvas()*point
				if not button._has_point(point) or layout.footer_rect.has_point(screen) or layout.sidebar_rect.has_point(screen) or layout.header_rect.has_point(screen):
					exposed=false
					break
				if stage._main_building_hotspot.get_global_rect().has_point(screen):
					exposed=false
					break
				for other in stage._building_hotspots.values():
					if other==button or not other.visible or other.get_index()<button.get_index(): continue
					if other._has_point(other.get_global_transform_with_canvas().affine_inverse()*screen):
						exposed=false
						break
				if not exposed: break
			if exposed: return Vector2(x,y)
	check(false,"no usable exposed painted patch: "+button.name)
	return Vector2(-1,-1)

func inspect_thornwake_upgrade(id: String) -> void:
	var base: String=ContentService.get_building(id).get("upgrade_from","")
	if base=="": return
	var stage=get_tree().current_scene.get_node("%TownStage")
	var built: Array=TownRules.get_active_town(session).built_buildings
	check(base in built and id in built,"upgrade erased saved predecessor: "+id)
	check(not stage.validation_building_hotspot_summary(base).visible,"upgrade left ancestor painting visible: "+id)
	check(stage.validation_building_hotspot_summary(id).visible,"upgrade painting absent: "+id)
	check(stage._visible_town_plot_building_id([id,base],built)==id and stage._visible_town_plot_building_id([base,id],built)==id,"upgrade selection depends on plot order: "+id)
	var paintings: Dictionary=stage._building_scene_art_manifest.factions.faction_thornwake
	check(paintings[id].ground_anchor==paintings[base].ground_anchor,"upgrade changed scenic ground anchor: "+id)
	rows.append({"label":"same_site_upgrade_preserves_ancestor","building_id":id,"base_id":base})
'''


def script_text():
    script = shared.script_text()
    replacements = (
        (json.dumps(shared.IDS), json.dumps(IDS)),
        (json.dumps(shared.AUTHORED_ORDERS), json.dumps(AUTHORED_ORDERS)),
        ('faction_mireclaw', 'faction_thornwake'),
        ('town_moonbite_reedshrine', 'town_woundroot_hearthgrove'),
        ('unchanged_earned_duskfen', 'unchanged_generated_graftroot'),
        ('await save_variant("unchanged_generated_graftroot")',
         'await save_variant("unchanged_generated_graftroot")\n\tawait inspect_scene_layers(["building_thornwake_seed_vault","building_wayfarers_hall"])\n\tawait pay_variant("building_market_square","generated_large_market")'),
        ('var exercised := []',
         'var exercised := []\n\tvar small=ScenarioFactory.create_session("rootgate-toll","normal",SessionState.LAUNCH_MODE_SKIRMISH)\n\tvar small_fixture: Dictionary=small.to_dict()\n\tcheck(small_fixture.overworld.map_size.width*small_fixture.overworld.map_size.height==66,"fixture is not the authored 66-tile map")'),
        ('var fixture: Dictionary=earned.duplicate(true)',
         'var fixture: Dictionary=small_fixture.duplicate(true)'),
        ('if id not in catalog or id in exercised: continue',
         'if id not in template.buildable_building_ids or id in template.starting_building_ids or id in exercised: continue'),
        ('exercised.size()==6,"not all six variant identities exercised"',
         'exercised.size()==28,"not all 28 constructible Thornwake identities exercised"'),
        ('var prior: Dictionary=normalized(session.to_dict())\n\tvar cost:',
         'var ancestor: String=ContentService.get_building(id).get("upgrade_from","")\n\tif ancestor!="": check(stage.validation_building_hotspot_summary(ancestor).visible,"upgrade ancestor absent before purchase: "+id)\n\tvar prior: Dictionary=normalized(session.to_dict())\n\tvar cost:'),
        ('await save_variant(label)\n\tawait inspect_scene_layers([id])',
         'await save_variant(label)\n\tawait inspect_thornwake_upgrade(id)\n\tawait inspect_scene_layers([id])'),
        ('check(button._has_point(body*button.size),"authored pointer test point is not painted: "+id)',
         'if stage._town_faction_id()=="faction_thornwake": body=thornwake_exposed_body(stage,button)\n\t\tcheck(button._has_point(body*button.size),"authored pointer test point is not painted: "+id)'),
    )
    for old, new in replacements:
        assert old in script, 'shared variant contract changed: ' + old
        script = script.replace(old, new)
    return script + UPGRADES


def script_for_resolution(resolution):
    return shared.script_for_resolution(resolution, script=script_text())


def main():
    return shared.main(expected_save_sha256=SAVE_SHA256,
                       save_description='exact normal seed-10 Large Ardren/Graftroot opening',
                       script_factory=script_for_resolution,
                       additional_owners=['tests/town_thornwake_faction_regression.py', BRIEFS_PATH],
                       description=__doc__)


if __name__ == '__main__':
    if '--platform' in sys.argv:
        import packaged_town_scene_layer_regression as packaged
        packaged.layers.main = main
        raise SystemExit(packaged.main())
    raise SystemExit(main())
