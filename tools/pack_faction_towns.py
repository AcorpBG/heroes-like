"""Pack faction-specific towns with shared scale and authored gate anchors.

Only crop transparent margins and downsample uniformly. Never recolour, stretch
or paint over the generated source. Register each doorway independently of the
lowest wheel, piling or root so irregular silhouettes keep the same entrance.
"""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('art/overworld/source/generated/towns/distinct_factions_20260920')
OUTPUT = Path('art/overworld/runtime/objects/towns/distinct_factions')


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
        crop_size = image.size
        image.thumbnail((480, 480), Image.Resampling.LANCZOS)
        canvas = Image.new('RGBA', (512, 512))
        offset = ((512-image.width)//2, (512-image.height)//2)
        canvas.paste(image, offset)
        entrance = entry['entrance_threshold_source_px']
        if not (bounds[0] <= entrance[0] < bounds[2] and bounds[1] <= entrance[1] < bounds[3]):
            raise ValueError(f'Entrance outside painted town: {source}')
        anchor = [round(offset[i] + (entrance[i]-bounds[i]) * image.size[i]/crop_size[i], 4) for i in range(2)]
        faction = entry['faction_id'].removeprefix('faction_')
        output = OUTPUT / (faction + '.png')
        canvas.save(ROOT / output, optimize=True)
        manifest['object_assets'][entry['asset_id']] = {
            'path': 'res://' + output.as_posix(),
            'source_generated': 'res://' + source.as_posix(),
            'source_processing_manifest': 'res://' + (SOURCE / 'provenance.json').as_posix(),
            'source_model': 'built_in_image_gen_original_distinct_faction_town',
            'asset_policy': 'original_generated_runtime_sprite_no_homm3_art_import',
            'assigned_faction_id': entry['faction_id'],
            'presentation_role': 'shared_faction_town',
            'runtime_sha256': hashlib.sha256((ROOT / output).read_bytes()).hexdigest(),
            'town_entrance_anchor_px': anchor,
            'accessible_description': entry['accessible_description'],
            'environment_policy': 'Neutral structural foundations on every biome; front-centre entrance, no baked ownership flags or terrain island.',
        }
        manifest['town_art_policy']['selected_designs'][entry['faction_id']] = entry['asset_id']
        print(f'{entry["asset_id"]}: {image.width}x{image.height} painted extent in 512x512 RGBA')
    manifest['town_art_policy']['camera_and_scale'] = 'Shared elevated orthographic camera, broad five-column scale and centered south entrance; each faction retains its own construction system, ground outline and skyline.'
    manifest['town_art_policy']['entrance_alignment'] = 'Optional town_entrance_anchor_px identifies the doorway threshold on its 512px sprite. The renderer aligns that point with the common entrance ground line instead of aligning dangling roots, wheels or pilings.'
    path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False)+'\n', encoding='utf-8', newline='\n')


if __name__ == '__main__':
    main()
