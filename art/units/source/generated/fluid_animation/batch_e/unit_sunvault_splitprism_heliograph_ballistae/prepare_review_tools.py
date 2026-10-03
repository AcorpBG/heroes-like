"""Reuse focused observers with this unit's identity and anatomical constants."""
import produce as p


def main():
    S = p.SOURCE_DIR
    fen = S.parent/'unit_neutral_fenmirror_gallowshells'
    hearth = S.parent/'unit_thornwake_woundroot_hearthseed_slingers'
    names = ['capture_clock.py', 'run_native_review.py', 'run_mirrored_native.py',
             'run_candidate_review.py', 'run_live_review.py', 'verify_imported_atlas.gd',
             'review_native_pages.py', 'verify_delivery.py']
    for name in names:
        text = (fen/name).read_text(encoding='utf-8')
        text = text.replace('unit_neutral_fenmirror_gallowshells', S.name)
        text = text.replace('FENMIRROR_GALLOWSHELL', 'HELIOGRAPH_BALLISTA')
        text = text.replace('Fenmirror Gallowshell', 'Heliograph Ballista')
        text = text.replace('fenmirror-import-', 'heliograph-import-')
        text = text.replace('Fenmirror texture import', 'Heliograph texture import')
        text = text.replace("Gallowshell's physical pincer strike", "Heliograph's physical counterthrust")
        text = text.replace('both articulated pincers and the carapace arch', 'both wheels, operator, lens and crystalline arms')
        text = text.replace('preserved pincer/carapace idle', 'preserved operator hand-crank idle')
        text = text.replace('pincer/leg', 'wheel/operator/launcher')
        if name == 'verify_delivery.py':
            text = text.replace("REQUIRED={'move','attack','hit','defend','cast','death'}", "REQUIRED={'move','attack','ranged','hit','defend','cast','death'}")
            text = text.replace("frame['scale']==.42 and frame['anchor']==[480,584]", "frame['scale']==.45 and frame['anchor']==[480,576]")
            text = text.replace("assert new.get('pose_aliases',{}).get('ranged')==old.get('pose_aliases',{}).get('ranged')", "assert 'ranged' not in new.get('pose_aliases',{})")
            text = text.replace('==270', '==240').replace('/270ms', '/240ms')
            text = text.replace('six published action', 'seven published action')
        target = S/name
        if target.exists():
            assert target.read_text(encoding='utf-8') == text
        else:
            target.write_text(text, encoding='utf-8')
    text = (hearth/'run_ranged_native.py').read_text(encoding='utf-8')
    text = text.replace('original sling windup/release/reload', 'original crank compression/recoil/recovery')
    text = text.replace('A 960px source canvas renders at .25 native scale.', 'A 960px source canvas renders at .225 native scale.')
    text = text.replace('asymmetric sling swing', 'solid crystalline arms and planted star feet')
    target = S/'run_ranged_native.py'
    if target.exists():
        assert target.read_text(encoding='utf-8') == text
    else:
        target.write_text(text, encoding='utf-8')
    print('Focused native/reflected, real Strike/Shoot, map/reduced-motion and exact import observers prepared; no runtime checks or acceptance claimed.')


if __name__ == '__main__':
    main()
