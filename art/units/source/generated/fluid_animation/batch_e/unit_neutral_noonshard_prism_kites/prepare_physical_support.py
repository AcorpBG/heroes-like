"""Condition unsampled support/guard/collapse on literal original anatomy."""
import json
import produce as p

IDENTITY = ('The exact original four-winged white-opal jewel creature in the '
            'supplied reference images, facing screen right in its original '
            'three-quarter side view. Exactly four attached glass wings with '
            'original gold framing and curved veins, two small gold taloned '
            'legs, and two white tail ribbons ending in prism-leaf fins. '
            'Keep the original swept golden crest, long white-and-gold beak, '
            'glass colours and anatomical proportions. ')
PLATE = ('The space outside the complete creature silhouette stays uniform '
         'dark navy RGB16,32,64. Fixed camera and original anatomical scale. '
         'All four wing tips, both tails and both legs remain comfortably '
         'inside the image. ')

if __name__ == '__main__':
    recipes = {
        'defend_h3_v1': (
            'One continuous protective fold: the four glass wings hinge '
            'inward into the compact supplied posture around the chest. '
            'The head bows slightly with beak shut, and the two gold talons '
            'curl beneath the body. Both original tail ribbons settle into '
            'their natural curls. Finish holding the supplied folded posture '
            'while keeping the original airborne clearance above plane y640. ',
            [[24, 1], [52, 1], [80, 1], [104, 1]]),
        'cast_h3_v1': (
            'One calm physical gesture: dip the original head with beak '
            'shut, fan all four attached glass wings into the supplied '
            'lowered-wing pose, and gently flex both small gold talons. '
            'Then raise the head, curl the talons under the chest, and '
            'restore the initial quiet hovering posture. Both tail ribbons '
            'sway slightly then settle. Retain original airborne clearance '
            'above plane y640. ',
            [[18, 0], [34, 1], [50, 1], [66, 1], [86, 0], [106, 0]]),
        'death_h3_v1': (
            'One continuous loss of lift and grounded collapse: the four '
            'original glass wings fold and droop as the torso descends; '
            'the two gold talons reach toward plane y640. The original '
            'body settles onto its side with all four wings and both tails '
            'folded into the supplied final resting pose. Keep original '
            'body size throughout the descent. The final body rests at '
            'plane y640 and remains still in that supplied resting pose '
            'for the final second. ',
            [[38, 1], [72, 2], [98, 3]])
    }
    for take, (action, guides) in recipes.items():
        out = p.SOURCE_DIR / take
        assert not (out / 'sampling_submission.json').exists(), take
        assert not (out / 'submission.json').exists(), take
        config = json.loads((out / 'config.json').read_bytes())
        original = out / 'initial_unsampled_config.json'
        if not original.exists():
            p.write(original, config)
        config['prompt'] = (IDENTITY + action + PLATE).strip()
        config['guides'] = guides
        p.write(out / 'config.json', config)
        p.prepare(out, config)
        p.verify(out, config)
        print('Prepared literal original-anatomy conditioning:', take, flush=True)
