#!/usr/bin/env python3
"""Rebuild the explicitly approved town cutouts and their provenance.

Only recipe-owned paths and object_assets entries are written. Historical art,
identity tables, and terrain selection policy are deliberately not modified.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image
from prepare_town_biome_art import extract, fit

ROOT = Path(__file__).resolve().parents[1]
DIRECTORY = ROOT/'art/overworld/source/generated/towns/biome_fit'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def resource(path):
    return 'res://'+path.relative_to(ROOT).as_posix()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--only', help='Rebuild one recipe job; default rebuilds all jobs')
    args = parser.parse_args()
    recipe = json.loads((DIRECTORY/'offline_recipe.json').read_text())
    if args.only and args.only not in recipe['jobs']: parser.error('Unknown recipe job')
    packet_path = DIRECTORY/'manifest.json'
    packet = json.loads(packet_path.read_text())
    art_path = ROOT/'art/overworld/manifest.json'
    art = json.loads(art_path.read_text())
    for name, job in recipe['jobs'].items():
        if args.only and args.only != name: continue
        paths = {field: ROOT/value.removeprefix('res://') for field,value in job.items() if field in ('input','draft')}
        if digest(paths['draft']) != job['draft_sha256']:
            raise ValueError(name+': unreviewed draft bytes')
        paths['source'] = DIRECTORY/(name+'_cutout.png')
        paths['trimmed'] = ROOT/('art/overworld/source/trimmed/towns/biome_fit/'+name+'.png')
        paths['runtime'] = ROOT/('art/overworld/runtime/objects/towns/biome_fit/'+name+'.png')
        white = job.get('flat_white',False)
        with Image.open(paths['draft']) as source:
            cutout,matte = extract(source,job.get('seeds',()),minimum=230 if white else 155,tolerance=20 if white else 35,flat_white=white)
            runtime,transform = fit(cutout)
        for path in paths.values():
            path.parent.mkdir(parents=True,exist_ok=True)
        cutout.save(paths['source'])
        runtime.save(paths['trimmed'])
        runtime.save(paths['runtime'])
        # Godot will assign a UID/import digest on first import. Never copy
        # another resource's UID. Both platform importers consume these params.
        imp = paths['runtime'].with_suffix('.png.import')
        if not imp.exists():
            imp.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[deps]\nsource_file="'+resource(paths['runtime'])+'"\n\n[params]\ncompress/mode=0\nmipmaps/generate=true\nprocess/fix_alpha_border=true\nprocess/size_limit=512\n')
        asset_id = 'town_biome_'+name
        row = {'base_asset_id':job['base_asset_id'], **{k:resource(v) for k,v in paths.items()},
               'canvas':[512,512], 'import_size_limit':512,
               'prompt':job.get('prompt') or (DIRECTORY/'land_prompt.txt').read_text().strip(),
               'processing':'Owner-approved offline background alpha extraction and aspect-preserving 512px packaging; source architecture is not repainted.',
               'offline_recipe':resource(DIRECTORY/'offline_recipe.json'),
               'recipe_job':name,'matte':matte,'transform':transform,
               'sha256':{k:digest(v) for k,v in paths.items()}}
        packet['assets'][asset_id] = row
        base = art['object_assets'][job['base_asset_id']]
        art['object_assets'][asset_id] = {
            'path':row['runtime'],'source_trimmed':row['trimmed'],'source_generated':row['source'],
            'source_processing_manifest':resource(packet_path),
            'source_model':'built_in_image_gen_original_biome_town_variant',
            'runtime_sha256':row['sha256']['runtime'],'base_asset_id':job['base_asset_id'],
            'accessible_description':job['description']}
        if 'assigned_town_id' in base:
            art['object_assets'][asset_id]['assigned_town_id'] = base['assigned_town_id']
        print(asset_id, row['sha256']['runtime'], flush=True)
    packet['status'] = 'variants_packaged_pending_full_visual_acceptance'
    for path,data in ((packet_path,packet),(art_path,art)):
        path.write_text(json.dumps(data,indent=2)+'\n')


if __name__=='__main__': main()
