"""Select observed combat motion and expose every pose at actual game scale."""
import json
from PIL import Image, ImageDraw
import produce as p
from prepare import reference

def select(take, indices, timing, contact, note, separation=None):
    out = p.SOURCE_DIR / take
    recipe = dict(source_frames=indices, frame_msec=timing, review_note=note)
    if contact is not None:
        recipe['contact_frame'] = contact
    if separation:
        recipe['runtime_projectile_separation'] = {
            str(i): dict(axis='x', split_x=x,
                         reason='Detached video projectile separated across a verified empty gap; runtime owns projectile flight.')
            for i, x in separation.items()}
    p.write(out / 'selection.json', recipe)
    p.build(out, json.loads((out / 'config.json').read_bytes()))
    handoff = json.loads((out / 'handoff.json').read_bytes())['units'][0]
    frames = handoff['frames'] + [dict(reference(i), clip='idle',
                                      name=f'original_idle_{i}') for i in range(16, 24)]
    cells = [(frame, reflected) for reflected in (False, True) for frame in frames]
    review = p.ROOT / '.artifacts/noonshard_prism_kite_h3'
    for page in range((len(cells) + 15) // 16):
        sheet = Image.new('RGB', (800, 864), (30, 40, 30))
        draw = ImageDraw.Draw(sheet)
        for cell, (frame, reflected) in enumerate(cells[page*16:(page+1)*16]):
            x, y = cell % 4 * 200, cell // 4 * 216
            if cell % 2:
                sheet.paste((218, 211, 193), (x, y, x+200, y+216))
            im, (dx, dy) = p.source_pose(dict(frame, scale=frame['scale']*.5), 0)
            if reflected:
                im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                dx = -dx-im.width
            sheet.paste(im, (x+100+dx, y+200+dy), im)
            draw.text((x+5, y+4), f'{frame["clip"]} {frame.get("video_frame", frame["name"])} '
                      f'{"left" if reflected else "right"}', fill=(140, 115, 75))
        sheet.save(review / f'{take}_native_cpu_{page:02d}.png')
    print(f'{take}: {len(indices)} original poses, {len(indices)*timing}ms; both-facing review prepared.', flush=True)

if __name__ == '__main__':
    select('attack_h3_v3', list(range(10, 20))+list(range(73, 85)), 40, 8,
           'All124 original RGB and enlarged RGBA personally reviewed: closed-mouth physical claw reach. '
           'Retain anticipation10-19 and recovery73-84, omitting a long static extended-claw hold20-72. '
           'Four wings, two gold legs and two tail fronds remain intact. Native CPU/Godot acceptance pending.')
    select('ranged_h3_v1', list(range(20, 53, 2))+list(range(58, 77))+list(range(78, 99, 2)), 32, 16,
           'All124 original RGB and enlarged RGBA personally reviewed. Retain aim20-52 and recoil/recovery58-98. '
           'Connected generated beam53-57 excluded completely, never erased from a selected body frame. '
           'Detach projectile only in58,59,60,62 through original empty vertical gaps. '
           'No synthetic poses or per-frame geometry changes. Native CPU/Godot acceptance pending.',
           {58:779, 59:775, 60:770, 62:800})
