"""Record completed personal live review and refresh exact source provenance."""
import copy,json,re
import produce as p
import build_delivery
from creature_animation_lock import exclusive

OUT=p.ROOT/'.artifacts/parallel_animation_20261003'/p.SOURCE_DIR.name

if __name__=='__main__':
    reports=re.findall(r'FLUID_ANIMATION_REPORT (\{[^\n]+\})',(OUT/'live_native/console.log').read_text())
    assert len(reports)==1 and json.loads(reports[0])==dict(checks=716,failures=[])
    assert 'FENMIRROR_GALLOWSHELL_IMPORTED_ATLAS_OK' in (OUT/'imported_pixels.log').read_text()
    assert len(list((OUT/'live_native').glob('battle-phase-*.png')))==8
    assert len(list((OUT/'live_native').glob('*-map-preserved-phase-*.png')))==8
    data=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
    data['final_live_visual_review']=dict(status='accepted',native_original_poses_personally_reviewed=212,
        overworld_shader_idle_phases_personally_reviewed=8,
        actual_normal_strike_captures_personally_reviewed=8,
        actual_reflected_strike_reviewed=False,continuous_video_playback=False,manual_game_session=False,
        notes='Personally reviewed every212 imported live native128px pose, all eight real Normal Strike captures including first closure and recovery, and all eight original shader/map-idle phases plus reduced-motion/static output. Six legs/two pincer arms and attached arch/rings remain coherent, fixed body scale, ground contacts and grounded persistent corpse. Full recovery returns to original ready. No alpha clipping/foreign pixels. Eight accepted original idle drawings and270ms timing preserved exactly. Focused live716 assertions pass; exact Godot-import RGBA equality confirmed; no full suite or Linux/manual/continuous-video claim.')
    p.write(p.SOURCE_DIR/'delivery.json',data)
    build_delivery.assemble()
    # Final review changes metadata, never selected pixels/anchors/ordering.
    # Keep published source digests current without repacking/importing artwork.
    with exclusive('content'):
        folder=p.ROOT/'art/animation/source/fluid'/p.SOURCE_DIR.name
        file=folder/'reviewed_handoff.json';reviewed=json.loads(file.read_bytes())
        current=reviewed['units'][0];new=json.loads((p.SOURCE_DIR/'handoff.json').read_bytes())['units'][0]
        for key in ['frames','clips','reference_height','source_facing']:
            assert current[key]==new[key],key
        current['provenance']=copy.deepcopy(new['provenance'])
        current['visual_review']=copy.deepcopy(new['visual_review'])
        current['final_live_visual_review']=copy.deepcopy(data['final_live_visual_review'])
        p.write(file,reviewed)
        file=folder/'provenance.json';provenance=json.loads(file.read_bytes())
        assert p.sha(p.ROOT/f'art/animation/runtime/fluid/{p.SOURCE_DIR.name}.png')==provenance['atlas_sha256']
        provenance['review']=copy.deepcopy(new['visual_review'])
        provenance['final_live_visual_review']=copy.deepcopy(data['final_live_visual_review'])
        p.write(file,provenance)
    print('Imported live native212, actual strike8 and actual map phases8 personally accepted; source provenance refreshed without artwork changes.')
