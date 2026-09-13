#!/usr/bin/env python3
"""Verify final release packs contain the current town policy/art on both OSes."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from compact_export_pck import read_directory


def inspect(path):
    data=path.read_bytes()
    _,entries=read_directory(data)
    hashes={row.path:hashlib.sha256(data[row.offset:row.offset+row.size]).hexdigest() for row in entries}
    wanted={'art/overworld/manifest.json','art/overworld/town_biome_sprites.json'}
    payload={row.path:data[row.offset:row.offset+row.size] for row in entries if row.path in wanted or row.path.startswith('art/overworld/runtime/objects/towns/biome_fit/')}
    failures=[]
    for name in wanted:
        if name not in payload or json.loads(payload[name])!=json.loads((ROOT/name).read_text()):
            failures.append('pack lacks current exact manifest: '+name)
    proof=json.loads((ROOT/'art/overworld/source/generated/towns/biome_fit/manifest.json').read_text())
    for asset,row in proof['assets'].items():
        importer=row['runtime'].removeprefix('res://')+'.import'
        descriptor=payload.get(importer,b'').decode()
        match=re.search(r'^path="res://([^"]+)"',descriptor,re.M)
        if not match or match.group(1) not in hashes:
            failures.append('missing packed town texture: '+asset)
    for owner in ('scenes/overworld/OverworldMapView.gdc','scripts/core/TownBiomeArtRules.gdc'):
        if owner not in hashes: failures.append('missing compiled render owner: '+owner)
    forbidden=[name for name in hashes if '/towns/biome_fit/' in name and ('/source/' in name or '/trimmed/' in name)]
    if forbidden: failures.append('source art leaked into package')
    return {'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'members':len(entries),'town_variants':len(proof['assets']),'failures':failures},hashes


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('linux',type=Path)
    parser.add_argument('windows',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    linux,first=inspect(args.linux)
    windows,second=inspect(args.windows)
    missing=sorted(set(first)^set(second))
    changed=sorted(name for name in set(first)&set(second) if first[name]!=second[name])
    # Godot may encode platform feature flags in project.binary. Art, content,
    # scripts and imports must otherwise be exactly equal, not just same count.
    unexpected=[name for name in changed if name!='project.binary']
    report={'ok':not (linux['failures'] or windows['failures'] or missing or unexpected),'linux':linux,'windows':windows,'inventory_difference':missing,'different_members':changed,'unexpected_payload_difference':unexpected}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))
    return int(not report['ok'])


if __name__=='__main__':raise SystemExit(main())
