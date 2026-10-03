"""Select observed combat motion and expose every pose at actual game scale."""
import json
from PIL import Image, ImageDraw
import produce as p
from prepare import reference
import argparse

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
    review = p.ROOT / '.artifacts/cindervane_censerwing_h3'
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
    parser=argparse.ArgumentParser(description='Pack only personally reviewed original video frames; no automatic acceptance')
    parser.add_argument('take')
    parser.add_argument('--indices',required=True,help='Chronological original video frame indices, separated by commas')
    parser.add_argument('--frame-msec',type=int,required=True)
    parser.add_argument('--contact-frame',type=int)
    parser.add_argument('--review-note',required=True)
    args=parser.parse_args()
    indices=[int(item) for item in args.indices.split(',')]
    assert len(indices)==len(set(indices)) and indices==sorted(indices)
    assert all(0<=index<124 for index in indices)
    assert args.frame_msec>=30
    assert args.contact_frame is None or 0<=args.contact_frame<len(indices)
    select(args.take,indices,args.frame_msec,args.contact_frame,args.review_note)
