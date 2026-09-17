"""Current source/art checks; no disposable historical evidence is required."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def validate(root=ROOT, config=None, source=None):
    errors = []
    manifest = json.loads((root / 'art/overworld/manifest.json').read_text())
    rendering = manifest['terrain_rendering']
    config = config if config is not None else json.loads((root / 'art/overworld/ground_materials.json').read_text())
    source = source if source is not None else json.loads((root / config['source_manifest'].removeprefix('res://')).read_text())
    def require(condition, message):
        if not condition:
            errors.append('Ground materials: ' + message)
    require(config.get('model') == 'original_raster_world_space_splat_v3', 'wrong live renderer model')
    slots = config.get('terrain_slots', {})
    grammar = json.loads((root / 'content/terrain_grammar.json').read_text())
    required = set(rendering['raster_base_v2']['terrain_assets']) | {row['id'] for row in grammar['terrain_classes']}
    require(required <= set(slots), 'missing terrain identities: ' + ', '.join(sorted(required - set(slots))))
    require(all(type(value) is int and 0 <= value < 16 for value in slots.values()), 'out-of-range/non-integer material slot')
    require(set(slots.values()) == set(range(16)), 'all sixteen original materials must remain reachable')
    require(config.get('material_span_tiles') == 6, 'material sampling scale differs from shader')
    require(source.get('generation_mode') == 'built_in_image_gen', 'original generation provenance absent')
    require(len(source.get('sources', [])) == 4, 'four original sheets required')
    require(source.get('runtime', {}).get('path') == config.get('atlas'), 'runtime/source manifest path mismatch')
    for entry in source.get('sources', []) + [source.get('runtime', {})]:
        path = root / entry.get('path', '').removeprefix('res://')
        require(path.is_file(), f'missing original/runtime raster: {path}')
        if not path.is_file():
            continue
        require(hashlib.sha256(path.read_bytes()).hexdigest() == entry.get('sha256'), f'provenance hash mismatch: {path.name}')
        with Image.open(path) as painting:
            require(list(painting.size) == entry.get('size'), f'canvas differs from provenance: {path.name}')
        if entry in source['sources']:
            require(len(entry.get('prompt', '')) > 200, f'original prompt missing: {path.name}')
    require(source.get('runtime', {}).get('size') == [2048, 2048], 'runtime atlas must match shader layout')
    shader = (root / 'scenes/overworld/overworld_ground_surface.gdshader').read_text()
    require('filter_nearest' in shader and 'known_slot' in shader and 'own.g < 0.5' in shader, 'fog-safe exact lookup missing')
    require('TIME' not in shader, 'ground sampling must not swim/animate')
    return errors


if __name__ == '__main__':
    failures = validate()
    print('\n'.join(failures) if failures else 'Original ground material/provenance contract passes')
    raise SystemExit(bool(failures))
