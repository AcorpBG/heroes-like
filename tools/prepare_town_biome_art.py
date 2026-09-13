#!/usr/bin/env python3
"""Owner-approved offline matte extraction for inspected generated town drafts.

Only background alpha and the production fit change; no synthetic town paint.
The source remains immutable. Explicit seeds identify enclosed background gaps,
never geometry invented in the runtime renderer.
"""
import argparse
from collections import deque
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


def extract(source, seeds=(), minimum=155, tolerance=35, speck_area=48, flat_white=False):
    image = source.convert('RGBA')
    data = np.array(image)
    rgb = data[:, :, :3].astype(np.int16)
    eligible = (rgb.min(axis=2) >= minimum) & (np.ptp(rgb, axis=2) <= tolerance)
    h, w = eligible.shape
    background = np.zeros((h, w), dtype=bool)
    queue = deque()
    starts = [(x, 0) for x in range(w)] + [(x, h-1) for x in range(w)]
    starts += [(0, y) for y in range(h)] + [(w-1, y) for y in range(h)] + list(seeds)
    if flat_white:
        # Approved flat-white generation recipe: include enclosed openings in
        # trusses/arches. These sources have dark outlined stone/timber; pure
        # neutral white is their inspected background, not a faction material.
        starts += [(int(x),int(y)) for y,x in zip(*np.where(rgb.min(axis=2) >= 250))]
    for x, y in starts:
        if not (0 <= x < w and 0 <= y < h): raise ValueError('Background seed outside canvas')
        if eligible[y, x] and not background[y, x]:
            queue.append((x, y)); background[y, x] = True
    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            if 0 <= nx < w and 0 <= ny < h and eligible[ny,nx] and not background[ny,nx]:
                background[ny,nx] = True; queue.append((nx,ny))
    data[background] = 0
    if background.mean() < .1: raise ValueError('Insufficient connected background; inspect matte recipe')
    # Remove the neutral matte fringe immediately outside the dark painted ink
    # edge. Restrict this to two source pixels and neutral bright colors; do not
    # erode colored flames, leaves, roof paint or the entire town silhouette.
    near_background = np.array(Image.fromarray((~background).astype(np.uint8)*255).filter(ImageFilter.MinFilter(5))) == 0
    fringe = near_background & ~background & (rgb.min(axis=2) >= 120) & (np.ptp(rgb,axis=2) <= tolerance)
    data[fringe] = 0
    background |= fringe
    # Tiny disconnected neutral islands are compression/paint residue in the
    # generated matte, not architecture. Do not discard larger detached details
    # or colored sparks/flags. This runs offline, never in the game renderer.
    visited = background.copy()
    removed_specks = 0
    for sy, sx in zip(*np.where(~visited)):
        if visited[sy, sx]: continue
        component = [(int(sx), int(sy))]
        queue = deque(component)
        visited[sy, sx] = True
        while queue:
            x, y = queue.popleft()
            for nx, ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if 0 <= nx < w and 0 <= ny < h and not visited[ny,nx]:
                    visited[ny,nx] = True
                    queue.append((nx,ny)); component.append((nx,ny))
        if len(component) <= speck_area:
            xx, yy = zip(*component)
            colors = rgb[yy, xx]
            if np.ptp(colors, axis=1).mean() <= tolerance:
                data[yy, xx] = 0
                removed_specks += len(component)
    return Image.fromarray(data), {'removed_pixels':int(background.sum()),'minimum':minimum,'tolerance':tolerance,'background_seeds':list(seeds),'neutral_speck_max_area':speck_area,'removed_speck_pixels':removed_specks,'flat_white':flat_white,'neutral_fringe_radius':2,'removed_fringe_pixels':int(fringe.sum())}


def fit(image, extent=480):
    box = image.getchannel('A').getbbox()
    if box is None: raise ValueError('Empty town cutout')
    cutout = image.crop(box)
    scale = extent/max(cutout.size)
    size = tuple(max(1,round(v*scale)) for v in cutout.size)
    result = Image.new('RGBA',(512,512))
    result.alpha_composite(cutout.resize(size,Image.Resampling.LANCZOS),((512-size[0])//2,(512-size[1])//2))
    return result, {'source_crop':list(box),'fit_size':list(size),'canvas':[512,512],'resampling':'LANCZOS'}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path)
    parser.add_argument('output',type=Path)
    parser.add_argument('--seed',action='append',default=[],help='Inspected enclosed background x,y')
    parser.add_argument('--flat-white',action='store_true')
    args=parser.parse_args()
    seeds=[tuple(map(int,v.split(','))) for v in args.seed]
    with Image.open(args.source) as source:
        cutout,matte=extract(source,seeds,minimum=230 if args.flat_white else 155,tolerance=20 if args.flat_white else 35,flat_white=args.flat_white)
        runtime,transform=fit(cutout)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    runtime.save(args.output)
    print(json.dumps({'source':str(args.source),'source_sha256':hashlib.sha256(args.source.read_bytes()).hexdigest(),'output':str(args.output),'runtime_sha256':hashlib.sha256(args.output.read_bytes()).hexdigest(),'matte':matte,'transform':transform}))


if __name__=='__main__':main()
