"""Current density/profile contracts; disposable screenshots are not prerequisites."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def validate(config=None):
    errors = []
    config = config if config is not None else json.loads((ROOT / 'art/overworld/object_raster_density.json').read_text())
    proof = json.loads((ROOT / 'art/overworld/source/generated/object_density_20260917/manifest.json').read_text())
    recipe_path = ROOT / 'art/overworld/source/generated/object_density_20260917/recipe.json'
    recipe = json.loads(recipe_path.read_text())
    art = json.loads((ROOT / 'art/overworld/manifest.json').read_text())['object_assets']

    def require(condition, message):
        if not condition:
            errors.append('Object raster density: ' + message)

    def sha(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()

    require(config.get('schema_id') == 'overworld_object_raster_density_v1', 'invalid schema')
    expected = {key for key, row in art.items() if row.get('atlas_region', [0, 0, 1000])[2] <= 64}
    require(set(config.get('assets', {})) == expected == set(recipe['assets']) == set(proof['assets']), 'missing or unknown low-density identity')
    require(proof['recipe_sha256'] == sha(recipe_path), 'recipe hash changed')
    require(proof['tool_sha256'] == sha(ROOT / 'tools/prepare_overworld_object_density.py'), 'packer hash changed')
    for key, row in config.get('assets', {}).items():
        original = art.get(key, {})
        require(row.get('original_path') == original.get('path') and row.get('original_region') == original.get('atlas_region'), 'original identity mismatch: ' + key)
        region = row.get('atlas_region', [])
        require(len(region) == 4 and region[2:] == [192, 192], 'insufficient raster density: ' + key)
        require(key in recipe['assets'] and recipe['assets'][key]['original_entry'] == original, 'original state metadata changed: ' + key)
        path = ROOT / row.get('path', '').removeprefix('res://')
        require(row.get('path') in proof['runtime'] and path.is_file(), 'unproven or missing runtime: ' + key)
        if path.is_file() and len(region) == 4:
            with Image.open(path) as raster:
                require(list(raster.size) == row.get('atlas_size'), 'atlas dimensions mismatch: ' + key)
                require(region[0] >= 0 and region[1] >= 0 and region[0] + region[2] <= raster.width and region[1] + region[3] <= raster.height, 'atlas region outside image: ' + key)
                if key in proof['assets']:
                    cell = raster.crop((region[0], region[1], region[0] + region[2], region[1] + region[3])).convert('RGBA')
                    require(hashlib.sha256(cell.tobytes()).hexdigest() == proof['assets'][key]['rgba_sha256'], 'wrong asset pixels/region: ' + key)
    for path, row in proof['runtime'].items():
        require(sha(ROOT / path.removeprefix('res://')) == row['sha256'], 'runtime hash changed: ' + path)
    for row in proof['assets'].values():
        require(sha(ROOT / row['source'].removeprefix('res://')) == row['source_sha256'], 'original painting changed')
        require(sha(ROOT / row['trimmed_path'].removeprefix('res://')) == row['trimmed_sha256'], 'trim/provenance mismatch')
    return errors
