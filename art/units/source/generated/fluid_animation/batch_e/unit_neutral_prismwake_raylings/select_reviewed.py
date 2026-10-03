"""Manually reviewed chronological original selections; runtime review required."""
import argparse
import json
import produce as p


def select(take, indices, note, contact=None):
    assert indices == sorted(set(indices))
    spec = dict(source_frames=indices, frame_msec=42, review_note=note)
    if contact is not None:
        spec['contact_frame'] = indices.index(contact)
    out = p.SOURCE_DIR / take
    p.write(out / 'selection.json', spec)
    p.build(out, json.loads((out / 'config.json').read_bytes()))
    print(take, len(indices), flush=True)


def flight():
    select('move_h3_v2', list(range(20, 115)),
           'All124 original RGB and alpha frames in both facings personally inspected, plus8 full-original-scale RGB and alpha details each facing. Continuous two-fin rise, complete downstroke and recovery keep the blue eye, single full beak, filigree and3 attached leaf-tip tendrils. The near fin briefly occludes one tail end at68; the original stem/end remain present. Retain every original transition20-114. Loop endpoints share the relaxed upstroke phase; actual Godot loop/action review pending. No reversed, duplicated, interpolated or normalized frames.')


def jab():
    indices = (list(range(0, 17)) + [20, 24, 28, 32, 36, 40, 43]
               + list(range(44, 81)) + [84, 88, 92, 96, 100, 104, 107]
               + list(range(108, 115)))
    select('attack_h3_v2', indices,
           'All124 original RGB and alpha frames in both facings personally inspected, plus8 full-original-scale RGB and alpha details each facing. One fin anticipation folds into the swept-fin windup, followed by one physical beak jab and coherent ready recovery. All3 attached tail leaf ends and the single blue eye/full beak remain present. Retain all physical transitions0-16,44-80,108-114; sustained windup and raised-fin recovery holds use chronological original samples. The one initial fin raise is anticipation, rather than the repeated flight cycles in rejected v1. Contact is the first full horizontal jab48, established by original-scale44-51 transition review. Actual Godot contact, timing and entry review pending. No reversed, duplicated, interpolated or normalized frames.', 48)


def recoil():
    indices = list(range(24, 39)) + [44, 52, 60, 63] + list(range(64, 83))
    select('hit_h3_v2', indices,
           'All124 original RGB and alpha frames in both facings personally inspected, plus8 full-original-scale RGB and alpha details each facing. One rapid recoil raises the single complete beak, folds the fins back and returns coherently to ready. Three attached leaf-tip tendrils remain present. The short backward gold chin flange is attached filigree, not a second long beak. Retain the complete impact24-38 and recovery64-82; sustained head-up hold uses chronological original samples. Actual Godot timing and entry review pending. No reversed, duplicated, interpolated or normalized frames.')


def guard():
    indices = list(range(7, 38)) + [44, 58, 76, 94, 110, 123]
    select('defend_h3_v2', indices,
           'All124 original RGB and alpha frames in both facings personally inspected, plus8 full-original-scale RGB and alpha details each facing. One fin anticipation becomes a continuous two-fin inward fold, ending in a held protective brace. Full single beak, blue eye and three attached tail paddles remain intact. The gold point beside the face belongs to the folded far fin. All folding transitions7-37 retained; stable brace uses chronological original samples and ends at the original123 static pose. Actual Godot entry and final guard review pending. No reversed, duplicated, interpolated or normalized frames.')


def salute():
    indices = (list(range(24, 36)) + [40, 48, 56, 64, 68]
               + list(range(69, 82)) + [85, 90, 94] + list(range(95, 101)))
    select('cast_h3_v2', indices,
           'All124 original RGB and alpha frames in both facings personally inspected, plus10 full-original-scale RGB and alpha details each facing. Physical support flare, held display, bow with continuous two-fin rotation, then gradual94-97 ready recovery. One unchanged blue eye, one complete beak and three attached leaf-tail paddles; thin near-fin orientation71-72 is present in the original and retained by alpha. Retain every moving transition24-35,69-81,95-100; shorten only observed sustained flare and bowed display holds with chronological original samples. Actual Godot gesture/entry review pending. No reversed, duplicated, interpolated or normalized frames.')


def lens_release():
    select('ranged_h3_v2', list(range(15, 79)),
           'All124 original RGB and alpha frames in both facings personally inspected, plus10 full-original-scale RGB and alpha details each facing. One preparatory fin stroke curls the three attached tendrils behind the near fin23-32, then a raised V charge focuses the single original eye and the fins open into the lens release before ready recovery. Enlarged23/26/28/30/31/32 retains attached curled stems and partial paddle occlusion; all three distinct paddles uncoil by36 and remain throughout release/recovery. Eye brightening stays inside its original rim, full attached beak and legitimate pink tip retained, no baked projectile. Retain all consecutive motion15-78. Contact45 is the broad downward release fan following the raised charge36, established by original-scale36/42/45 review. Actual Godot Shoot timing and pose observation pending. No reversed, duplicated, interpolated or normalized frames.', 45)


def collapse():
    indices = list(range(58, 101)) + [108, 116, 123]
    select('death_h3_v2', indices,
           'All124 original RGB and alpha frames in both facings personally inspected, plus18 full-original-scale RGB and alpha details each facing. Gradual loss of hover and downward body pitch lead to a fast two-frame fin fold on ground contact76-77; the single eye dims inside its original rim. Full single beak, attached gold framework and both folded membranes remain intact. Two tail tips overlap77-80, then all three attached leaf ends separate by84 during settling. Preserve every original descent/landing/settling frame58-100; sample only the sustained final rest108/116/123, with original123 held as the corpse. Actual Godot entry/ground placement/timing review pending. No reversed, duplicated, interpolated or normalized frames.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('actions', nargs='+', choices=['move', 'attack', 'hit', 'defend', 'cast', 'ranged', 'death'])
    args = parser.parse_args()
    for action in args.actions:
        {'move': flight, 'attack': jab, 'hit': recoil, 'defend': guard,
         'cast': salute, 'ranged': lens_release, 'death': collapse}[action]()
