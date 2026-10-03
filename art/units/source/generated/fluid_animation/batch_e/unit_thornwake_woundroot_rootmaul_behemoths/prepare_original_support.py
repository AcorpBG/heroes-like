"""Reassess two failed support sources; use the original four-limb arm display."""
import json,shutil
import produce as p

if __name__=='__main__':
    repaired=p.SOURCE_DIR/'support_near_claw_v2.png'
    source=p.ROOT.__class__('C:/Users/acorp/.codex/generated_images/01a0fd50-f23a-7d32-8303-80fafa7a2272/exec-4cc354bd-9dde-4fc0-97a7-7da8b848c3f9.png')
    assert not repaired.exists();shutil.copyfile(source,repaired)
    prompt=p.SOURCE_DIR/'support_near_claw_v2.prompt.txt';reference=p.SOURCE_DIR/'cast_h3_v3/guide_0_rgba.png'
    record=lambda path:dict(path=path.relative_to(p.ROOT).as_posix(),sha256=p.sha(path))
    p.write(p.SOURCE_DIR/'support_near_claw_v2.generation.json',dict(image=record(repaired),prompt=record(prompt),references=[record(reference)],tool_output=str(source).replace('\\','/'),review='Rejected conditioning painting. Added colored halo, partly transparent foreground and missing exposed far rear root foot. Preserve original; not used in H3 conditioning.'))
    old=p.SOURCE_DIR/'cast_h3_v3';out=p.SOURCE_DIR/'cast_h3_v4'
    p.write(old/'rejection.json',dict(status='rejected_source',original_rgb_frames_reviewed=124,matte_frames_reviewed=124,enlarged_matched_phase_indices=[0,24,36,48,60,80,96,112,123],representative_native_frame_indices=list(range(96,112)),native_facings_reviewed=['normal','reflected'],reason='Source changes backdrop to cyan, green and yellow; connected leaf, crown, tail and claw edges remain purple. Full hand flex/recovery cannot qualify. No connected subject recoloring or masking.',all_originals_and_recipes_preserved=True,continuous_video_playback=False))
    assert not out.exists();out.mkdir()
    c=json.loads((old/'config.json').read_bytes());original=json.loads((p.SOURCE_DIR/'attack_h3_v1/config.json').read_bytes())
    c['references']=[original['references'][0],dict(original['references'][1],name='original_two_arm_display')]
    c['guides']=[[48,1]];c['last']=0;c['seed']=2026120405
    c['prompt']=('One original Rootmaul Behemoth makes one quiet physical arm gesture in the fixed tactical camera. Exactly two front root arms with three stone claws each and two rear root legs. '
                 'Starting in supplied ready, draw both front elbows up and inward, displaying both heavy clawed hands in front of the chest as in the supplied original raised-arm painting. '
                 'Both rear root feet support the same creature beneath its leafy mantle. Pause briefly with both hands raised, then smoothly extend the elbows and lower both hands into the identical supplied ready. '
                 'Its forked crown, gray-green stone shoulder plates, brown bark, green moss, orange leaves, curled tail and painted amber insets stay attached and retain the supplied colors and anatomical proportions. '
                 'One arm display and complete recovery. The entire empty backdrop stays uniformly magenta from the first frame through the last frame. Fixed original camera, lighting, scale and root support plane.')
    p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
    measurement=json.loads((p.SOURCE_DIR/'attack_h3_v1/foreground_measurement.json').read_bytes())
    measurement['guides']=measurement['guides'][:2]
    for guide in measurement['guides']:
        guide['path']=guide['path'].replace('attack_h3_v1',out.name);assert p.sha(p.ROOT/guide['path'])==guide['sha256']
    p.write(out/'foreground_measurement.json',measurement)
    node=p.ROOT.__class__('H:/ai/minimax-h3/ComfyUI/comfy_extras/nodes_minimax_h3.py')
    p.write(out/'correction.json',dict(prior_take=old.name,prior_rejection_sha256=p.sha(old/'rejection.json'),reassessed_installed_node_sha256=p.sha(node),reassessment='ImageToVideo first/last and AddGuide image latents are re-injected each step. AddGuide exposes frame index but no guide-strength parameter. Prior single-arm painting extends rear knees against the fixed-torso instruction; targeted edit introduced a halo and missing foot. Use the original four-limb raised-two-arm painting with a dedicated physical display/recovery and no melee contact guide.',change='Original ready/raised-arm/ready controls and new physical two-arm description, new seed. No model,20-step sampler, canvas, original anatomical scale, ground anchor or matte change. Rejected original sources and guide retained.'))
    delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());delivery['takes']=[x.replace('cast_h3_v3','cast_h3_v4') for x in delivery['takes']];delivery['failed_takes'].append('cast_h3_v3');p.write(p.SOURCE_DIR/'delivery.json',delivery)
    print('Reassessed original two-arm support prepared and verified, unsubmitted.',flush=True)
