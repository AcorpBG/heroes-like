#!/usr/bin/env python3
"""Merge stable-id town upgrade designs and pack their original articulated art.

Source handoffs contain reviewed rectangles and anatomical anchors. This tool
only crops and uniformly downsamples original RGBA pixels; it never paints or
synthesizes a pose. Run --designs independently while art is being authored.
"""
import argparse
import copy
import hashlib
import json
import math
import shutil
from pathlib import Path
import tempfile

from PIL import Image
from pack_unit_pose_art import pack
from pack_overworld_creature_idle import extract
from prepare_idle_pose_alpha import prepare

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    compact = path.name in ('units.json','unit_art_manifest.json','unit_animation_manifest.json')
    path.write_text(json.dumps(data, ensure_ascii=False, indent=None if compact else 2,
                               separators=(',', ':') if compact else None) + '\n', encoding='utf-8')


def uri(path):
    return 'res://' + path.resolve().relative_to(ROOT).as_posix()


def merge_designs():
    path = ROOT / 'content/units.json'
    content = read(path)
    units = {u['id']: u for u in content['items']}
    rosters = read(ROOT / 'content/town_development.json')['rosters']
    changed = {}
    for source in sorted((ROOT / 'content/unit_upgrade_designs').glob('faction_*.json')):
        design = read(source)
        rows = design['items']
        expected = {r['unit_id']: r['upgraded_unit_id'] for r in rosters[design['faction_id']]}
        assert len(rows) == len(expected) == 12, source
        assert {r['base_id']: r['upgrade_id'] for r in rows} == expected, source
        for row in rows:
            uid, base = row['upgrade_id'], row['base_id']
            unit = row['unit']
            assert unit['id'] == uid and unit['upgrade_from'] == base
            assert unit['faction_id'] == units[uid]['faction_id'] == design['faction_id']
            assert unit['cost'] == units[uid]['cost'] and unit['growth'] == units[uid]['growth'], uid
            assert unit['abilities'] != units[base]['abilities'], uid
            assert row['name'] == unit['name'] and not unit['name'].startswith('Veteran ')
            changed[uid] = copy.deepcopy(unit)
            if 'art_source_unit_id' not in units[uid]:
                changed[uid].pop('art_source_unit_id', None)
    content['items'] = [changed.get(u['id'], u) for u in content['items']]
    write(path, content)
    for filename in ('unit_art_manifest.json', 'unit_animation_manifest.json'):
        target = ROOT / 'content' / filename
        manifest = read(target)
        for row in manifest['items']:
            if row['unit_id'] in changed:
                row['name'] = changed[row['unit_id']]['name']
        write(target, manifest)
    return len(changed)


def static_surface(image, size, ground_margin=6):
    box = image.getchannel('A').getbbox()
    cut = image.crop(box)
    scale = min((size[0] - 12) / cut.width, (size[1] - ground_margin - 6) / cut.height)
    cut = cut.resize((max(1, round(cut.width * scale)), max(1, round(cut.height * scale))), Image.Resampling.LANCZOS)
    output = Image.new('RGBA', size)
    output.paste(cut, ((size[0] - cut.width) // 2, size[1] - ground_margin - cut.height))
    return output


def original_cutout(frame, source_dir):
    """Keep portrait resolution; never enlarge the already downsampled atlas."""
    rects = frame['rects']
    left, top = min(r[0] for r in rects), min(r[1] for r in rects)
    right, bottom = max(r[2] for r in rects), max(r[3] for r in rects)
    cutout = Image.new('RGBA',(right-left,bottom-top))
    with Image.open(source_dir/frame['source']) as source:
        for rect in rects:
            cutout.paste(source.crop(rect),(rect[0]-left,rect[1]-top))
    return cutout


def action_envelope(frames, source_dir):
    """Expand transparent canvas around the original ground line, never art."""
    left = top = 0
    right, bottom = 512, 256
    for frame in frames:
        cut = original_cutout(frame, source_dir)
        scale = frame['scale']
        cut = cut.resize((max(1, round(cut.width*scale)), max(1, round(cut.height*scale))), Image.Resampling.LANCZOS)
        bounds = cut.getchannel('A').getbbox()
        x0 = min(r[0] for r in frame['rects'])
        y0 = min(r[1] for r in frame['rects'])
        x = round(256-(frame['anchor'][0]-x0)*scale)
        y = round(240-(frame['anchor'][1]-y0)*scale)
        left, top = min(left,x+bounds[0]), min(top,y+bounds[1])
        right, bottom = max(right,x+bounds[2]), max(bottom,y+bounds[3])
    side = math.ceil(max(-left,right-512)/16)*16
    above, below = math.ceil(-top/16)*16, math.ceil((bottom-256)/16)*16
    return [512+side*2,256+above+below],16+below


def canonical_idle(atlas, index, size, columns, ground_margin):
    """Compare the original 512x256 pixels relative to anatomical ground."""
    width,height=size
    x=index%columns*width+width//2-256
    y=index//columns*height+height-ground_margin-240
    return atlas.crop((x,y,x+512,y+256))


def integrate_art(handoff_path, excluded=(), included=()):
    handoff_path = handoff_path.resolve()
    handoff = read(handoff_path)
    art_path, animation_path = [ROOT / 'content' / n for n in ('unit_art_manifest.json', 'unit_animation_manifest.json')]
    art, animations = read(art_path), read(animation_path)
    arts = {r['unit_id']: r for r in art['items']}
    anims = {r['unit_id']: r for r in animations['items']}
    units_path = ROOT / 'content/units.json'
    units = read(units_path)
    unit_index = {u['id']: u for u in units['items']}
    idle_path = ROOT / 'art/overworld/creature_idle.json'
    idle = read(idle_path)
    packed = []
    for entry in handoff['units']:
        uid = entry['unit_id']
        if uid in excluded or (included and uid not in included):
            continue
        assert uid.endswith('_veteran') and uid in unit_index
        frames = copy.deepcopy(entry['frames'] + entry.get('actions', []))
        has_actions = any(frame.get('clip','idle') != 'idle' for frame in frames)
        reviewed_entry = copy.deepcopy(entry)
        reviewed_entry['frames'] = copy.deepcopy(frames)
        reviewed_entry.pop('actions', None)
        source_dir = ROOT / 'art/animation/source/poses' / uid
        source_dir.mkdir(parents=True, exist_ok=True)
        previous_recipe = read(source_dir/'packing.json') if (source_dir/'packing.json').is_file() else {}
        idle_indices = [i for i, f in enumerate(frames) if f.get('clip', 'idle') == 'idle']
        assert len(idle_indices) >= 3, f'{uid}: needs at least three original articulated poses'
        sources = {}
        prepared_sources = {}
        # All poses use ONE scale, so painted anatomy cannot pump between frames.
        scale = 1.0
        for frame_index, frame in enumerate(frames):
            source_name = frame.get('source', entry['source'])
            source = (handoff_path.parent / source_name).resolve()
            if not source.is_file():
                source = (ROOT / source_name).resolve()
            reviewed_entry['frames'][frame_index]['source'] = source.relative_to(ROOT).as_posix()
            if entry.get('alpha_noise_cutoff', 0):
                import os
                alpha_recipe = source_dir / (source.stem + '-alpha.json')
                write(alpha_recipe, {'source':Path(os.path.relpath(source,source_dir)).as_posix(), 'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(), 'alpha_noise_cutoff':entry['alpha_noise_cutoff'], 'output':source.stem+'-alpha.png'})
                prepared = source_dir / (source.stem+'-alpha.png')
                if source not in prepared_sources:
                    prepare(alpha_recipe)
                    prepared_sources[source] = prepared
                source = prepared
            frame['source'] = str(source)
            with Image.open(source) as image:
                assert image.mode == 'RGBA' and image.getchannel('A').getextrema()[0] == 0, source
                bounds = []
                for rect in frame['rects']:
                    box = image.crop(rect).getchannel('A').getbbox()
                    assert box, f'{uid}: empty source rectangle'
                    bounds.append((rect[0]+box[0],rect[1]+box[1],rect[0]+box[2],rect[1]+box[3]))
            sources[uri(source)] = hashlib.sha256(source.read_bytes()).hexdigest()
            left = min(r[0] for r in bounds); right = max(r[2] for r in bounds)
            top = min(r[1] for r in bounds); bottom = max(r[3] for r in bounds)
            ax, ay = frame['anchor']
            if frame.get('clip','idle') == 'idle':
                scale = min(scale, 244 / max(ax-left, right-ax, 1), 228 / max(ay-top, 1), 12 / max(bottom-ay, 1))
        # Adding action drawings preserves the accepted idle atlas pixels and
        # its apparent body size. Out-of-frame action painting is an art framing
        # error, never a reason to shrink every idle pose to make a gate pass.
        if has_actions and previous_recipe:
            scale = float(previous_recipe['frames'][0]['scale'])
        import os
        for i, frame in enumerate(frames):
            frame.update(source=Path(os.path.relpath(frame['source'], source_dir)).as_posix(), scale=scale*float(frame.get('scale_multiplier',1.0)), name=frame.get('name', f'idle_{i}'))
        frame_size, ground_margin = action_envelope(frames,source_dir) if has_actions else ([512,256],16)
        recipe = {'unit_id': uid, 'status': 'original_town_upgrade_poses', 'frame_size': frame_size, 'columns': 4, 'ground_margin': ground_margin, 'frames': frames}
        recipe_path = source_dir / 'packing.json'
        write(recipe_path, recipe)
        output = ROOT / 'art/animation/runtime/poses' / f'{uid}.png'
        previous_idle = []
        if has_actions and output.is_file():
            with Image.open(output) as previous_atlas:
                old=anims[uid]
                old_size=[old['pose_frame_size'][key] for key in ('width','height')]
                old_margin=old.get('pose_ground_margin',0)
                if previous_atlas.width != old_size[0]*4 or previous_atlas.height % old_size[1] != 0:
                    old_size=previous_recipe['frame_size']
                    old_margin=previous_recipe['ground_margin']
                previous_idle = [canonical_idle(previous_atlas,i,old_size,old['pose_columns'],old_margin).tobytes() for i in idle_indices]
        with tempfile.TemporaryDirectory(prefix='.town-upgrade-pack-',dir=output.parent) as directory:
            staged = Path(directory)/'atlas.png'
            result = pack(recipe_path, staged)
            with Image.open(staged) as atlas:
                poses = [canonical_idle(atlas,i,frame_size,4,ground_margin) for i in idle_indices]
                assert len({p.tobytes() for p in poses}) >= 3, f'{uid}: repeated idle paint'
                if previous_idle:
                    assert [p.tobytes() for p in poses] == previous_idle, f'{uid}: action append changed accepted idle paint'
            # Windows temporary directories have private ACLs. Moving their
            # files into runtime preserves those ACLs and can make the atlas
            # unreadable to the editor or Git running as the workspace owner.
            # Copy validated bytes so the destination keeps/inherits its normal
            # workspace permissions instead of the temporary directory's ACL.
            shutil.copyfile(staged, output)
        first = original_cutout(frames[idle_indices[0]],source_dir)
        for surface, directory, size in [('portrait','portraits',(384,512)), ('battle_icon','battle_icons',(160,160)), ('battle_standee','battle_standees',(192,224)), ('overworld_icon','overworld_icons',(96,96))]:
            target = ROOT / 'art/units' / directory / f'{uid}.png'
            static_surface(first, size).save(target, optimize=True)
            arts[uid][surface] = uri(target)
        reviewed_entry['source'] = reviewed_entry['frames'][0]['source']
        write(source_dir / 'reviewed_handoff.json', {'units':[reviewed_entry]})
        provenance = {'unit_id': uid, 'sources': sources, 'handoff': 'reviewed_handoff.json', 'packing_tool': 'tools/integrate_town_creature_upgrades.py', 'recipe': 'packing.json', 'atlas_sha256': result['sha256'], 'policy': 'Original articulated paintings; common scale and anatomical ground anchor; no synthesized pose.'}
        write(source_dir / 'provenance.json', provenance)
        for row in (arts[uid], anims[uid]):
            row.pop('shared_art_from', None)
            row.update(art_source_kind='original_town_upgrade_art_v1', curated_source=list(sources)[0], curated_source_sha256=list(sources.values())[0])
        arts[uid]['battle_standee_anchor'] = {'x': 0.5, 'y': 218/224}
        clips = {}
        for name in ('idle','move','attack','ranged','defend','hit','cast','death','dead'):
            indices = [i for i, f in enumerate(frames) if f.get('clip','idle') == name]
            if not indices:
                continue
            clips[name] = {'frames': len(indices), 'indices': indices}
            if name in ('idle','move','defend'):
                clips[name].update(loop=True, frame_msec=entry.get('frame_msec',240), static_frame=0)
        if 'dead' in clips and 'death' not in clips:
            indices = clips.get('hit',clips['dead'])['indices'][-1:] + clips['dead']['indices'][-1:]
            clips['death'] = {'frames':len(indices),'indices':indices}
        # Missing action painting is explicit fallback to the upgraded idle art,
        # never a return to a differently equipped base creature's action sheet.
        # A standing idle must never masquerade as a persistent corpse. Without
        # an authored dead painting, the existing renderer removes the body.
        aliases = {name: 'idle' for name in ('move','attack','defend','death') if name not in clips}
        for name,target in {'ranged':'attack' if 'attack' in clips else 'idle', 'hit':'defend' if 'defend' in clips else 'idle', 'cast':'idle'}.items():
            if name not in clips: aliases[name]=target
        anims[uid].update(sprite_sheet=uri(output), pose_sheet=uri(output), pose_frame_size={'width':frame_size[0],'height':frame_size[1]}, pose_reference_height=256, pose_columns=4, pose_ground_margin=ground_margin, pose_clips=clips, pose_aliases=aliases, pose_source_facing=entry.get('source_facing','right'), pose_provenance=uri(source_dir/'provenance.json'), pose_review_status='original_upgrade_articulated_idle')
        anims[uid].pop('pose_review_evidence',None)
        if all(name in clips for name in ('attack','hit','dead')):
            anims[uid]['pose_review_status'] = 'original_upgrade_articulated_idle_and_actions'
        strip, idle_entry = extract(anims[uid])
        strip_path = ROOT / idle_entry['path'].removeprefix('res://')
        if has_actions and strip_path.is_file():
            with Image.open(strip_path) as previous_strip:
                assert strip.size == previous_strip.size and strip.tobytes() == previous_strip.tobytes(), f'{uid}: action append changed overworld idle pixels'
            assert idle_entry['ground_anchor'] == idle['units'][uid]['ground_anchor'], f'{uid}: action append changed overworld ground anchor'
        strip.save(strip_path,optimize=True)
        idle_entry['sha256'] = hashlib.sha256(strip_path.read_bytes()).hexdigest()
        idle['units'][uid] = idle_entry
        unit_index[uid].pop('art_source_unit_id',None)
        packed.append(uid)
    write(art_path,art); write(animation_path,animations); write(idle_path,idle); write(units_path,units)
    return packed


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--designs',action='store_true')
    parser.add_argument('--art',type=Path)
    parser.add_argument('--exclude',nargs='*',default=[],help='Explicitly withheld candidates pending artist review')
    parser.add_argument('--only',nargs='*',default=[],help='Pack selected completed units incrementally')
    args=parser.parse_args()
    if args.designs: print(f'Merged {merge_designs()} stable upgrade definitions.')
    if args.art: print(json.dumps({'packed':integrate_art(args.art,args.exclude,args.only)}))
