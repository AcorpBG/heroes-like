#!/usr/bin/env python3
"""Focused original blocker art and live generated-body adoption check.

Uses the existing Medium rendering probe. Owns its temporary driver, output,
timeout and child process on Windows/Linux; does not launch a manual match.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '.artifacts/rmg-blocker-variety-20260913'
MARKER = 'OVERWORLD_RASTER_TERRAIN_BLOCKER_MASS_REPORT '

ADOPTION = r'''
func _check_variety(view, summary: Dictionary) -> void:
	var manifest: Dictionary = ContentService.load_json("res://art/overworld/decorative_object_sprites.json")
	var additions: Dictionary = manifest.generated_body_appearances
	var counts := {}
	for entry in summary.get("body_entries", []):
		var id := String(entry.get("asset_id", ""))
		if additions.has(id): counts[id] = int(counts.get(id, 0)) + 1
	if counts.is_empty(): _failures.append("real generated map selected none of the new blockers")
	# Isolated terrain fixture exercises all nine palettes through the actual
	# selector, without mutating the generated session or its map.
	var isolated = load("res://scenes/overworld/OverworldMapView.gd").new()
	isolated._load_overworld_art_manifest()
	isolated._map_size = Vector2i(72,72)
	var selected := {}
	for terrain in ["grass","forest","mire","coast","rough","badlands","snow","lava","cavern"]:
		isolated._map_data = []
		for y in range(72):
			var row := []
			row.resize(72)
			row.fill(terrain)
			isolated._map_data.append(row)
		for y in range(72):
			for x in range(72):
				var tile := Vector2i(x,y)
				var id: String = isolated._generated_decorative_body_asset_id({},tile)
				if id != isolated._generated_decorative_body_asset_id({},tile): _failures.append("unstable selection")
				if additions.has(id): selected[id] = true
	for id in additions:
		if not selected.has(id): _failures.append("new blocker never selected: " + id)
		var texture = isolated._object_texture_for_asset(id)
		if texture == null or texture.get_width() != 256: _failures.append("new texture missing or import unbounded: " + id)
	isolated.free()
	print("RMG_BLOCKER_VARIETY_ADOPTION " + JSON.stringify({"generated_map_counts":counts,"all_biome_selector_ids":selected.keys()}))
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=shutil.which('godot4') or shutil.which('godot'))
    args = parser.parse_args()
    if not args.godot:
        parser.error('--godot is required')
    OUT.mkdir(parents=True, exist_ok=True)
    art = json.loads((ROOT/'art/overworld/manifest.json').read_text())['object_assets']
    palette = json.loads((ROOT/'art/overworld/decorative_object_sprites.json').read_text())
    additions = palette['generated_body_appearances']
    failures = []
    for aid, row in additions.items():
        path = ROOT/art[aid]['path'].removeprefix('res://')
        with Image.open(path) as image:
            alpha = image.getchannel('A')
            if alpha.histogram()[0] < image.width*image.height*.1:
                failures.append(aid + ': background is not transparent')
            if any(alpha.getpixel(p)>32 for p in [(0,0),(image.width-1,0),(0,image.height-1),(image.width-1,image.height-1)]):
                failures.append(aid + ': opaque corner')
        for biome in row['biome_ids']:
            if aid not in palette['generated_body_palette'][biome]:
                failures.append(aid + ': missing biome wiring')
    if failures:
        print(json.dumps({'ok':False,'failures':failures})); return 1
    source = (ROOT/'tests/overworld_raster_terrain_blocker_mass_report.gd').read_text()
    source = source.replace('res://.artifacts/overworld_cohesive_biome_blocker_mass_10232', 'res://.artifacts/rmg-blocker-variety-20260913')
    source = source.replace('\t_validate_body_summary(first_summary)', '\t_validate_body_summary(first_summary)\n\t_check_variety(map_view, first_summary)') + ADOPTION
    # The ordinary probe quits after its captures. Temporary scripts do not
    # remain in the game or exports, and the owner profile stays untouched.
    with tempfile.TemporaryDirectory(prefix='blocker-driver-',dir=OUT) as temporary:
        work=Path(temporary)
        (work/'probe.gd').write_text(source,encoding='utf-8')
        res='res://'+(work/'probe.gd').relative_to(ROOT).as_posix()
        scene=work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="'+res+'" id="1"]\n[node name="BlockerVariety" type="Node"]\nscript=ExtResource("1")\n')
        command=[args.godot,'--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','--rendering-method','gl_compatibility','--resolution','1920x1080','--position','-10000,-10000','res://'+scene.relative_to(ROOT).as_posix()]
        env=dict(os.environ,APPDATA=str(work/'profile'),XDG_DATA_HOME=str(work/'profile'))
        options={}
        if os.name=='nt':
            startup=subprocess.STARTUPINFO(); startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW; startup.wShowWindow=subprocess.SW_HIDE
            options['startupinfo']=startup
        else:
            command=['xvfb-run','-a','-s','-screen 0 1920x1080x24']+command
        with (OUT/'runtime.log').open('w',encoding='utf-8') as log:
            process=subprocess.Popen(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,**options)
            try: code=process.wait(timeout=360)
            finally:
                if process.poll() is None: process.kill(); process.wait(timeout=10)
    lines=(OUT/'runtime.log').read_text(encoding='utf-8').splitlines()
    reports=[json.loads(line[len(MARKER):]) for line in lines if line.startswith(MARKER)]
    adoption=[json.loads(line.split(' ',1)[1]) for line in lines if line.startswith('RMG_BLOCKER_VARIETY_ADOPTION ')]
    report=reports[-1] if reports else {'ok':False,'failures':['missing live report']}
    report['adoption']=adoption[-1] if adoption else {}
    report['returncode']=code
    report['runtime_errors']=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:'))]
    report['ok']=bool(report['ok']) and code==0 and bool(adoption) and not report['runtime_errors']
    (OUT/'variety-report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k in ['ok','failures','returncode','runtime_errors','adoption','expected_body_tile_count','visual_anchor_count','session_authority_exact','collision_authority_exact']}))
    return 0 if report['ok'] else 1


if __name__=='__main__':raise SystemExit(main())
