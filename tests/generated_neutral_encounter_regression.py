#!/usr/bin/env python3
"""Focused runtime contract; real generated-map/platform acceptance is separate."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = r'''extends Node
const Rules = preload("res://scripts/persistence/GeneratedNeutralEncounterRules.gd")
const Battle = preload("res://scripts/core/BattleRules.gd")
const Bridge = preload("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
var failures := []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func equivalent(a, b) -> bool:
	if (a is int or a is float) and (b is int or b is float): return float(a)==float(b)
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for index in range(a.size()):
			if not equivalent(a[index],b[index]): return false
		return true
	return a==b
# Median native creature value per tier on generated maps.
const SOURCE_VALUES := [60, 145, 336, 568, 983, 1669, 5931]
func unit_power(unit_id: String) -> float:
	return float(load("res://scripts/core/AiHeroRules.gd").army_power([{"unit_id":unit_id,"count":1}]))
func _ready() -> void:
	var identities := {}
	var formations := {}
	var group_counts := {}
	var kinds := {}
	var pools := {}
	var upgrade_mixes := 0
	var rate := float(ContentService.load_json(Rules.COMPANIES_PATH).power_per_native_value)
	check(rate > 0.0,"companies catalog has no exchange rate")
	for company in ContentService.load_json(Rules.COMPANIES_PATH).companies:
		check(not ContentService.get_encounter(String(company.encounter_id)).is_empty(),"company encounter definition missing: "+String(company.id))
	for tier in range(7):
		for subtype in range(20):
			var previous_power := -1.0
			for quantity in [1, 3, 9, 28, 75]:
				var placement := {"placement_id":"guard_%d_%d" % [tier, subtype], "kind":"guard", "x":4,"y":7,"level":1,"native_guard_quantity":quantity,"native_guard_level":tier,"native_guard_creature_subtype":subtype,"native_guard_ai_value":SOURCE_VALUES[tier],"encounter_id":"encounter_mire_raid","object_id":"encounter_mire_raid","package_guard_engagement_tiles":[{"x":4,"y":6,"level":1}]}
				var before := placement.duplicate(true)
				var result := Rules.resolve(placement)
				check(result.ok,"valid source metadata rejected")
				if not result.ok: continue
				check(placement == before,"source placement mutated")
				var encounter: Dictionary = result.encounter
				check(encounter == Rules.resolve(placement).encounter,"repeat conversion differs")
				var restored: Dictionary = JSON.parse_string(JSON.stringify(encounter))
				check(equivalent(restored,encounter),"JSON save roundtrip differs")
				check(encounter.x==placement.x and encounter.y==placement.y and encounter.level==placement.level and encounter.package_guard_engagement_tiles==placement.package_guard_engagement_tiles,"topology changed")
				var army: Dictionary = encounter.enemy_army
				var profile: Dictionary = encounter.generated_neutral_profile
				var total := 0
				var tolerance := 0.0
				var unit_ids := {}
				for stack in army.stacks:
					total += int(stack.count)
					unit_ids[String(stack.unit_id)] = true
					check(int(stack.count)>0 and not ContentService.get_unit(String(stack.unit_id)).is_empty(),"invalid generated stack")
				for unit_id in unit_ids:
					tolerance += unit_power(String(unit_id))
				var target := float(quantity * SOURCE_VALUES[tier]) * rate
				var power := float(load("res://scripts/core/AiHeroRules.gd").army_power(army.stacks))
				# Whole creatures: each unit rounds by at most one creature, and tiny budgets field one lead.
				check(absf(power-target)<=tolerance+0.5,"battle power does not follow the native budget: %s %.1f vs %.1f" % [encounter.encounter_id, power, target])
				check(target<20.0*tolerance or absf(power-target)<=0.05*target,"battle power drifts from a large native budget")
				check(absf(float(profile.power)-power)<=0.5 and int(profile.native_budget)==quantity*SOURCE_VALUES[tier],"company provenance does not match its army")
				check(power>=previous_power,"a larger native guard fields a weaker army")
				previous_power = power
				check(total==int(profile.total_quantity) and int(profile.source_quantity)==quantity,"headcount provenance lost")
				check(army.stacks.size()<=7,"army exceeds seven stacks")
				check(not ContentService.get_encounter(encounter.encounter_id).is_empty(),"guard encounter definition missing")
				check(Battle._enemy_army_for_encounter(encounter,ContentService.get_encounter(encounter.encounter_id))==army,"battle discarded generated composition")
				identities[encounter.encounter_id]=true
				formations[profile.formation]=true
				group_counts[army.stacks.size()]=true
				kinds[String(profile.kind).split("_")[0]]=true
				pools["faction" if String(profile.faction_id)!="" else "neutral"]=true
				for unit_id in unit_ids:
					if unit_ids.has(String(ContentService.get_unit(String(unit_id)).get("upgrade_to",""))):
						upgrade_mixes += 1
	check(identities.size()>=100,"too few distinct companies: %d" % identities.size())
	check(formations.size()==2 and group_counts.size()>=5,"missing formation/stack-count variety")
	check(kinds.size()>=10 and pools.size()==2,"missing company kinds or faction/neutral leads: %s" % str(kinds.keys()))
	check(upgrade_mixes>=20,"too few companies mixing a unit with its upgrade")
	for invalid in [-1,0,65536]:
		check(not Rules.resolve({"native_guard_quantity":invalid,"native_guard_level":0,"native_guard_creature_subtype":1,"native_guard_ai_value":60}).ok,"invalid quantity silently accepted")
	check(not Rules.resolve({"native_guard_quantity":9,"native_guard_level":0,"native_guard_creature_subtype":1,"native_guard_ai_value":0}).ok,"missing native value silently accepted")
	check(not Rules._apply_company({}, {"id":"probe","encounter_id":"encounter_company_missing","slots":[{"unit_id":"unit_river_guard","share":1.0}]}, 100.0).ok,"missing company encounter silently accepted")
	var catalog_company: Dictionary = ContentService.load_json(Rules.COMPANIES_PATH).companies[60]
	var no_art := catalog_company.duplicate(true)
	no_art["asset_id"] = "missing_original_art"
	check(not Rules._apply_company({}, no_art, 100.0).ok,"missing company art silently accepted")
	check(not Rules.resolve_supplemental({},"site_missing_mapping").ok,"unknown supplemental site silently accepted")
	check(not Rules._apply_profile({}, {"asset_id":"missing_original_art"}, 9).ok,"missing art silently accepted")
	var legacy := {"encounter_id":"encounter_mire_raid","enemy_army":{"stacks":[{"unit_id":"unit_bog_brute","count":2}]}}
	check(Rules.resolve(legacy).encounter==legacy,"legacy saved army rewritten")
	var old_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/overworld_cutout/native_day97_roundtrip.json"))
	check(SaveService.save_session(old_save, 1)!="","legacy fixture save failed")
	var old_restored = SaveService.restore_manual_session(1)
	check(old_restored!=null,"legacy fixture restore failed")
	if old_restored!=null:
		check(equivalent(old_restored.overworld.encounters,old_save.overworld.encounters),"legacy save encounters changed")
	var supplemental_ids := {}
	var supplemental_counts := {}
	for site_id in ContentService.load_json(Rules.PROFILES_PATH).supplemental_sites:
		for index in range(8):
			var placement := {"placement_id":"source_%s_%d" % [site_id,index],"encounter_id":"encounter_mire_raid","guard_value":600,"x":8,"y":9,"level":0,"guard_link":{"target_placement_id":"site_%d" % index}}
			var result := Rules.resolve_supplemental(placement,site_id)
			check(result.ok,"supplemental site mapping failed")
			if not result.ok: continue
			var encounter: Dictionary=result.encounter
			check(not encounter.has("native_guard_quantity"),"supplemental guard forged native metadata")
			check(encounter.guard_link==placement.guard_link and encounter.guard_value==600 and encounter.x==8 and encounter.y==9,"supplemental topology/link changed")
			check(Rules._army_strength(encounter.enemy_army)<=149,"supplemental strength ceiling increased")
			check(encounter==Rules.resolve_supplemental(placement,site_id).encounter,"supplemental mapping nondeterministic")
			supplemental_ids[encounter.encounter_id]=true
			supplemental_counts[encounter.generated_neutral_profile.total_quantity]=true
		var node := {"placement_id":"integration_"+site_id,"site_id":site_id,"x":8,"y":9,"level":1}
		var adopted := Bridge._supplemental_rare_source_guard(node)
		check(not adopted.is_empty(),"bridge rejected supplemental source")
		if not adopted.is_empty():
			check(adopted.generated_neutral_profile.site_id==site_id,"bridge selected wrong site mapping")
			check(adopted.guard_link.target_placement_id==node.placement_id and adopted.x==8 and adopted.y==9 and adopted.level==1,"bridge lost guard linkage/coordinates")
	check(supplemental_ids.size()==7 and supplemental_counts.size()>=3,"resource guards lack identity/headcount variety")
	print("NEUTRAL_VARIETY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"identities":identities.size(),"formations":formations.keys(),"stack_counts":group_counts.keys(),"kinds":kinds.keys(),"upgrade_mixes":upgrade_mixes}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''

def main():
    out = ROOT / '.artifacts/generated_neutral_variety_20260910'
    out.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='probe-', dir=out) as work, tempfile.TemporaryDirectory(prefix='heroes-neutral-data-') as user:
        work = Path(work)
        (work/'probe.gd').write_text(SCRIPT)
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="probe.gd" id="1"]\n[node name="Probe" type="Node"]\nscript = ExtResource("1")\n')
        env = dict(os.environ, XDG_DATA_HOME=user, XDG_CONFIG_HOME=user, XDG_CACHE_HOME=user)
        run = subprocess.run(['godot','--headless','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','res://'+str(scene.relative_to(ROOT))], env=env, capture_output=True, text=True, timeout=120)
        output = run.stdout + run.stderr
        (out/'focused.log').write_text(output)
        rows = [line.partition('NEUTRAL_VARIETY_REPORT ')[2] for line in output.splitlines() if line.startswith('NEUTRAL_VARIETY_REPORT ')]
        report = json.loads(rows[-1]) if rows else {'ok':False,'error':'no runtime report'}
        report['exit_code']=run.returncode
        report['ok']=report['ok'] and run.returncode==0 and 'SCRIPT ERROR' not in output and 'ERROR:' not in output
        (out/'focused.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps(report))
        return 0 if report['ok'] else 1

if __name__ == '__main__':
    raise SystemExit(main())
