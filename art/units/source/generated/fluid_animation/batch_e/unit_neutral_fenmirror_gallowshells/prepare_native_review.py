"""Adapt the existing focused observer to this six-action melee-only unit."""
from pathlib import Path
import produce as p

if __name__=='__main__':
    old=p.ROOT/'art/units/source/generated/fluid_animation/batch_e/unit_neutral_cindervane_censerwings'
    for name in ['capture_clock.py','run_native_review.py','run_mirrored_native.py']:
        text=(old/name).read_text(encoding='utf-8')
        text=text.replace('unit_neutral_cindervane_censerwings',p.SOURCE_DIR.name)
        text=text.replace('Censerwing\'s physical beak strike','Gallowshell\'s physical pincer strike')
        text=text.replace('all four wings and the attached ember tail','both articulated pincers and the carapace arch')
        text=text.replace('preserved wing/head/tail idle','preserved pincer/carapace idle')
        target=p.SOURCE_DIR/name
        if target.exists():assert target.read_text(encoding='utf-8')==text
        else:target.write_text(text,encoding='utf-8')
    print('NATIVE AND REFLECTED OBSERVERS PREPARED; NO RUNTIME ACCEPTANCE YET')
