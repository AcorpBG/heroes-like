#!/usr/bin/env python3
"""Cross-platform legal scene-driven town matches with isolated user storage.

Reuses the established full-match action policy without importing its POSIX
launcher. No resources, troops, positions or outcomes are injected. Small maps
are normal menu configurations. Bounded failure is never treated as victory.
"""
from __future__ import annotations
import argparse
import ast
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / '.artifacts/town_match_east_20260923'


def script(economy: bool = False) -> str:
    tree = ast.parse((ROOT / 'tests/generated_full_match_quality.py').read_text())
    source = next(ast.literal_eval(n.value) for n in tree.body
                  if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'SCRIPT' for t in n.targets))
    source = source.replace('var session\n', 'const TownEconomy = preload("res://scripts/core/TownDevelopmentRules.gd")\nvar session\n')
    # Observation belongs to the existing stream, so it records the same real
    # transaction boundary as the normal full-match driver.
    source = source.replace('"built": town.get("built_buildings", [])}',
        '"built": town.get("built_buildings", []), "available_recruits":town.get("available_recruits", {}), "growth":OverworldRules.town_weekly_growth(town, session), "shop_purchases":town.get("artifact_shop_purchases", {})}')
    source = source.replace('SettingsService.set_presentation_mode("windowed")', 'SettingsService.set_reduced_motion_enabled(true)\n\tSettingsService.set_presentation_mode("windowed")')
    source = source.replace('counts = resume.counts', 'counts = resume.counts.duplicate(true)')
    source = source.replace('checkpoint_labels = resume.checkpoint_labels', 'checkpoint_labels = resume.checkpoint_labels.duplicate(true)')
    source = source.replace('scene.validation_action_catalog()', 'town_catalog(scene)')
    source = source.replace('scene.validation_perform_town_action(selected)', 'town_rule_order(scene, selected, lane)')
    source = source.replace('scene.validation_perform_town_action(transfer)', 'town_rule_order(scene, transfer, "transfer")')
    source = source.replace('# The shipped catalog determines eligibility and normal costs. Never inject stock.', '# The shipped catalog determines eligibility and normal costs. Never inject stock.\n\tvar pending_catalog := {}')
    source = source.replace('var catalog: Dictionary = town_catalog(scene)', 'if pending_catalog.is_empty(): pending_catalog = town_catalog(scene)\n\t\t\tvar catalog: Dictionary = pending_catalog')
    source = source.replace('var result: Dictionary = town_rule_order(scene, selected, lane)', 'var result: Dictionary = town_rule_order(scene, selected, lane)\n\t\t\tpending_catalog = {} # Re-read eligibility after every real transaction.')
    source = source.replace('for action in town_catalog(scene).get("transfer", []):', 'if pending_catalog.is_empty(): pending_catalog = town_catalog(scene)\n\t\tfor action in pending_catalog.get("transfer", []):')
    source = source.replace('transfer_id.ends_with(":all") and not bool', '(transfer_id.ends_with(":all") or transfer_id.ends_with(":1") and not pending_catalog.get("transfer",[]).any(func(row):return String(row.get("id","")) == transfer_id.trim_suffix(":1")+":all")) and not bool')
    source = source.replace('var result: Dictionary = town_rule_order(scene, transfer, "transfer")', 'var result: Dictionary = town_rule_order(scene, transfer, "transfer")\n\t\tpending_catalog = {}')
    source = source.replace('\tvar leave: Dictionary = scene.validation_leave_town()', '\tawait improve_stationed_army()\n\tvar leave: Dictionary = scene.validation_leave_town()')
    source = source.replace('func town_orders() -> void:', '''func town_catalog(scene) -> Dictionary:
\t# Match TownShell's production read scope; never retain it over a mutation.
\tTownRules.begin_read_scope(session)
\tvar result: Dictionary = scene.validation_action_catalog()
\tTownRules.end_read_scope(session)
\treturn result

func improve_stationed_army() -> void:
\tif not bool(cfg.get("core_town_actions",false)): return
\tfor attempt in range(Heroes.ARMY_SLOT_COUNT):
\t\tvar town: Dictionary = TownRules.get_active_town(session)
\t\tvar hero_id := String(session.overworld.get("active_hero_id",""))
\t\tif hero_id not in Heroes._stationed_holder_ids(session,town): return
\t\tvar field: Array = Heroes._holder_stacks(session,town,hero_id)
\t\tvar reserve: Array = Heroes._holder_stacks(session,town,"garrison")
\t\tvar weakest := -1
\t\tvar strongest := -1
\t\tfor index in range(field.size()):
\t\t\tif weakest < 0 or power([field[index]]) < power([field[weakest]]): weakest = index
\t\tfor index in range(reserve.size()):
\t\t\tif strongest < 0 or power([reserve[index]]) > power([reserve[strongest]]): strongest = index
\t\tif weakest < 0 or strongest < 0 or power([reserve[strongest]]) <= power([field[weakest]]): return
\t\tvar started := Time.get_ticks_usec()
\t\tvar before := player_power()
\t\tvar incoming: Dictionary = reserve[strongest].duplicate(true)
\t\tvar displaced: Dictionary = field[weakest].duplicate(true)
\t\tvar source_slot := int(incoming.get("slot_index",strongest))
\t\tvar target_slot := int(displaced.get("slot_index",weakest))
\t\tvar result := TownRules.manage_army_slots_in_active_town(session,"garrison",source_slot,hero_id,target_slot,"all")
\t\tawait settle()
\t\trecord("town_army_swap",started,{"ok":result.get("ok",false),"message":result.get("message",""),"incoming":incoming,"displaced":displaced,"power_before":before,"power_after":player_power()})
\t\tif not bool(result.get("ok",false)):
\t\t\tfailures.append("legal stationed army replacement rejected: "+String(result.get("message","")))
\t\t\treturn

func town_rule_order(scene, action_id: String, lane: String) -> Dictionary:
\tif not bool(cfg.get("core_town_actions",false)):
\t\treturn scene.validation_perform_town_action(action_id)
\t# These are precisely the production transactions called by TownShell.
\t# Their visitor, costs, caps, prerequisites and finalization still apply.
\tmatch lane:
\t\t"build": return TownRules.build_active_town(session,action_id.trim_prefix("build:"))
\t\t"recruit": return TownRules.recruit_active_town(session,action_id.trim_prefix("recruit:"))
\t\t"market": return TownRules.perform_market_action(session,action_id)
\t\t"response": return TownRules.perform_response_action(session,action_id)
\t\t"artifact": return TownRules.manage_artifact_at_active_town(session,action_id)
\t\t"specialty": return TownRules.choose_specialty_at_active_town(session,action_id.trim_prefix("choose_specialty:"))
\t\t"study": return TownRules.learn_spell_at_active_town(session,action_id.trim_prefix("learn_spell:"))
\t\t"transfer": return TownRules.transfer_in_active_town(session,action_id)
\treturn {"ok":false,"message":"unsupported production rule lane"}

func town_orders() -> void:''')
    source = source.replace('"input_method":"scene pointer/actions; shipped Quick Resolve; production save API and router resume"', '"input_method":"production town rule transactions; scene adventure; shipped Quick Resolve; production save API and router resume" if bool(cfg.get("core_town_actions",false)) else "scene pointer/actions; shipped Quick Resolve; production save API and router resume"')
    source = source.replace('serial += 1\n\tcounts[kind]', 'if kind in ["town_build","town_recruit","town_response"] and bool(result.get("ok",false)):\n\t\tlast_progress_day = session.day # Actual paid construction/muster/service progress.\n\tserial += 1\n\tcounts[kind]')
    source = source.replace('win-seeking driver made no exploration/interaction progress for fourteen days', 'win-seeking driver made no field or paid town-development progress for fourteen days')
    source = source.replace('\t\telif scene_path().ends_with("BattleReportShell.tscn"):', '''\t\telif scene_path().ends_with("OverworldShell.tscn") and is_instance_valid(scene._hero_level_up_dialog) and scene._hero_level_up_dialog.visible:
\t\t\tvar started := Time.get_ticks_usec()
\t\t\tvar prompt: Dictionary = OverworldRules.get_level_up_prompt(session)
\t\t\tvar options: Array = prompt.get("choice",{}).get("options",[])
\t\t\tvar selected := "" if options.is_empty() else String(options[0])
\t\t\tif selected == "": scene._hero_level_up_dialog.review_dismissed.emit()
\t\t\telse: scene._hero_level_up_dialog.specialty_selected.emit(selected)
\t\t\tawait settle()
\t\t\trecord("hero_level_choice",started,{"specialty":selected})
\t\telif scene_path().ends_with("BattleReportShell.tscn"):''')
    source = source.replace('var resupply := reinforcement_target()', '''# An ordinary defensive opening keeps the commander and purchased troops
\t# in town while production AI takes its normal turns.
\tif session.day <= int(cfg.get("defend_until_day",0)):
\t\treturn {}
\tvar resupply := reinforcement_target()''')
    source = source.replace('if session.day - last_progress_day > 14:', 'if session.day > int(cfg.get("defend_until_day",0)) + 14 and session.day - last_progress_day > 14:')
    source = source.replace('\t\tvar turn: Dictionary = get_tree().current_scene._request_end_turn(false)', '''\t\tvar blocked_reason := String(get_tree().current_scene._overworld_gameplay_movement_blocked_reason())
\t\tif blocked_reason != "":
\t\t\tfailures.append("unhandled input owner before End Turn: " + blocked_reason)
\t\t\tbreak
\t\tvar turn: Dictionary = get_tree().current_scene._request_end_turn(false)''')
    source = source.replace('\t\telif scene_path().ends_with("BattleReportShell.tscn"):', '''\t\telif scene_path().ends_with("OverworldShell.tscn") and is_instance_valid(scene._resource_reward_dialog) and scene._resource_reward_dialog.visible:
\t\t\tvar started := Time.get_ticks_usec()
\t\t\tvar before: Dictionary = session.overworld.resources.duplicate(true)
\t\t\tscene._resource_reward_dialog.custom_action.emit(&"gold")
\t\t\tawait settle()
\t\t\trecord("resource_reward_choice",started,{"choice":"gold","before":before,"after":session.overworld.resources.duplicate(true)})
\t\telif scene_path().ends_with("BattleReportShell.tscn"):''')
    if economy:
        source = source.replace('last_town_day[id] = session.day', 'last_town_day[id] = session.day\n\tvar development_goal := construction_goal()')
        source = source.replace('["specialty", "build", "recruit", "study"]', '["specialty", "market", "build", "response", "recruit", "artifact", "study"]')
        source = source.replace('\tvar pending_catalog := {}', '\tvar pending_catalog := {}\n\tvar protect_home := bool(cfg.get("prioritize_home_tier6",false)) and String(town.get("faction_id","")) != String(cfg.faction) and not home_has_tier6_recruit()')
        source = source.replace('\t\tvar used := {}', '\t\tif protect_home and lane in ["market","build","recruit","study"]: continue\n\t\tvar used := {}')
        source = source.replace('\t\tvar used := {}', '\t\tif lane == "recruit":\n\t\t\tawait fund_recruit_supply(scene,development_goal)\n\t\t\tpending_catalog = {}\n\t\tvar used := {}')
        source = source.replace('12 if lane in ["recruit", "specialty"] else 1', '16 if lane in ["recruit", "specialty", "market", "response", "artifact"] else 1')
        source = source.replace('if lane != "specialty":', 'if lane not in ["specialty", "market"]:')
        source = source.replace('var choices: Array = catalog.get(lane, []).duplicate()', 'var choices: Array = catalog.get(lane, []).duplicate()\n\t\t\tif lane == "recruit": choices.sort_custom(func(a,b):return int(a.get("unit_tier",1)) > int(b.get("unit_tier",1)))')
        source = source.replace('not bool(action.get("disabled",true)) and not used.has', 'not bool(action.get("disabled",lane != "artifact")) and not used.has')
        needle = '\t\t\tfor action in choices:\n'
        source = source.replace(needle, needle + '''\t\t\t\tvar aid := String(action.id)
\t\t\t\tvar goal: Dictionary = development_goal
\t\t\t\tvar reserve: Dictionary = goal.get("cost",{}).duplicate(true)
\t\t\t\tif lane in ["recruit","response","study"] and not reserve.is_empty(): reserve.gold = int(goal.get("required_gold_total",reserve.get("gold",0)))
\t\t\t\tif lane == "build" and aid != String(goal.get("id","")):
\t\t\t\t\tcontinue
\t\t\t\tif lane == "market":
\t\t\t\t\tif goal.is_empty() or not aid.ends_with(":1") or int(town.get("last_build_day",0)) == session.day:
\t\t\t\t\t\tcontinue
\t\t\t\t\tvar readiness := OverworldRules.town_cost_readiness(TownRules.get_active_town(session),session.overworld.resources,reserve,session.day)
\t\t\t\t\tif not bool(readiness.get("market_affordable",false)): continue
\t\t\t\t\tvar resource := aid.split(":")[2]
\t\t\t\t\tvar amount := int(session.overworld.resources.get(resource,0))
\t\t\t\t\tvar needed := int(reserve.get(resource,0))
\t\t\t\t\tvar gold_ready: bool = int(session.overworld.resources.get("gold",0)) >= int(readiness.get("required_gold_total",0))
\t\t\t\t\tif aid.begins_with("market:buy:") and (amount >= needed or not gold_ready): continue
\t\t\t\t\tif aid.begins_with("market:sell:") and (amount <= needed or gold_ready): continue
\t\t\t\tif lane == "recruit" and (session.day % 7 != 1 or player_power() >= 1000) and not reserve.is_empty():
\t\t\t\t\tvar protects_build := true
\t\t\t\t\tfor resource in action.get("unit_cost",{}):
\t\t\t\t\t\tvar spend: int = int(action.unit_cost[resource]) * int(action.get("direct_affordable_count",0))
\t\t\t\t\t\tif int(session.overworld.resources.get(resource,0)) - spend < int(reserve.get(resource,0)):
\t\t\t\t\t\t\tprotects_build = false
\t\t\t\t\tif not protects_build:
\t\t\t\t\t\tcontinue
\t\t\t\tif lane == "response":
\t\t\t\t\tif protect_home and aid != "stabilize_recovery": continue
\t\t\t\t\tvar service_cost := planned_service_cost(aid)
\t\t\t\t\tvar preserves_budget := true
\t\t\t\t\tfor resource in service_cost:
\t\t\t\t\t\tif int(session.overworld.resources.get(resource,0)) - int(service_cost[resource]) < int(reserve.get(resource,0)): preserves_budget = false
\t\t\t\t\tif not preserves_budget and not aid.begins_with("town_buy:") and not aid.begins_with("town_sell:"): continue
\t\t\t\t\tif aid.begins_with("town_sell:"):
\t\t\t\t\t\tif int(counts.get("artifact_sale",0)) > 0: continue
\t\t\t\t\telif aid.begins_with("town_buy:"):
\t\t\t\t\t\tif int(counts.get("artifact_purchase",0)) > 1: continue
\t\t\t\t\telif not aid.begins_with("town_upgrade:") and not aid.begins_with("town_train:") and not aid.begins_with("town_faction:") and aid != "stabilize_recovery":
\t\t\t\t\t\tcontinue
\t\t\t\tif lane == "artifact" and not aid.begins_with("equip_artifact:"):
\t\t\t\t\tcontinue
\t\t\t\tif lane == "artifact" and String(action.get("label","")).begins_with("Swap In"):
\t\t\t\t\tcontinue # Fill empty slots without repeatedly exchanging occupied gear.
\t\t\t\tif lane == "study" and int(session.overworld.resources.get("gold",0)) < int(reserve.get("gold",0)) + 2000:
\t\t\t\t\tcontinue
''')
        source = source.replace('record("town_"+lane,started,', '''if bool(result.get("ok",false)):
\t\t\t\tif lane == "build": development_goal = construction_goal()
\t\t\t\tif selected.begins_with("town_buy:"): counts["artifact_purchase"] = int(counts.get("artifact_purchase",0))+1
\t\t\t\tif selected.begins_with("town_sell:"): counts["artifact_sale"] = int(counts.get("artifact_sale",0))+1
\t\t\trecord("town_"+lane,started,''')
        start = source.index('func build_priority(')
        end = source.index('func known(', start)
        source = source[:start] + '''func home_has_tier6_recruit() -> bool:
\tvar stacks: Array = session.overworld.get("army",{}).get("stacks",[]).duplicate(true)
\tfor town in session.overworld.get("towns",[]):
\t\tif String(town.get("owner","")) == "player": stacks.append_array(town.get("garrison",[]))
\tfor stack in stacks:
\t\tvar unit: Dictionary = ContentService.get_unit(String(stack.get("unit_id","")))
\t\tif String(unit.get("faction_id","")) == String(cfg.faction) and int(unit.get("tier",0)) >= 6 and int(stack.get("count",0)) > 0: return true
\treturn false

func fund_recruit_supply(scene, goal: Dictionary) -> void:
\tvar town: Dictionary = TownRules.get_active_town(session)
\tvar market: Dictionary = OverworldRules.town_market_state(town)
\tvar imports: Array = market.get("import_resources",[])
\tif imports.is_empty(): return
\tvar catalog := town_catalog(scene)
\tvar recruits: Array = catalog.get("recruit",[]).duplicate()
\trecruits.sort_custom(func(a,b):return int(a.get("unit_tier",1)) > int(b.get("unit_tier",1)))
\tfor action in recruits:
\t\tif int(action.get("available_count",0)) <= 0 or int(action.get("market_affordable_count",0)) <= 0: continue
\t\tvar cost: Dictionary = action.get("unit_cost",{})
\t\tvar missing := {}
\t\tfor resource in imports:
\t\t\tvar deficit := maxi(0,int(cost.get(resource,0))-int(session.overworld.resources.get(resource,0)))
\t\t\tif deficit > 0: missing[resource] = deficit
\t\tif missing.is_empty(): continue
\t\tvar quote := OverworldRules.town_cost_readiness(town,session.overworld.resources,cost,session.day)
\t\tvar reserve := int(goal.get("required_gold_total",goal.get("cost",{}).get("gold",0)))
\t\tif session.day % 7 == 1 and player_power() < 1000: reserve = 0
\t\tif int(session.overworld.resources.get("gold",0)) < reserve + int(quote.get("required_gold_total",cost.get("gold",0))): continue
\t\tfor resource in missing:
\t\t\tfor quantity in range(int(missing[resource])):
\t\t\t\tvar id := "market:buy:%s:1" % resource
\t\t\t\tvar options: Array = town_catalog(scene).get("market",[])
\t\t\t\tif not options.any(func(row):return String(row.get("id","")) == id and not bool(row.get("disabled",true))): return
\t\t\t\tvar started := Time.get_ticks_usec()
\t\t\t\tvar result := town_rule_order(scene,id,"market")
\t\t\t\tawait settle()
\t\t\t\trecord("town_market",started,{"id":id,"ok":result.get("ok",false),"message":result.get("message",""),"purpose":"recruit_supply","unit":action.id})
\t\t\t\tif not bool(result.get("ok",false)):
\t\t\t\t\tfailures.append("enabled recruitment import failed: "+id)
\t\t\t\t\treturn
\t\treturn # Fund one real high-tier recruit, then re-read the recruitment catalog.

func build_priority(action: Dictionary) -> int:
\tvar id := String(action.get("id","")).trim_prefix("build:")
\tvar fixed := {"building_dev_storehouse_1":0,"building_market_square":2,"building_dev_hall_2":3,"building_dev_growth_1":10,"building_dev_artifact_exchange":11,"building_dev_storehouse_2":13,"building_dev_hall_3":14,"building_dev_fort_1":15,"building_dev_growth_2":17,"building_dev_trade_exchange":19,"building_dev_hall_4":20}
\tif fixed.has(id): return int(fixed[id])
\tvar building: Dictionary = ContentService.get_building(id)
\tvar unit: Dictionary = ContentService.get_unit(String(building.get("unlock_unit_id","")))
\tif not unit.is_empty():
\t\tvar tier := int(unit.get("tier",1))
\t\tvar ranks := {1:1,2:5,3:8,4:16,5:18,6:21,7:23}
\t\treturn int(ranks.get(tier,25)) + (3 if tier == 1 and unit.has("upgrade_from") else (1 if unit.has("upgrade_from") else 0))
\tif not building.get("income",{}).is_empty(): return 12
\treturn 30

func planned_service_cost(action_id: String) -> Dictionary:
\tvar parts := action_id.split(":")
\tif parts[0] == "town_buy": return {"gold":TownEconomy.price(ContentService.get_artifact(parts[1]))}
\tif parts[0] == "town_faction": return ContentService.get_building(parts[1]).get("faction_service",{}).get("cost",{})
\tif parts[0] == "town_upgrade":
\t\tvar town: Dictionary = TownRules.get_active_town(session)
\t\tvar count := 0
\t\tfor stack in Heroes._holder_stacks(session,town,parts[1]):
\t\t\tif String(stack.get("unit_id","")) == parts[2]: count += int(stack.get("count",0))
\t\tfor id in TownEconomy.active_buildings(town):
\t\t\tvar target := String(ContentService.get_building(String(id)).get("unlock_unit_id",""))
\t\t\tif String(ContentService.get_unit(target).get("upgrade_from","")) == parts[2]: return TownEconomy.upgrade_cost(parts[2],target,count)
\treturn {}

func construction_goal() -> Dictionary:
\tvar town: Dictionary = TownRules.get_active_town(session)
\tvar choices := []
\tvar market: Dictionary = OverworldRules.town_market_state(town)
\t# Inspect future options without executing a second daily build.
\tfor id in OverworldRules.get_town_build_options(town):
\t\tvar cost: Dictionary = ContentService.get_building(String(id)).get("cost",{})
\t\tvar rare_missing := false
\t\tfor resource in cost:
\t\t\tif resource not in ["gold","wood","ore"] and int(session.overworld.resources.get(resource,0)) < int(cost[resource]) and resource not in market.get("import_resources",[]): rare_missing = true
\t\tif not rare_missing: choices.append({"id":"build:"+String(id),"cost":cost})
\tchoices.sort_custom(func(a,b):return String(a.id)<String(b.id) if build_priority(a)==build_priority(b) else build_priority(a)<build_priority(b))
\tif choices.is_empty(): return {}
\tvar goal: Dictionary = choices[0]
\tvar readiness := OverworldRules.town_cost_readiness(town,session.overworld.resources,goal.cost,session.day)
\tgoal.required_gold_total = int(readiness.get("required_gold_total",goal.cost.get("gold",0)))
\treturn goal

''' + source[end:]
        source = source.replace('"town":2,"encounter":1,"artifact":3,"resource":4', '"town":2,"encounter":4,"artifact":3,"resource":1')
        source = source.replace('if explored:\n', 'if explored and String(candidate.kind) == "resource":\n\t\t\treturn candidate\n\t\tif explored:\n')
    return source


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--faction', choices=['thornwake', 'brasshollow', 'veilmourn'], required=True)
    parser.add_argument('--label', required=True)
    parser.add_argument('--seed', default='10')
    parser.add_argument('--economy', action='store_true', help='Use legal market orders, paid town services and resource-first adventure')
    parser.add_argument('--core-town-actions', action='store_true', help='Call the same production town transactions directly, bypassing per-order scene rendering only')
    parser.add_argument('--resume', type=Path, help='Resume exact completed End Turn autosave and its recorded action history')
    parser.add_argument('--resume-checkpoint', choices=['autosave','mid_match'], default='autosave')
    parser.add_argument('--defend-until-day', type=int, default=0, help='Ordinary town defense and development before adventuring')
    parser.add_argument('--prioritize-home-tier6', action='store_true', help='Bank the first tier-six hometown recruit before developing captured rival towns')
    parser.add_argument('--size', default='homm3_small', choices=['homm3_small','homm3_medium'])
    parser.add_argument('--max-days', type=int, default=90)
    parser.add_argument('--timeout', type=int, default=3600)
    parser.add_argument('--godot', default=shutil.which('godot4') or shutil.which('godot') or 'D:/Games/godot/Godot_v4.6.2-stable_win64.exe')
    args = parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('label must be a new lowercase slug')
    out = OUTPUT / args.label
    out.mkdir(parents=True, exist_ok=False)
    cfg = dict(seed=args.seed, size=args.size, players=2,
               faction='faction_'+args.faction, hero='', max_days=args.max_days,
               template_selection_mode='native_catalog_auto', monster_strength='normal', defend_until_day=args.defend_until_day, core_town_actions=args.core_town_actions, prioritize_home_tier6=args.prioritize_home_tier6)
    source = script(args.economy)
    if args.economy:
        from town_overhaul_match_west import commerce_policy
        source = commerce_policy(source)
    if args.resume:
        save_name = 'autosave.json' if args.resume_checkpoint == 'autosave' else 'slot2.json'
        saves = list(args.resume.glob('profile/**/saves/'+save_name))
        if len(saves) != 1: raise ValueError('exactly one isolated autosave required')
        saved = saves[0].read_bytes()
        payload = json.loads(saved)
        digest = hashlib.sha256(saved).hexdigest()
        rows = [json.loads(line) for line in (args.resume/'actions.jsonl').read_text().splitlines()]
        setup = next(row['result'] for row in rows if row['kind'] == 'setup')
        if any(setup.get(key) != cfg[key] for key in ['seed','size','players','template_selection_mode','monster_strength']):
            raise ValueError('resume setup does not match selected match configuration')
        humans = [p for p in payload['overworld'].get('players',[]) if p.get('human')]
        if len(humans) != 1 or humans[0].get('faction_id') != cfg['faction']:
            raise ValueError('resume human faction does not match selected faction')
        matches = [i for i,r in enumerate(rows) if r['kind'] in ['end_turn','save_resume'] and r['result'].get('save_sha256')==digest]
        if not matches or payload['scenario_status'] != 'in_progress': raise ValueError('autosave lacks exact nonterminal action boundary')
        rows = rows[:matches[-1]+1]
        counts = {}
        for row in rows:
            counts[row['kind']] = counts.get(row['kind'],0)+1
            action_id = row.get('result',{}).get('id','')
            if row['kind'] == 'town_response' and row.get('result',{}).get('ok'):
                extra = 'artifact_purchase' if action_id.startswith('town_buy:') else ('artifact_sale' if action_id.startswith('town_sell:') else '')
                if extra: counts[extra] = counts.get(extra,0)+1
        metadata = dict(rows[-1]['driver_state'], counts=counts,
                        checkpoint_labels=[r['result']['label'] for r in rows if r['kind']=='save_resume'],
                        serial=rows[-1]['serial'], source=args.resume.name, save_sha256=digest)
        cfg['resume'] = metadata
        (out/'resume.json').write_bytes(saved)
        (out/'actions.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in rows))
    driver = out / 'driver.gd'
    driver.write_text(source, encoding='utf-8')
    scene = out / 'driver.tscn'
    scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="TownMatch" type="Node"]\nscript = ExtResource("1")\n' % driver.relative_to(ROOT).as_posix())
    env = dict(os.environ, APPDATA=str(out/'profile'), LOCALAPPDATA=str(out/'local'),
               XDG_DATA_HOME=str(out/'profile'), HEROES_FULL_MATCH_OUTPUT=out.as_posix(),
               HEROES_FULL_MATCH_CONFIG=json.dumps(cfg), HEROES_FULL_MATCH_RESOLUTION='1280x720',
               HEROES_PROFILE_LOG='0', HEROES_STRATEGIC_AI_PROFILE='0')
    provenance = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                  for pattern in ['scripts/**/*.gd', 'scenes/**/*.gd', 'content/*.json'] for p in ROOT.glob(pattern)}
    (out/'provenance.json').write_text(json.dumps(provenance, indent=2))
    started = time.monotonic()
    cmd = [args.godot, '--headless', '--path', str(ROOT), '--audio-driver', 'Dummy',
           '--accessibility', 'disabled', 'res://'+scene.relative_to(ROOT).as_posix()]
    print(json.dumps({'start':cfg,'output':str(out)}), flush=True)
    with (out/'runtime.log').open('w', encoding='utf-8') as log:
        process = subprocess.Popen(cmd, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        (out/'process.json').write_text(json.dumps({'pid':process.pid,'cmd':cmd}))
        try:
            rc = process.wait(timeout=args.timeout)
        except (subprocess.TimeoutExpired, KeyboardInterrupt):
            if os.name == 'nt':
                subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            else:
                process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            rc = 124
    lines = (out/'runtime.log').read_text(encoding='utf-8', errors='replace').splitlines()
    prefix = 'GENERATED_FULL_MATCH_REPORT '
    markers = [line[len(prefix):] for line in lines if line.startswith(prefix)]
    report = json.loads(markers[-1]) if markers else {'ok':False,'failures':['no terminal engine report']}
    report.update(returncode=rc, wall_s=round(time.monotonic()-started, 2),
                  runtime_errors=[line for line in lines if line.startswith(('ERROR:', 'SCRIPT ERROR:'))])
    report['ok'] = report.get('ok', False) and rc == 0 and not report['runtime_errors']
    (out/'report.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report), flush=True)
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
