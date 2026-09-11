#!/usr/bin/env python3
"""Same real resource-strip probe through the isolated export bootstrap."""
import overworld_resource_strip_regression as strip
import packaged_menu_and_turn_readability_regression as package
import sys
import json
import hashlib
import re
from pathlib import Path

# Optional engine-only control: no game script, icon strip or scene is involved.
# Keep the normal runner strict: known upstream errors still make it return 1.
BASELINE = r'''extends Node
func _ready()->void: call_deferred("run")
func run()->void:
	var menu:=MenuButton.new()
	menu.text="Engine popup control"
	add_child(menu)
	menu.get_popup().add_item("Control")
	for i in range(3): await get_tree().process_frame
	for i in range(2):
		menu.show_popup()
		for j in range(3): await get_tree().process_frame
		menu.get_popup().hide()
		for j in range(3): await get_tree().process_frame
	menu.queue_free()
	for i in range(3): await get_tree().process_frame
	print('BATTLE_READABILITY_REPORT {"checks":0,"failures":[],"ok":true}')
	get_tree().quit()
'''

if __name__=='__main__':
    baseline=None
    if '--compare-engine-baseline' in sys.argv:
        position=sys.argv.index('--compare-engine-baseline')
        baseline=Path(sys.argv[position+1])
        del sys.argv[position:position+2]
    if '--baseline-popup' in sys.argv:
        sys.argv.remove('--baseline-popup')
        strip.SCRIPT=BASELINE
    package.ui=strip
    label=sys.argv[sys.argv.index('--label')+1]
    process_codes=[]
    original_run=package.packages.run
    def observed_run(*args,**kwargs):
        result=original_run(*args,**kwargs)
        process_codes.append(result)
        return result
    package.packages.run=observed_run
    code=package.main()
    if baseline is not None:
        # Retain the strict failing reports/logs. Separately prove that the
        # functional regression passes and adds no errors to a bare engine menu.
        output=strip.OUTPUT/label
        current=json.loads((output/'packaged-report.json').read_text())
        control=json.loads((baseline/'packaged-report.json').read_text())
        def errors(path):
            return [re.sub(r'Window#\d+', 'Window#ID', line)
                    for line in (path/'runtime.log').read_text().splitlines()
                    if 'ERROR:' in line]
        lines=(output/'runtime.log').read_text().splitlines()
        functional=json.loads(next(line.split('BATTLE_READABILITY_REPORT ',1)[1]
                                   for line in reversed(lines) if line.startswith('BATTLE_READABILITY_REPORT ')))
        expected=errors(baseline)
        comparison={
            'functional_ok':functional['ok'] and functional['checks']>=209,
            'process_exit_ok':bool(process_codes) and all(value==0 for value in process_codes),
            'same_pack':current['pack_sha256']==control['pack_sha256'],
            'bare_engine_control':control['packaged_probe_sha256']==hashlib.sha256(BASELINE.encode()).hexdigest(),
            'export_unchanged':current['export_unchanged'] and control['export_unchanged'],
            'no_new_engine_errors':len(expected)==6 and errors(output)==expected,
            'baseline':str(baseline), 'engine_clean':not errors(output),
            'upstream':'https://github.com/godotengine/godot/issues/89657',
        }
        comparison['ok']=all(comparison[key] for key in ('functional_ok','process_exit_ok','same_pack','bare_engine_control','export_unchanged','no_new_engine_errors'))
        (output/'engine-baseline-comparison.json').write_text(json.dumps(comparison,indent=2)+'\n')
        print(json.dumps(comparison))
        code=0 if comparison['ok'] else 1
    raise SystemExit(code)
