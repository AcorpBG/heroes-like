#!/usr/bin/env python3
"""Same outline/input/build/save checks in isolated Linux/Windows packages."""
import town_building_outline_regression as outlines
import packaged_menu_and_turn_readability_regression as package
import sys
import json
import re
import hashlib
from pathlib import Path

# The six rendered faction hover captures can exercise native tooltip windows.
# Exercise the same six tooltip lifetimes without any game UI or art.
BASELINE = r'''extends Node
func _ready()->void: call_deferred("run")
func run()->void:
	var button:=Button.new()
	button.position=Vector2(100,100)
	button.size=Vector2(200,100)
	button.tooltip_text="Engine tooltip control"
	add_child(button)
	for i in range(6):
		var move:=InputEventMouseMotion.new()
		move.position=Vector2(150,150)
		Input.parse_input_event(move)
		await get_tree().create_timer(1.0).timeout
		move=InputEventMouseMotion.new()
		move.position=Vector2(2,2)
		Input.parse_input_event(move)
		await get_tree().create_timer(.1).timeout
	button.queue_free()
	await get_tree().process_frame
	print('BATTLE_READABILITY_REPORT {"checks":0,"failures":[],"ok":true}')
	get_tree().quit()
'''

if __name__ == '__main__':
    baseline = None
    if '--compare-engine-baseline' in sys.argv:
        position = sys.argv.index('--compare-engine-baseline')
        baseline = Path(sys.argv[position + 1])
        del sys.argv[position:position + 2]
    if '--baseline-popup' in sys.argv:
        sys.argv.remove('--baseline-popup')
        outlines.SCRIPT = BASELINE
    package.ui = outlines
    label = sys.argv[sys.argv.index('--label') + 1]
    process_codes = []
    original_run = package.packages.run
    def observed_run(*args, **kwargs):
        result = original_run(*args, **kwargs)
        process_codes.append(result)
        return result
    package.packages.run = observed_run
    code = package.main()
    if baseline is not None:
        output = outlines.OUTPUT / label
        current = json.loads((output / 'packaged-report.json').read_text())
        control = json.loads((baseline / 'packaged-report.json').read_text())
        def errors(path):
            return [re.sub(r'Window#\d+', 'Window#ID', line)
                    for line in (path / 'runtime.log').read_text().splitlines()
                    if 'ERROR:' in line]
        lines = (output / 'runtime.log').read_text().splitlines()
        functional = json.loads(next(line.split('BATTLE_READABILITY_REPORT ', 1)[1]
                                     for line in reversed(lines) if line.startswith('BATTLE_READABILITY_REPORT ')))
        expected = errors(baseline)
        comparison = {
            'functional_ok': functional['ok'] and functional['checks'] >= 5066,
            'process_exit_ok': bool(process_codes) and all(value == 0 for value in process_codes),
            'same_pack': current['pack_sha256'] == control['pack_sha256'],
            'bare_engine_control': control['packaged_probe_sha256'] == hashlib.sha256(BASELINE.encode()).hexdigest(),
            'export_unchanged': current['export_unchanged'] and control['export_unchanged'],
            'no_new_engine_errors': len(expected) == 12 and errors(output) == expected,
            'baseline': str(baseline), 'engine_clean': not errors(output),
        }
        comparison['ok'] = all(comparison[key] for key in (
            'functional_ok', 'process_exit_ok', 'same_pack', 'bare_engine_control',
            'export_unchanged', 'no_new_engine_errors'))
        (output / 'engine-baseline-comparison.json').write_text(json.dumps(comparison, indent=2) + '\n')
        print(json.dumps(comparison))
        code = 0 if comparison['ok'] else 1
    raise SystemExit(code)
