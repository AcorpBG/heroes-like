"""Prepare source-backed Harbor corrections; never submit or overwrite originals."""
import json
from pathlib import Path
import produce as p
from prepare_h3 import ref, IDENTITY, PLATE


def prepare(name, baseline, references, guides, action, seed):
    out = p.SOURCE_DIR/name
    out.mkdir(exist_ok=False)
    c = json.loads((p.SOURCE_DIR/baseline/'config.json').read_bytes())
    c.update(references=references, guides=guides, last=0, seed=seed,
             prompt=(IDENTITY+action+PLATE).strip())
    p.write(out/'config.json', c)
    p.prepare(out, c)
    return out


if __name__ == '__main__':
    passing_path = p.SOURCE_DIR/'move_h3_v1/matte/rgba_068.png'
    passing = dict(name='observed_near_knee_passing_068',
                   source=passing_path.relative_to(p.ROOT).as_posix(),
                   rects=[[0,0,960,640]], anchor=[420,560], scale=.5,
                   alpha_noise_cutoff=0, video_frame=68,
                   video_time_seconds=68/24,
                   guide_lineage=dict(original_video=(p.SOURCE_DIR/'move_h3_v1/original_lossless.mkv').relative_to(p.ROOT).as_posix(),
                                      original_sha256=p.sha(p.SOURCE_DIR/'move_h3_v1/original_lossless.mkv'),
                                      matte_sha256=p.sha(passing_path)))
    prepare('move_h3_v2', 'move_h3_v1', [ref(13),ref(2),passing],
            [[20,1],[40,0],[60,2],[80,0],[105,0]],
            'Perform ONE slow complete two-step walking-in-place cycle. First extend the FAR leg '
            'toward screen right with heel contact as in guide20, keeping the NEAR leg behind on its toe. '
            'Transfer weight onto the far foot, draw the legs into passing and settle into the planted '
            'double-support ready stance at40. Then the NEAR leg lifts through its bent-knee passing '
            'pose at60 while the far boot stays planted; continue the near boot forward toward screen '
            'right, extend its knee, place that heel down and load weight onto that near boot. '
            'The far leg travels back on its toe during this opposite near-foot step. Return through '
            'grounded double support by80 and settle to the initial ready stance. The two legs genuinely '
            'alternate forward heel contact and weight bearing. Do not repeat the same foot step. '
            'Keep pelvis centered and carry the full rigid pole in the unchanged two-hand diagonal grip. ',
            2026100100)
    prepare('attack_h3_v2', 'attack_h3_v1', [ref(13),ref(6),ref(5)],
            [[24,1],[48,2],[65,2],[88,1]],
            'Perform one controlled two-handed pole thrust without overhead rotation. From the diagonal '
            'ready carry, lower the silver hook slightly toward screen right while lifting only the rear '
            'butt to chest height, yielding the supplied horizontal preparation at24. Keep the silver '
            'hook at the screen-right shaft end throughout. Push the single continuous rigid shaft '
            'toward screen right with both hands, forward left elbow extending and rear right hand '
            'driving, to the supplied full thrust at48. Briefly brace at65, then retract both arms to '
            'the horizontal recovery at88, shift weight back and return to diagonal ready. No overhead '
            'swing, pole inversion, hand release, spin, weapon bending, flash, projectile or extra tip. ',
            2026100101)
