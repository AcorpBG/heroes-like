#!/usr/bin/env python3
"""Exercise deferred menu accessibility before entry and after scene removal."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile

from generated_town_order_profile import ROOT, OUTPUT, run_probe

SCRIPT = r'''
extends Node
var failures := []
func _ready() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
func run() -> void:
	get_tree().current_scene = null
	var menu = load("res://scenes/menus/MainMenu.tscn").instantiate()
	# No onready controls yet: a detached callback must not ask for its tree.
	menu.call("_refresh_stage_accessibility")
	add_child(menu)
	for frame in range(6):
		await get_tree().process_frame
	menu.validation_open_settings_stage()
	for frame in range(6):
		await get_tree().process_frame
	check(menu._stage_dock_is_open(),"live settings stage did not open")
	check(menu.get_viewport().gui_get_focus_owner() != null,"live settings navigation lost focus")
	# One callback awaits its next frame; another has not started yet.
	menu.call("_refresh_stage_accessibility")
	menu.call_deferred("_refresh_stage_accessibility")
	remove_child(menu)
	for frame in range(3):
		await get_tree().process_frame
	check(not menu.is_inside_tree(),"removed menu unexpectedly reentered tree")
	menu.free()
	print("MENU_STAGE_ACCESSIBILITY_LIFECYCLE_REGRESSION "+JSON.stringify({"ok":failures.is_empty(),"failures":failures,"cases":["before_tree","live_settings_focus","removed_during_frame_wait","deferred_after_removal"]}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    args = parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('label must be a fresh lowercase slug')
    out = OUTPUT/args.label
    out.mkdir(parents=True, exist_ok=False)
    digest = hashlib.sha256((ROOT/'scenes/menus/MainMenu.gd').read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix='menu-lifecycle-', dir=OUTPUT) as temp:
        work = Path(temp)
        (work/'probe.gd').write_text(SCRIPT)
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Lifecycle" type="Node"]\nscript = ExtResource("1")\n' % (work/'probe.gd').relative_to(ROOT))
        env = dict(os.environ, XDG_DATA_HOME=str(out/'data'))
        with (out/'runtime.log').open('w') as log:
            code = run_probe(['dbus-run-session','--','xvfb-run','-a','-s','-screen 0 2000x1200x24','godot4','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','res://'+str(scene.relative_to(ROOT))],env,log)
    lines = (out/'runtime.log').read_text().splitlines()
    marker = 'MENU_STAGE_ACCESSIBILITY_LIFECYCLE_REGRESSION '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok':False,'failures':['missing report']}
    report.update(returncode=code,source_sha256=digest,runtime_errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line])
    report['ok'] = bool(report['ok']) and code==0 and not report['runtime_errors']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
