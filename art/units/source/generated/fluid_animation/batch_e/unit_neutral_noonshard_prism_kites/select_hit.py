"""Select the actual physical reaction and prepare native-size CPU review."""
import json
from PIL import Image, ImageDraw
import produce as p
from prepare import reference

if __name__ == '__main__':
    out = p.SOURCE_DIR / 'hit_h3_v1'
    config = json.loads((out / 'config.json').read_bytes())
    indices = list(range(20, 35, 2)) + list(range(37, 101, 3))
    note = ('Personally reviewed all124 original lossless RGB and all124 enlarged '
            'semantic RGBA frames. Select the physical upward neck recoil, wing '
            'brace and complete recovery20-100, thinning original held phases '
            'without synthesising poses. Four attached glass wings, two gold '
            'talons and two tail fronds remain intact. Source48 contains a small '
            'detached background fleck and is not selected. One fixed original '
            'scale and anchor. Native CPU right/reflected and Godot reviews '
            'remain pending.')
    p.write(out / 'selection.json', dict(source_frames=indices,
                                       frame_msec=30, review_note=note))
    p.build(out, config)
    handoff = json.loads((out / 'handoff.json').read_bytes())['units'][0]
    frames = handoff['frames'] + [dict(reference(i), clip='idle',
                                      name=f'original_idle_{i}')
                                 for i in range(16, 24)]
    cells = [(frame, reflected) for reflected in (False, True) for frame in frames]
    review = p.ROOT / '.artifacts/noonshard_prism_kite_h3'
    for page in range((len(cells) + 15) // 16):
        sheet = Image.new('RGB', (800, 864), (30, 40, 30))
        draw = ImageDraw.Draw(sheet)
        for cell, (frame, reflected) in enumerate(cells[page*16:(page+1)*16]):
            x, y = cell % 4 * 200, cell // 4 * 216
            if cell % 2:
                sheet.paste((218, 211, 193), (x, y, x+200, y+216))
            f = dict(frame, scale=frame['scale'] * .5)
            im, (dx, dy) = p.source_pose(f, frame.get('alpha_noise_cutoff', 0))
            if reflected:
                im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                dx = -dx-im.width
            sheet.paste(im, (x+100+dx, y+200+dy), im)
            draw.text((x+5, y+4), f'{frame["clip"]} '
                      f'{frame.get("video_frame", frame["name"])} '
                      f'{"left" if reflected else "right"}',
                      fill=(140, 115, 75))
        sheet.save(review / f'hit_native_cpu_{page:02d}.png')
    print(f'Selected{len(indices)} source reaction poses; native CPU right/reflected prepared.', flush=True)
