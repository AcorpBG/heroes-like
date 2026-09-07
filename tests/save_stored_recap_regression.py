#!/usr/bin/env python3
"""Compare stored recaps to the complete pre-change SaveService and count work."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

from generated_town_order_profile import ROOT, OUTPUT, run_probe

REFERENCE = 'cdda0ba6c6dd60c84911daa2df3f3d8cd16ad5a0'
OWNER = 'scripts/autoload/SaveService.gd'
MARKER = 'SAVE_STORED_RECAP_REGRESSION '


def instrument(source):
    source = re.sub(r'^class_name [^\n]+\n', '', source, count=1)
    anchor = '\nfunc _session_save_recap_context(\n'
    if source.count(anchor) != 1:
        raise ValueError('review recap owner signature')
    source = source.replace(anchor, '\nfunc counted_original_recap_context(\n')
    return source + '''
var recap_build_count := 0
func _session_save_recap_context(session: SessionStateStoreScript.SessionData, summary: Dictionary, preloaded_progress_recap: String = "", include_play_check_state: bool = false, refresh_watch_context: Dictionary = {}) -> Dictionary:
\trecap_build_count += 1
\treturn counted_original_recap_context(session, summary, preloaded_progress_recap, include_play_check_state, refresh_watch_context)
'''


SCRIPT = r'''
extends Node
var original
var current
var errors := []
var rows := []
var checks := 0
var require_reuse := false
func _ready() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		errors.append(label)
func compare(summary: Dictionary, label: String, expect_reuse := false, expect_build := true) -> String:
	var before := summary.duplicate(true)
	var live = SessionState.active_session
	var state: Dictionary = live.to_dict() if live != null else {}
	original.recap_build_count = 0
	current.recap_build_count = 0
	var start := Time.get_ticks_usec()
	var old: String = original.describe_summary_resume_recap(summary)
	var old_us := Time.get_ticks_usec()-start
	start = Time.get_ticks_usec()
	var now: String = current.describe_summary_resume_recap(summary)
	var current_us := Time.get_ticks_usec()-start
	check(old == now,label+": complete recap text")
	check(before == summary,label+": caller summary unchanged")
	check(live == null or state == live.to_dict(),label+": live state unchanged")
	if expect_build:
		check(original.recap_build_count == 1,label+": original materializes stored context")
		if not expect_reuse or require_reuse:
			check(current.recap_build_count == (0 if expect_reuse else 1),label+": exact current materialization count")
	else:
		check(original.recap_build_count == 0 and current.recap_build_count == 0,label+": original early return preserved")
	rows.append({"label":label,"original_usec":old_us,"current_usec":current_us,"original_builds":original.recap_build_count,"current_builds":current.recap_build_count})
	return now
func inspect() -> Dictionary:
	var old: Dictionary = original.inspect_manual_slot(1)
	var now: Dictionary = current.inspect_manual_slot(1)
	check(old == now,"complete public inspected summary equality")
	return now
func saved_fixture(session, label: String) -> Dictionary:
	original.validation_clear_summary_cache()
	current.validation_clear_summary_cache()
	var result: Dictionary = original.save_runtime_manual_session(session,1)
	check(bool(result.get("ok",false)),label+": actual transactional save")
	# Both owners inspect the same disk bytes through the same cold entry path.
	# Runtime-created summaries and disk-created summaries already differ on
	# the unchanged control; mixing their caches is not an equality oracle.
	original.validation_clear_summary_cache()
	var summary := inspect()
	check(not summary.get("payload",{}).is_empty(),label+": inline saved world")
	compare(summary,label+" cold")
	compare(summary,label+" warm",true)
	compare(summary.duplicate(true),label+" detached equal copy",true)
	return summary
func run() -> void:
	original = load(OS.get_environment("RECAP_ORIGINAL")).new()
	current = load(OS.get_environment("RECAP_CURRENT")).new()
	require_reuse = OS.get_environment("RECAP_REQUIRE_REUSE") == "1"
	for id in ["three-hearth-auxiliary-charter","bogbound-oath","three-banner-field-commission","rootway-graftmarch","ashen-clausemarch","false-channel-pursuit"]:
		var session = ScenarioFactory.create_session(id,"normal",SessionState.LAUNCH_MODE_SKIRMISH)
		OverworldRules.normalize_overworld_state_for_runtime(session)
		SessionState.set_active_session(session)
		var summary := saved_fixture(session,id)
		for mode in ["town","battle","outcome"]:
			# Detached display-state controls, not claimed as played battles/outcomes.
			var changed := summary.duplicate(true)
			changed.resume_target = mode
			changed.game_state = mode
			changed.payload.game_state = mode
			compare(changed,id+" changed "+mode)
		compare(summary,id+" original after detached changes",true)
		var changed := summary.duplicate(true)
		changed.payload.overworld.resources.gold += 1
		changed.payload.scenario_summary = "Different stored result"
		compare(changed,id+" changed payload")
		compare(summary,id+" original after payload change",true)
		current.validation_clear_summary_cache()
		compare(summary,id+" cleared cache")
		current._store_slot_summary_cache(summary)
		compare(summary,id+" replaced entry")
		compare(summary,id+" replaced entry warm",true)
		var state := session.to_dict()
		check(original.build_in_session_save_surface(session,1) == current.build_in_session_save_surface(session,1),id+": complete live save surface")
		check(state == session.to_dict(),id+": complete save surface is read-only")
	var session = ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state_for_runtime(session)
	SessionState.set_active_session(session)
	var summary := saved_fixture(session,"freshness")
	ContentService.clear_cache()
	compare(summary,"authored content reset")
	compare(summary,"authored content reset warm",true)
	var content_before: String = current.describe_summary_resume_recap(summary)
	var catalog: Dictionary = ContentService.load_json(ContentService.SCENARIOS_PATH).duplicate(true)
	for scenario in catalog.items:
		if String(scenario.get("id","")) == "river-pass":
			scenario.objectives.victory[0].label = "Changed objective from reloaded content"
	# Use the documented reset/replacement boundary, not mutation of borrowed rows.
	ContentService.clear_cache()
	ContentService._cache[ContentService.SCENARIOS_PATH] = catalog
	var content_after := compare(summary,"changed authored objective content")
	check(content_before != content_after and content_after.contains("Changed objective from reloaded content"),"reloaded content changes the actual visible next decision")
	compare(summary,"changed authored objective warm",true)
	ContentService.clear_cache()
	check(compare(summary,"restore authored content") == content_before,"original content restored exactly")
	compare(summary,"restored authored content warm",true)
	var draft := {"id":"recap_cache_draft_fixture","generated":true,"selection":{"availability":{"campaign":false,"skirmish":false}}}
	check(bool(ContentService.register_generated_scenario_draft(draft,{}).get("ok",false)),"register detached draft fixture")
	compare(summary,"draft registration")
	compare(summary,"draft registration warm",true)
	ContentService.unregister_generated_scenario_draft(String(draft.id))
	compare(summary,"draft unregistration")
	compare(summary,"draft unregistration warm",true)
	ContentService.clear_generated_scenario_drafts()
	compare(summary,"draft registry reset")
	compare(summary,"draft registry reset warm",true)
	var path: String = summary.path
	var bytes := FileAccess.get_file_as_string(path)
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(bytes+"\n ")
	file.close()
	compare(summary,"external size change rejects reuse")
	summary = inspect()
	compare(summary,"fresh external inspection")
	compare(summary,"fresh external inspection warm",true)
	# The existing named-save signature hashes actual bytes, even same-size edits.
	var named := "user://saves/recap-cache.save.json"
	file = FileAccess.open(named,FileAccess.WRITE)
	file.store_string(bytes)
	file.close()
	var named_summary: Dictionary = original._inspect_slot("file","recap-cache",named)
	check(named_summary == current._inspect_slot("file","recap-cache",named),"named public summary equality")
	compare(named_summary,"named deferred summary",false,false)
	file = FileAccess.open(named,FileAccess.WRITE)
	file.store_string(bytes.replace('"day":1,','"day":2,'))
	file.close()
	check(FileAccess.get_size(named) == bytes.to_utf8_buffer().size(),"same-size named edit")
	check(original._inspect_slot("file","recap-cache",named) == current._inspect_slot("file","recap-cache",named),"same-size named freshness equality")
	check(int(current._inspect_slot("file","recap-cache",named).day) == 2,"same-size named freshness reads edited day")
	# Recovery stays in the ordinary inspection owner; recaps cannot suppress it.
	var candidate: String = current.validation_transaction_artifact_paths(path).candidate
	file = FileAccess.open(candidate,FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	summary = inspect()
	check(not FileAccess.file_exists(candidate),"ordinary inspection recovers transaction artifact")
	check(FileAccess.get_file_as_string(path) == bytes+"\n ","discarded candidate preserves exact live bytes")
	compare(summary,"after unchanged-live transaction recovery",true)
	compare(summary,"after transaction recovery warm",true)
	var deleted: Dictionary = current.delete_session_from_summary(summary)
	check(bool(deleted.get("ok",false)),"ordinary delete succeeds")
	compare(summary,"deleted file rejects cached recap")
	compare(inspect(),"deleted empty slot",false,false)
	compare({},"empty summary",false,false)
	var invalid := summary.duplicate(true)
	invalid.valid = false
	invalid.status_text = "This save is unavailable."
	compare(invalid,"blocked summary",false,false)
	invalid = summary.duplicate(true)
	invalid.payload = {}
	invalid.payload_deferred = true
	compare(invalid,"deferred summary",false,false)
	var saved_path := OS.get_environment("RECAP_SAVE")
	if saved_path != "":
		var generated = SessionState.restore_session(JSON.parse_string(FileAccess.get_file_as_string(saved_path)))
		var state := generated.to_dict()
		var result: Dictionary = original.save_runtime_manual_session(generated,1)
		check(bool(result.get("ok",false)),"actual generated save")
		original.validation_clear_summary_cache()
		current.validation_clear_summary_cache()
		var generated_summary := inspect()
		var inline_world: bool = not generated_summary.get("payload",{}).is_empty()
		compare(generated_summary,"actual generated cold",false,inline_world)
		compare(generated_summary,"actual generated warm",inline_world,inline_world)
		check(state == generated.to_dict(),"actual generated save and recap leave full gameplay unchanged")
	original.free()
	current.free()
	print("SAVE_STORED_RECAP_REGRESSION "+JSON.stringify({"ok":errors.is_empty(),"checks":checks,"errors":errors,"rows":rows}))
	get_tree().quit(0 if errors.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', type=Path)
    parser.add_argument('--require-reuse', action='store_true')
    args = parser.parse_args()
    if not re.fullmatch('[a-z0-9_-]+', args.label):
        parser.error('label must be a fresh lowercase slug')
    out = OUTPUT / args.label
    out.mkdir(parents=True, exist_ok=False)
    original = subprocess.check_output(['git', 'show', f'{REFERENCE}:{OWNER}'], cwd=ROOT).decode()
    current = (ROOT / OWNER).read_text()
    saved = args.save.read_bytes() if args.save else None
    with tempfile.TemporaryDirectory(prefix='stored-recap-', dir=OUTPUT) as temporary:
        work = Path(temporary)
        for name, source in [('original', original), ('current', current)]:
            (work / (name+'.gd')).write_text(instrument(source))
        (work / 'probe.gd').write_text(SCRIPT)
        scene = work / 'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Recaps" type="Node"]\nscript = ExtResource("1")\n' % (work/'probe.gd').relative_to(ROOT))
        if saved:
            (work / 'input_save.json').write_bytes(saved)
        env = dict(os.environ, XDG_DATA_HOME=str(out/'data'), RECAP_ORIGINAL='res://'+str((work/'original.gd').relative_to(ROOT)), RECAP_CURRENT='res://'+str((work/'current.gd').relative_to(ROOT)), RECAP_REQUIRE_REUSE='1' if args.require_reuse else '0', RECAP_SAVE=str(work/'input_save.json') if saved else '')
        with (out/'runtime.log').open('w') as log:
            code = run_probe(['godot4', '--headless', '--path', str(ROOT), '--audio-driver', 'Dummy', '--accessibility', 'disabled', 'res://'+str(scene.relative_to(ROOT))], env, log)
    lines = (out/'runtime.log').read_text().splitlines()
    reports = [json.loads(line[len(MARKER):]) for line in lines if line.startswith(MARKER)]
    report = reports[-1] if reports else {'ok':False, 'errors':['missing report']}
    report.update(returncode=code, reference_revision=REFERENCE, reference_sha256=hashlib.sha256(original.encode()).hexdigest(), current_sha256=hashlib.sha256(current.encode()).hexdigest(), content_sha256=hashlib.sha256((ROOT/'scripts/autoload/ContentService.gd').read_bytes()).hexdigest(), save_sha256=hashlib.sha256(saved).hexdigest() if saved else None, runtime_errors=[line for line in lines if line.startswith(('ERROR:', 'SCRIPT ERROR:')) or 'leaked' in line])
    report['ok'] = bool(report['ok']) and code == 0 and not report['runtime_errors']
    (out/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k != 'rows'}))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
