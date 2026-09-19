#!/usr/bin/env python3
"""Remove inspected near-transparent alpha noise from generated idle sheets.

This is edge preparation only: no recoloring, pose synthesis or registration.
Originals and all paint with alpha above the recipe cutoff remain untouched.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


def prepare(recipe_path):
    recipe = json.loads(recipe_path.read_text())
    cutoff = recipe['alpha_noise_cutoff']
    if type(cutoff) is not int or not 0 <= cutoff <= 8:
        raise ValueError('Only inspected alpha noise at 0..8 may be removed')
    source = recipe_path.parent / recipe['source']
    if hashlib.sha256(source.read_bytes()).hexdigest() != recipe['source_sha256']:
        raise ValueError('Original changed; inspect before preparing')
    image = Image.open(source)
    if image.mode != 'RGBA':
        raise ValueError('Use the original generated alpha, never key its RGB')
    image.putalpha(image.getchannel('A').point(lambda value: 0 if value <= cutoff else value))
    output = recipe_path.parent / recipe['output']
    image.save(output, optimize=True)
    return output


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('recipe', type=Path)
    print(prepare(parser.parse_args().recipe))
