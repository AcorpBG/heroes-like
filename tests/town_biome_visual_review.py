#!/usr/bin/env python3
"""Offline art-review sheets, not gameplay screenshots or procedural art.

Composite registered town pixels over the actual generated terrain materials.
Native/generated gameplay captures are produced separately by the Godot probe.
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT/'.artifacts/town-biome-fit-20260913/art-review')
    args = parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    art = json.loads((ROOT/'art/overworld/manifest.json').read_text())
    skins = json.loads((ROOT/'art/overworld/town_biome_sprites.json').read_text())
    terrains = ['grass','forest','mire','rough','sand','lava','snow','coast','underground']
    bases = list(skins['appearances'])
    backgrounds = {}
    for terrain in terrains:
        path = art['terrain_rendering']['raster_base_v2']['terrain_assets'][terrain]
        with Image.open(ROOT/path.removeprefix('res://')) as image:
            backgrounds[terrain] = image.convert('RGBA').resize((384,384),Image.Resampling.LANCZOS).crop((0,0,180,174))
    for start in range(0,len(bases),6):
        page = Image.new('RGBA',(1620,6*212+32),(25,27,28,255))
        draw = ImageDraw.Draw(page)
        draw.text((8,7),'TOWN / TERRAIN ART REVIEW - original raster composites, not a gameplay capture',fill='white')
        for row,base in enumerate(bases[start:start+6]):
            for col,terrain in enumerate(terrains):
                x,y=col*180,32+row*212
                page.alpha_composite(backgrounds[terrain],(x,y+32))
                selected = skins['appearances'][base]['biome_asset_ids'][skins['terrain_aliases'][terrain]]
                entry = art['object_assets'][selected]
                with Image.open(ROOT/entry['path'].removeprefix('res://')) as source:
                    sprite=source.convert('RGBA')
                    region=entry.get('atlas_region',entry.get('region'))
                    if region:
                        if isinstance(region,dict): rx,ry,rw,rh=[region[k] for k in ('x','y','width','height')]
                        else: rx,ry,rw,rh=region
                        sprite=sprite.crop((rx,ry,rx+rw,ry+rh))
                    box=sprite.getchannel('A').point(lambda v:255 if v>4 else 0).getbbox()
                    sprite=ImageOps.contain(sprite.crop(box),(140,158),Image.Resampling.LANCZOS)
                page.alpha_composite(sprite,(x+(180-sprite.width)//2,y+32+174-sprite.height-8))
                label=base.removeprefix('town_identity_').removeprefix('town_faction_')
                draw.text((x+3,y+1),label[:28],fill='white')
                draw.text((x+3,y+15),terrain+(' / variant' if selected!=base else ' / original'),fill='#a7b9cc')
        path=args.output/('town-biomes-%02d.png'%(start//6+1))
        page.convert('RGB').save(path)
        print(path)


if __name__=='__main__':main()
