"""Select observed action intervals; acceptance follows native-scale review."""
import json
import produce as p

def choose(take,indices,msec,note,contact=None):
    out=p.SOURCE_DIR/take
    selection=dict(source_frames=indices,frame_msec=msec,review_note=note,
        retiming_reason='Original observed frames and 24fps timestamps retained. '
                        'Shortened stationary holds join matching physical poses; '
                        'no interpolation, reversed motion or per-frame normalization.')
    if contact is not None:selection['contact_frame']=contact
    p.write(out/'selection.json',selection)
    p.build(out,json.loads((out/'config.json').read_bytes()))

if __name__=='__main__':
    choose('move_h3_v1',list(range(20,70)),33,
        'One full reciprocal cycle with both contact/loading/passing/extension phases. '
        'Right spear hand and left shield arm remain attached. Matching extended '
        'near-foot contact at loop boundary; later repeated cycle excluded. '
        'Legacy magenta fringe removed using the clean ready foreground palette.')
    choose('attack_h3_v1',list(range(15,50))+list(range(69,82)),33,
        'Full right-shoulder windup, rapid wrist/shoulder rotation and forward spear '
        'extension. Blade turns edge-on at38-41 then presents its original curved '
        'profile and aperture at44. Full shaft, right grip and left shield retained. '
        'Matching extended hold49-69 shortened; continuous recovery retained.',29)
    choose('defend_h3_v1',list(range(12,41)),42,
        'Right spear arm makes a preparatory parry adjustment while knees bend and '
        'left shield braces before torso. The planted terminal guard is held.')
    choose('hit_h3_v2',list(range(22,56)),33,
        'Continuous backward torso recoil and supported knee bend, then recovery. '
        'Both original grips, shield and full spear retained; rejected v1 streaks '
        'and detached flakes are absent from this corrected original.')
    choose('cast_h3_v2',list(range(26,46))+list(range(72,89)),42,
        'Quiet physical support salute. Right elbow rotates and raises the full '
        'spear above the right shoulder; left arm retains shield. Matching raised '
        'hold45-72 shortened; the whole lowering and recovery interval retained. '
        'No flare, spell, added illumination or weapon throw.',12)
    choose('death_h3_v2',list(range(19,67)),33,
        'Entire observed descent, kneeling loss of support, side roll and limb '
        'settling retained. Antlered head ends left, boots right, original spear '
        'horizontal before corpse and shield resting on torso/ground. Persistent '
        'terminal corpse is fully grounded. No collapse interval omitted.')
    p.assemble()
    print('Assembled six actions:246 new original poses; eight reviewed idle poses retained.')
