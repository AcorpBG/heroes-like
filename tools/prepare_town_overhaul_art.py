"""Package original overhaul paintings and merge their live faction scene bindings.

Artwork is generated separately. This step only crops transparent margins and
resizes the saved masters; production.json records sources, prompts and placement.
"""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACKET = ROOT / 'art/towns/source/generated/overhaul/production.json'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def save(path, payload):
    path.write_text(json.dumps(payload, indent=2) + '\n', encoding='utf-8')


def uri(path):
    return 'res://' + path.relative_to(ROOT).as_posix()


def save_backdrops(path, payload):
    # This older manifest keeps stage records inline. Replace only changed
    # records, retaining the surrounding formatting and other factions.
    text = path.read_text(encoding='utf-8')
    previous = json.loads(text)
    for faction, row in payload['factions'].items():
        for stage, metadata in row['stages'].items():
            if previous['factions'][faction]['stages'][stage] == metadata:
                continue
            faction_start = text.index('"' + faction + '":')
            value_start = text.index('"' + stage + '":', faction_start)
            value_start = text.index('{', value_start)
            _, count = json.JSONDecoder().raw_decode(text[value_start:])
            text = text[:value_start] + json.dumps(metadata) + text[value_start+count:]
    path.write_text(text, encoding='utf-8')


def main():
    scene_path = ROOT / 'content/town_building_scene_art_manifest.json'
    layout_path = ROOT / 'content/town_building_scene_layouts.json'
    backdrop_path = ROOT / 'content/town_development_scene_manifest.json'
    scene, layout, backdrop = map(read, (scene_path, layout_path, backdrop_path))
    packet = read(PACKET)
    for item in packet['items']:
        source = ROOT / item['source_path']
        prompt = ROOT / item['prompt_path']
        if digest(source) != item['source_sha256']:
            raise ValueError('Changed original master: ' + str(source))
        faction, name = item['faction_id'], item['id']
        image = Image.open(source)
        metadata = {
            'source_path': uri(source), 'source_sha256': digest(source),
            'source_size': list(image.size), 'prompt_path': uri(prompt),
            'prompt_sha256': digest(prompt), 'generation_output': item['generation_output'],
            'generation_date': item['generation_date'], 'generation_tool': item['tool'],
            'reference_inputs': item['reference_inputs'], 'processing_tool': 'tools/prepare_town_overhaul_art.py',
        }
        if item['kind'] == 'backdrop':
            runtime = ROOT / f'art/towns/runtime/backdrops/overhaul/{faction}_{name}.png'
            runtime.parent.mkdir(parents=True, exist_ok=True)
            # The generated source is 16:9 to rounding precision. Match the
            # established scene coordinate system without changing composition.
            image.convert('RGB').resize((1600, 900), Image.Resampling.LANCZOS).save(runtime)
            metadata.update(runtime_path=uri(runtime), runtime_sha256=digest(runtime))
            backdrop['factions'][faction]['stages'][item['stage']] = metadata
            continue
        if image.mode != 'RGBA' or image.getchannel('A').getextrema() != (0, 255):
            raise ValueError('Building must have real transparent alpha: ' + str(source))
        bounds = image.getchannel('A').getbbox()
        cropped = image.crop(bounds)
        runtime = ROOT / f'art/towns/runtime/scene_layers/overhaul/{faction}/{name}.png'
        icon = ROOT / f'art/towns/runtime/buildings/overhaul/{faction}/{name}.png'
        for path in (runtime, icon):
            path.parent.mkdir(parents=True, exist_ok=True)
        rendered = cropped.copy()
        rendered.thumbnail((512, 512), Image.Resampling.LANCZOS)
        rendered.save(runtime)
        thumb = cropped.copy()
        thumb.thumbnail((240, 240), Image.Resampling.LANCZOS)
        canvas = Image.new('RGBA', (256, 256))
        canvas.paste(thumb, ((256-thumb.width)//2, (256-thumb.height)//2))
        canvas.save(icon)
        width = item['visible_width']
        height = width * cropped.height / cropped.width
        x, y = item['ground_anchor']
        metadata.update({
            'asset_id': faction + '_' + name, 'trim_box': list(bounds),
            'runtime_path': uri(runtime), 'runtime_sha256': digest(runtime),
            'runtime_size': list(rendered.size), 'icon_path': uri(icon), 'icon_sha256': digest(icon),
            'normalized_rect': [(x-width/2)/1600, (y-height)/900, width/1600, height/900],
            'ground_anchor': [x/1600, y/900], 'modulate': [1, 1, 1, 1], 'hit_alpha_threshold': .25,
            'grounding': 'Civic building sits on the cleared right-bank courtyard with its entrance facing the quay; successive stages retain the same ground anchor.',
            'curation': 'Original separate upgrade painting; see production packet for source and prompt. Runtime rendering is reviewed per integrated slice.',
        })
        scene['factions'][faction][name] = metadata
        for plot in layout['factions'][faction]['plots']:
            if plot['plot_id'] == item['plot_id']:
                plot['embedded_in_base'] = False
    for path, payload in ((scene_path, scene), (layout_path, layout)):
        save(path, payload)
    save_backdrops(backdrop_path, backdrop)
    print(f"Packaged {len(packet['items'])} original paintings; existing faction layers preserved.")


if __name__ == '__main__':
    main()
