"""Pack the five faction town repaints; Embercourt remains the visual reference.

Only crop transparent margins and downsample uniformly. Never recolour, stretch
or paint over the generated source. Runtime placement already aligns the painted
bottom centre with the shared town entrance.
"""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('art/overworld/source/generated/towns/matched_factions_20260920')
OUTPUT = Path('art/overworld/runtime/objects/towns/matched_factions')


def main():
    provenance = json.loads((ROOT / SOURCE / 'provenance.json').read_text(encoding='utf-8'))
    path = ROOT / 'art/overworld/manifest.json'
    manifest = json.loads(path.read_text(encoding='utf-8'))
    (ROOT / OUTPUT).mkdir(parents=True, exist_ok=True)
    for entry in provenance['assets']:
        source = SOURCE / entry['source']
        with Image.open(ROOT / source) as original:
            image = original.convert('RGBA')
        alpha = image.getchannel('A')
        bounds = alpha.point(lambda a: 255 if a > 8 else 0).getbbox()
        if not bounds or alpha.getextrema()[0] != 0:
            raise ValueError(f'Expected transparent isolated town: {source}')
        image = image.crop(bounds)
        image.thumbnail((480, 480), Image.Resampling.LANCZOS)
        canvas = Image.new('RGBA', (512, 512))
        canvas.paste(image, ((512-image.width)//2, (512-image.height)//2))
        faction = entry['faction_id'].removeprefix('faction_')
        output = OUTPUT / (faction + '.png')
        canvas.save(ROOT / output, optimize=True)
        manifest['object_assets'][entry['asset_id']] = {
            'path': 'res://' + output.as_posix(),
            'source_generated': 'res://' + source.as_posix(),
            'source_processing_manifest': 'res://' + (SOURCE / 'provenance.json').as_posix(),
            'source_model': 'built_in_image_gen_original_matched_faction_town',
            'asset_policy': 'original_generated_runtime_sprite_no_homm3_art_import',
            'assigned_faction_id': entry['faction_id'],
            'presentation_role': 'shared_faction_town',
            'runtime_sha256': hashlib.sha256((ROOT / output).read_bytes()).hexdigest(),
            'accessible_description': entry['accessible_description'],
            'environment_policy': 'Neutral structural foundations on every biome; front-centre entrance, no baked ownership flags or terrain island.',
        }
        manifest['town_art_policy']['selected_designs'][entry['faction_id']] = entry['asset_id']
        print(f'{entry["asset_id"]}: {image.width}x{image.height} painted extent in 512x512 RGBA')
    manifest['town_art_policy']['camera_and_scale'] = 'Embercourt reference: elevated orthographic camera, horizontal front facade, broad five-column settlement, fine weathered architecture and centered south entrance.'
    path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False)+'\n', encoding='utf-8', newline='\n')


if __name__ == '__main__':
    main()
