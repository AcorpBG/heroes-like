"""Replay selected original poses on CPU at their authored battle-size timing.

This is a transparent-frame timing preview, not a Godot runtime acceptance.
"""
import argparse
import json
from fractions import Fraction

import av
from PIL import Image, ImageDraw

import produce as p
from prepare import reference


def preview(take):
    folder = p.SOURCE_DIR / take
    handoff = json.loads((folder / 'handoff.json').read_bytes())['units'][0]
    spec = next(iter(handoff['clips'].values()))
    frames = handoff['frames']
    duration = spec['frame_msec']
    assert duration >= 30 and not spec.get('frame_durations_msec')
    output = p.ROOT / '.artifacts/cindervane_censerwing_h3' / f'{take}_timing.mp4'
    with av.open(str(output), 'w') as video:
        stream = video.add_stream('libx264', rate=50)
        stream.width, stream.height, stream.pix_fmt = 480, 288, 'yuv420p'
        stream.options = {'crf': '17', 'preset': 'medium', 'threads': '2'}
        stream.time_base = Fraction(1, 50)
        action_ms = len(frames) * duration
        # A pause at the original ready painting separates four genuine takes;
        # the action itself is neither reversed nor padded with duplicate poses.
        period = action_ms + 800
        for tick in range((period * 4 + 19) // 20):
            phase = tick * 20 % period
            source = (frames[min(phase // duration, len(frames) - 1)]
                      if phase < action_ms else reference(16))
            canvas = Image.new('RGB', (480, 288), (28, 38, 28))
            canvas.paste((219, 212, 197), (240, 0, 480, 288))
            draw = ImageDraw.Draw(canvas)
            draw.text((8, 8), f'CPU timing preview: {take}', fill=(155, 130, 90))
            draw.text((8, 27), f'{len(frames)} poses / {action_ms}ms; Godot review pending', fill=(155, 130, 90))
            for reflected, center in [(False, 120), (True, 360)]:
                pose, (dx, dy) = p.source_pose(dict(source, scale=source['scale'] * .5), 0)
                if reflected:
                    pose = pose.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                    dx = -dx - pose.width
                canvas.paste(pose, (center + dx, 246 + dy), pose)
            frame = av.VideoFrame.from_image(canvas)
            frame.pts, frame.time_base = tick, Fraction(1, 50)
            for packet in stream.encode(frame):
                video.mux(packet)
        for packet in stream.encode():
            video.mux(packet)
    print(output, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('take')
    preview(parser.parse_args().take)
