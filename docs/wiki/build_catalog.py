#!/usr/bin/env python3
"""Build the wiki's static catalog. Reads game data; writes only catalog.js here.

This is a documentation build, not a game test or repository validator.
Run with Python 3.10+ from any directory. No third-party packages are required.
"""
import json
import re
import struct
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
MEDIA = {'.png', '.jpg', '.jpeg', '.webp', '.svg', '.gif', '.wav', '.ogg', '.flac', '.mp3', '.ttf', '.otf'}
DOMAINS = {
    'factions': ('Factions', 'Six banners. Six ways to rule the Reach.'),
    'heroes': ('Heroes', 'Commanders, starting magic, specialties and movement.'),
    'units': ('Units', 'Compare troops, abilities, recruitment costs and battlefield stats.'),
    'towns': ('Towns', 'Strongholds, building rosters, spell libraries and garrisons.'),
    'buildings': ('Buildings', 'Follow prerequisites and discover income, recruits and support.'),
    'spells': ('Spells', 'Schools of magic, targets, costs and exact authored effects.'),
    'artifacts': ('Artifacts', 'Equipment, bonuses, affinities and trade-offs.'),
    'artifact_sets': ('Artifact sets', 'Matching relics and their equipped-piece bonuses.'),
    'resources': ('Resources', 'The materials that fund and sustain your kingdom.'),
    'resource_sites': ('Adventure sites', 'Rewards, control income, services and recruitment.'),
    'map_objects': ('Map objects', 'Landmarks, obstacles, visit rules and terrain associations.'),
    'neutral_dwellings': ('Neutral dwellings', 'Independent companies and their recruitment sites.'),
    'army_groups': ('Armies', 'Authored troop compositions and their commanders.'),
    'encounters': ('Encounters', 'Enemy forces, battle objectives and victory rewards.'),
    'biomes': ('Biomes', 'Movement, terrain and the character of each landscape.'),
    'terrain': ('Terrain & roads', 'The surfaces, transitions and overlays of the world map.'),
    'campaigns': ('Campaigns', 'Linked chapters, starting positions and campaign stories.'),
    'scenarios': ('Scenarios', 'Authored maps, opening forces and win conditions.'),
    'sounds': ('Sound cues', 'Music, ambience and the sounds behind game actions.'),
    'effects': ('Visual effects', 'The visual language of attacks, spells and feedback.'),
}


def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8'))


def words(value):
    return re.sub(r'\s+', ' ', str(value).replace('_', ' ').replace('-', ' ')).strip().capitalize()


def paths(value):
    if isinstance(value, str) and value.startswith('res://'):
        yield value[6:]
    elif isinstance(value, dict):
        for child in value.values():
            yield from paths(child)
    elif isinstance(value, list):
        for child in value:
            yield from paths(child)


def main():
    contents = {p.stem: read(p.relative_to(ROOT)) for p in sorted((ROOT / 'content').glob('*.json'))}
    entries = []
    for category in DOMAINS:
        if category not in contents:
            continue
        for row in contents[category].get('items', []):
            entries.append({'id': row['id'], 'name': row.get('name', row.get('display_name', words(row['id']))),
                            'category': category, 'source': 'content/' + category + '.json', 'data': row})
    for row in contents['artifacts'].get('sets', []):
        entries.append({'id': row['id'], 'name': row['name'], 'category': 'artifact_sets', 'source': 'content/artifacts.json', 'data': row})
    for row in contents['terrain_grammar']['terrain_classes'] + contents['terrain_grammar']['overlay_classes']:
        entries.append({'id': 'terrain:' + row['id'], 'name': words(row['id']), 'category': 'terrain',
                        'source': 'content/terrain_grammar.json', 'data': row})
    audio_manifests = ['ui_sfx_manifest', 'presentation_sfx_manifest', 'battle_sfx_manifest', 'ambient_sfx_manifest', 'music_runtime_manifest', 'audio_production_banks']
    for name in audio_manifests:
        for key, row in contents[name]['cues'].items():
            sound_name = re.sub(r'_v0*(\d+)$', r' · variation \1', key.removeprefix('production_').removeprefix('audio_placeholder_'))
            entries.append({'id': 'sound:' + key, 'name': words(sound_name), 'category': 'sounds',
                            'source': 'content/' + name + '.json', 'data': {'cue_id': key, **row}})
    for name in ['battle_vfx_manifest', 'overworld_vfx_manifest', 'town_vfx_manifest', 'system_feedback_vfx_manifest']:
        for key, row in contents[name].get('cues', {}).items():
            entries.append({'id': 'effect:' + key, 'name': words(key.removeprefix('vfx_').removeprefix('placeholder_')),
                            'category': 'effects', 'source': 'content/' + name + '.json', 'data': row})
    for asset_id, row in read('art/overworld/decorative_object_sprites.json').get('generated_body_appearances', {}).items():
        entries.append({'id': 'rmg_blocker:' + asset_id, 'name': row['name'], 'category': 'map_objects',
                        'source': 'art/overworld/decorative_object_sprites.json',
                        'data': {**row, 'family': 'blocker', 'role': 'rmg_scenery', 'passable': False,
                                 'visitable': False, 'icon_path': row['runtime_path']}})
    by_id = {e['id']: e for e in entries}
    labels = {key: row['name'] for key, row in by_id.items()}

    def quantities(value):
        return ', '.join(str(v) + ' ' + labels.get(k, words(k)) for k, v in value.items() if isinstance(v, (int, float)) and v != 0)

    def description(e):
        d, cat = e['data'], e['category']
        text = next((d[k] for k in ['description', 'identity_summary', 'public_summary', 'summary', 'public_text', 'identity', 'readability_role'] if isinstance(d.get(k), str) and d[k]), '')
        if not text:
            text = d.get('ui', {}).get('summary', '') or d.get('selection', {}).get('summary', '')
        if cat == 'units':
            text = f"Tier {d.get('tier', '?')} {'ranged' if d.get('ranged') else 'melee'} troop. " + ' '.join(a.get('description', '') for a in d.get('abilities', []))
        elif cat == 'resources':
            text = {
                'gold': 'Pays for troops, buildings, hero recruitment and market trades.',
                'wood': 'Construction material used by buildings, army recruitment and trades.',
                'ore': 'Construction and equipment material used by buildings and recruitment.',
                'experience': 'Advances hero progression when awarded by encounters and events.',
            }.get(e['id'], f"A {words(d.get('category', 'kingdom')).lower()} resource. Its costs and rewards are listed in the related entries below.")
        elif cat == 'army_groups':
            text = 'Authored army composition: ' + ', '.join(f"{s['count']} {labels.get(s['unit_id'], words(s['unit_id']))}" for s in d.get('stacks', [])) + '.'
        elif cat == 'map_objects' and not text:
            text = f"{words(d.get('family', 'map'))} landmark. "
            text += 'Can be visited' if d.get('visitable') else 'A scenery or terrain object without a visit action'
            text += '; units can pass through it.' if d.get('passable') else '; its footprint blocks movement.'
            interaction = d.get('interaction', {})
            if interaction.get('requires_guard_clear'): text += ' Its guard must be cleared before use.'
        elif cat == 'resource_sites':
            pieces = [text] if text else []
            for field, phrase in [('rewards', 'Visit reward'), ('claim_rewards', 'Claim reward'), ('control_income', 'Control income'), ('claim_recruits', 'Claim recruits'), ('weekly_recruits', 'Weekly recruits')]:
                if quantities(d.get(field, {})): pieces.append(phrase + ': ' + quantities(d[field]) + '.')
            text = ' '.join(pieces) or f"{words(d.get('family', 'adventure')).capitalize()} site. Its visit rules and linked map object determine how it is used."
        elif cat == 'encounters' and not text:
            text = f"A {words(d.get('terrain', 'field')).lower()} battle against {labels.get(d.get('enemy_group_id'), 'the listed enemy force')}."
            if d.get('rewards'): text += ' Victory rewards: ' + quantities(d['rewards']) + '.'
        elif cat == 'biomes':
            text = f"{e['name']} landscape. Base movement cost: {d.get('movement_cost', 1)}. " + ('Traversable terrain.' if d.get('passable') else 'Not normally traversable.')
        elif cat == 'sounds':
            kind = 'Full musical composition' if d.get('playback_mode') == 'full_mix' else 'Music layer' if 'music_' in e['source'] else 'Ambient sound bed' if 'ambient_' in e['source'] else 'Action sound'
            text = f"{kind} for {words(d.get('role', d.get('cue_id', 'game feedback'))).lower()}."
            if d.get('duration_msec'): text += f" Duration: {d['duration_msec'] / 1000:g} seconds."
            if d.get('repeat_cooldown_msec'): text += f" Repetition cooldown: {d['repeat_cooldown_msec']} ms."
        elif cat == 'effects':
            text = f"Visual feedback for {e['name'].lower()}; presented as {words(d.get('render_mode', 'gameplay feedback')).lower()}. It communicates an event; the gameplay rules determine the effect."
        return text or f"{e['name']} is an authored {DOMAINS[cat][0].lower()} entry. Its properties and related content are listed below."

    # Media inventory includes source art and source audio, without copying them.
    asset_paths = sorted(p for p in (ROOT / 'art').rglob('*') if p.is_file() and p.suffix.lower() in MEDIA)
    if (ROOT / 'icon.svg').exists(): asset_paths.append(ROOT / 'icon.svg')
    assets = []
    for p in asset_paths:
        path = p.relative_to(ROOT).as_posix()
        archive = any(t in path for t in ['/source/', '/alternates/', '/homm3_local_prototype/', '/experiments/', '/source_sheets/', '/runtime/terrain_tiles/generated/', '/runtime/terrain/'])
        kind = 'audio' if p.suffix.lower() in {'.wav', '.ogg', '.flac', '.mp3'} else 'art'
        group = path.split('/')[1] if '/' in path else 'branding'
        assets.append({'id': 'asset:' + path, 'path': path, 'name': words(p.stem), 'kind': kind,
                       'group': group, 'archive': archive, 'bytes': p.stat().st_size, 'uses': [], 'files': [], 'roles': []})
        if p.suffix.lower() == '.png':
            with p.open('rb') as stream: header = stream.read(24)
            if header.startswith(b'\x89PNG\r\n\x1a\n'):
                assets[-1]['width'], assets[-1]['height'] = struct.unpack('>II', header[16:24])
    asset_by_path = {a['path']: a for a in assets}
    entity_media = defaultdict(dict)

    def attach(entity_id, path, role='', origin='', rect=None):
        path = path.removeprefix('res://')
        asset = asset_by_path.get(path)
        if asset is None: return
        if entity_id in by_id:
            if entity_id not in asset['uses']: asset['uses'].append(entity_id)
            entity_media[entity_id][path] = {'path': path, **({'rect': rect} if rect else {}), 'role': words(role)}
        if origin and origin not in asset['files']: asset['files'].append(origin)
        if role and words(role) not in asset['roles']: asset['roles'].append(words(role))

    def scan(value, origin, owner='', role=''):
        if isinstance(value, dict):
            owner = next((value[k] for k in ['id', 'unit_id', 'hero_id', 'building_id', 'spell_id'] if value.get(k) in by_id), owner)
            for k, v in value.items(): scan(v, origin, k if k in by_id else owner, k)
        elif isinstance(value, list):
            for v in value: scan(v, origin, owner, role)
        elif isinstance(value, str) and value.startswith('res://'): attach(owner, value, role, origin)

    for name, d in contents.items(): scan(d, 'content/' + name + '.json')
    for p in sorted((ROOT / 'art').rglob('*.json')):
        scan(read(p.relative_to(ROOT)), p.relative_to(ROOT).as_posix())
    for e in entries:
        for path in paths(e['data']): attach(e['id'], path, 'Associated media', e['source'])
    for folder in ['scenes', 'scripts']:
        for p in (ROOT / folder).rglob('*'):
            if p.suffix not in {'.gd', '.tscn', '.tres'}: continue
            for path in re.findall(r'res://(art/[^\s\"\'\)]+)', p.read_text(encoding='utf-8')):
                attach('', path, 'Scene presentation', p.relative_to(ROOT).as_posix())

    overworld = read('art/overworld/manifest.json')
    object_assets = overworld['object_assets']

    def sprite(entity_id, sprite_id, role):
        if isinstance(sprite_id, dict): sprite_id = sprite_id.get('asset_id')
        row = object_assets.get(sprite_id, {})
        if row.get('path'):
            rect = row.get('region') or row.get('atlas_region')
            if isinstance(rect, dict): rect = [rect.get(k, 0) for k in ['x', 'y', 'width', 'height']]
            attach(entity_id, row['path'], role, 'art/overworld/manifest.json', rect)

    for table in ['resource_site_sprites', 'artifact_field_sprites', 'town_identity_sprites', 'hero_identity_sprites', 'encounter_identity_sprites', 'town_faction_sprites']:
        for key, value in overworld.get(table, {}).items(): sprite(key, value, 'Overworld sprite')
    for filename in ['map_object_sprites', 'decorative_object_sprites']:
        for key, value in read('art/overworld/' + filename + '.json')['object_sprite_mappings'].items(): sprite(key, value, 'Map object sprite')

    sound_relations = defaultdict(list)
    audio = contents['audio_production_banks']
    def sound_bank(entity_id, bank, role):
        for cue in audio['banks'].get(bank, []):
            sound_id = 'sound:' + cue
            if sound_id in by_id:
                if sound_id not in sound_relations[entity_id]: sound_relations[entity_id].append(sound_id)
                attach(entity_id, by_id[sound_id]['data']['path'], role, 'content/audio_production_banks.json')
    for entity_id, profile in audio['unit_profiles'].items():
        for gesture in ['move', 'attack', 'hit', 'defeat']:
            sound_bank(entity_id, profile['body_bank'] + '_' + gesture, gesture + ' sound')
        for key in ['weapon_bank', 'impact_bank']:
            if profile.get(key): sound_bank(entity_id, profile[key], key.removesuffix('_bank') + ' sound')
    for entity_id, banks in audio['spell_banks'].items():
        for gesture in ['cast', 'effect', 'expire']:
            if banks.get(gesture): sound_bank(entity_id, banks[gesture], gesture + ' sound')
    for p in sorted((ROOT / 'art/audio/source/stable_audio_3_v1/provenance').glob('*.json')):
        record = read(p.relative_to(ROOT))
        for kind in ['source', 'master', 'runtime']:
            a = asset_by_path.get(record.get(kind + '_path', '').removeprefix('res://'))
            if a:
                a['production'] = {'role': words(record.get('brief_id', record.get('id', 'audio'))),
                                   'gesture': words(record.get('gesture', '')), 'category': words(record.get('category', '')),
                                   'stage': kind, 'prompt': record.get('prompt', ''), 'reference': p.relative_to(ROOT).as_posix()}

    primary = {}
    for name, key in [('unit_art_manifest', 'battle_standee'), ('hero_art_manifest', 'portrait'), ('building_art_manifest', 'icon_path'), ('spell_icons', 'icon_path'), ('faction_crests', 'icon_path')]:
        for row in contents[name]['items']:
            if row.get(key): primary[row['id']] = {'path': row[key].removeprefix('res://')}
    for e in entries:
        d = e['data']
        e['description'] = description(e)
        e['faction'] = d.get('faction_id', d.get('player_faction_id', ''))
        e['tags'] = list(dict.fromkeys(str(v) for v in [d.get('role'), d.get('category'), d.get('family'), d.get('school_id'), d.get('rarity'), d.get('context'), d.get('strategic_role')] if v))
        if d.get('contains_dead_tree'):
            e['tags'].append('dead_tree')
        if d.get('production_kind'):
            e['tags'].append(d['production_kind'])
        e['media'] = list(entity_media[e['id']].values())
        special = d.get('scenic_backdrop_path') or d.get('emblem_path') or d.get('icon_path') or d.get('ui', {}).get('icon_path')
        e['portrait'] = primary.get(e['id']) or ({'path': special.removeprefix('res://')} if special else next((m for m in e['media'] if m['path'].endswith('.png') and not asset_by_path[m['path']]['archive']), None))
        refs = defaultdict(set)

        def relations(v, label='Related content'):
            if isinstance(v, dict):
                for k, item in v.items():
                    if k in by_id and k != e['id']: refs[label].add(k)
                    if k not in {'enemy_strategy', 'ai_hints', 'validation_tags', 'id', 'faction_id', 'player_faction_id'}:
                        relations(item, words(k.removesuffix('_ids').removesuffix('_id')))
            elif isinstance(v, list):
                for item in v: relations(item, label)
            elif isinstance(v, str) and v in by_id and v != e['id']: refs[label].add(v)
        relations(d)
        e['relations'] = {key: sorted(ids, key=lambda id: labels[id]) for key, ids in refs.items()}
        if sound_relations[e['id']]: e['relations']['Associated sounds'] = sound_relations[e['id']]

    for a in assets:
        role = next((r for r in a['roles'] if r not in ['Associated media', 'Path', 'Source path', 'Runtime path']), '')
        scope = 'Source/archive' if a['archive'] else 'Presentation'
        if a['uses']:
            names = ', '.join(labels[id] for id in a['uses'][:3])
            a['description'] = f"{scope} {'audio' if a['kind'] == 'audio' else 'artwork'} associated with {names}."
        else:
            roles = {'towns': 'town scenery and building presentation', 'overworld': 'world-map scenery, terrain or landmarks', 'units': 'troop presentation', 'animation': 'unit animation states', 'audio': 'music or sound production', 'ui': 'interface presentation', 'battle': 'battlefield feedback', 'campaigns': 'campaign presentation', 'magic': 'spell presentation', 'heroes': 'hero presentation', 'artifacts': 'equipment presentation', 'economy': 'resource presentation', 'factions': 'faction heraldry'}
            a['description'] = f"{scope} file in the {roles.get(a['group'], 'game art')} library."
        if role: a['description'] += ' Role: ' + role.lower() + '.'
        if a.get('production'):
            p = a['production']
            cue = next((by_id[id] for id in a['uses'] if by_id[id]['category'] == 'sounds'), None)
            if cue:
                a['name'] = cue['name']
                a['description'] = cue['description'] + f" This is the {p['stage']} recording."
            else:
                a['description'] = f"{words(p['stage'])} recording for {p['role'].lower()}{' — ' + p['gesture'].lower() if p['gesture'] else ''}. {p['category']} production asset."
        if a['kind'] == 'art' and len(a['uses']) == 1:
            a['name'] = labels[a['uses'][0]] + (' · ' + role if role else ' · Artwork')
        if re.fullmatch(r'[\d_]+', Path(a['path']).stem):
            terrain = next((name for key, name in {'grastl':'Grass', 'dirttl':'Dirt', 'rocktl':'Rock', 'sandtl':'Sand', 'watrtl':'Water', 'snowtl':'Snow', 'lavtl':'Lava', 'swmptl':'Swamp', 'subbtl':'Underground', 'rougtl':'Rough'}.items() if '/' + key + '/' in a['path']), 'Terrain')
            a['name'] = terrain + ' tile · ' + words(Path(a['path']).stem)
            a['description'] = f"{terrain} tile frame used to compose a continuous terrain surface. Neighbouring terrain determines which tile variant a renderer selects. " + ('Retained renderer/reference artwork; excluded from the official game export.' if a['archive'] else 'Part of the terrain artwork library.')
        if '/source/' in a['path']: a['description'] += ' Retained production source; not a shipped gameplay object.'
        elif '/homm3_local_prototype/' in a['path']: a['description'] += ' Local reference material, excluded from official game packages.'
        elif not a['files']: a['description'] += ' No direct manifest or literal scene reference was found; placement may be dynamic or archival.'
        # Related entries supply precise gameplay explanations; the asset itself
        # only communicates those rules and never creates an additional bonus.
    counts = Counter(e['category'] for e in entries)
    result = {'title': 'Aurelion Reach', 'edition': '13 September 2026',
              'categories': [{'id': k, 'name': v[0], 'description': v[1], 'count': counts[k]} for k, v in DOMAINS.items()],
              'entries': entries, 'assets': assets,
              'coverage': {'entries': len(entries), 'media': len(assets), 'art': sum(a['kind'] == 'art' for a in assets),
                           'audio': sum(a['kind'] == 'audio' for a in assets), 'archive': sum(a['archive'] for a in assets)},
              'heroImage': 'art/towns/runtime/backdrops/complete_identities/town_riverwatch.png'}
    catalog = HERE / 'catalog.js'
    staging = HERE / 'catalog.js.tmp'
    staging.write_text('/* Generated by build_catalog.py. Do not edit by hand. */\nwindow.WIKI_CATALOG = ' + json.dumps(result, ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/') + ';\n', encoding='utf-8')
    staging.replace(catalog)
    print('Built wiki catalog:', json.dumps(result['coverage']))


if __name__ == '__main__':
    main()
