"""Preserve a new closed-mouth claw-contact painting and original H3 rejection."""
import json, shutil
from pathlib import Path
import produce as p
from prepare import IDENTITY, PLATE, reference

GENERATED=Path('C:/Users/acorp/.codex/generated_images/01a0965d-a98e-7560-8e9d-802269b3760b/exec-11256a3f-1d81-4fd1-9adb-1d40e52fbffe.png')
PROMPT='Create ONE transparent-background animation keypose of this exact original creature, keeping its painted fantasy sprite style, original opal-glass and gold materials, right-facing three-quarter side camera and airborne posture. This is the physical melee contact pose. Its mouth is firmly CLOSED with the exact original long white-and-gold snout, no breath or magic. The small gold taloned leg on the near side extends forward toward screen right for one claw slash; the far-side gold leg remains tucked underneath the chest. Exactly TWO small gold taloned legs, FOUR original attached glass wings (two on each side), and TWO white trailing tail ribbons with prism-leaf ends. Preserve the four-wing proportions, gold veinwork, swept gold head crest and recognizable original face. Slight forward neck/chest reach only; wings brace naturally, all appendages entirely visible. No additional arms, fingers, legs, wings, weapons, particles, light rays, projectiles, mouth glow, smoke, speed lines or shadows. One creature only, centered with ample transparent margin; a single animation keypose, not a sheet.'

if __name__=='__main__':
    master=p.SOURCE_DIR/'claw_contact_original.png'
    if not master.exists():shutil.copy2(GENERATED,master)
    assert p.sha(master)=='bd60af9f056f0ee93f26fb09b23dae7e5092e24339b5e2ffbc79ef8cef54df95'
    prompt=p.SOURCE_DIR/'claw_contact_original.prompt.txt';prompt.write_text(PROMPT+'\n',encoding='utf-8')
    p.write(master.with_suffix('.generation.json'),dict(tool='builtin image_gen.imagegen',transparent_background=True,image=dict(path=master.relative_to(p.ROOT).as_posix(),sha256=p.sha(master)),prompt=dict(path=prompt.relative_to(p.ROOT).as_posix(),sha256=p.sha(prompt)),references=[dict(path=(p.SOURCE_DIR/'move_h3_v1/guide_0_rgba.png').relative_to(p.ROOT).as_posix(),sha256=p.sha(p.SOURCE_DIR/'move_h3_v1/guide_0_rgba.png'))],anatomical_registration=dict(painted_wing_root=[916,576],ready_wing_root=[586,421],guide_whole_source_scale=.49,output_scale=.5,guide_translation=[137,139],reason='One rigid original-painting scale and translation measured from the attached near wing root and long wing. No per-video-frame deformation or normalization.')))
    claw=dict(name='closed_mouth_near_claw_contact',source=master.relative_to(p.ROOT).as_posix(),rects=[[0,0,1465,1073]],anchor=[700,1022],scale=.245,alpha_noise_cutoff=8)
    out=p.SOURCE_DIR/'attack_h3_v2';out.mkdir(exist_ok=True)
    assert not (out/'sampling_submission.json').exists()
    action='One physical CLOSED-MOUTH claw slash. Keep the original beak firmly closed in every frame. Brace the original four wings, curl the two original gold talons, reach the near gold talon forward toward SCREEN RIGHT once in the supplied contact pose, then curl that same talon back underneath the chest and return to exact ready hover. The far gold leg stays tucked. The neck/head make only a slight closed-beak follow-through. No mouth opening or spitting; no breath, fan of shards, projectile, magic, dust or glow. One claw strike only, then recovery. '
    c=dict(unit_id=p.SOURCE_DIR.name,clip='attack',canvas=[960,704],anchor=[480,640],scale=.5,key_rgb=[16,32,64],seed=2026108312,references=[reference(16),claw],guides=[[54,1],[66,1]],last=0,prompt=IDENTITY+action+PLATE,tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
    c['prompt']=c['prompt'].strip()
    p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
    delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
    delivery['takes']=['attack_h3_v2' if t=='attack_h3_v1' else t for t in delivery['takes']]
    delivery['rejected_takes']=['attack_h3_v1']
    delivery['rejection_notes']=[dict(take='attack_h3_v1',reason='All124 original RGB frames personally reviewed chronologically. Repeated magical breath/projectile fans at24-30 and56-61 contradict the physical-melee action. Reject entire take; preserve unmodified original RGB, latent, guides, prompts and provenance. No masking away connected effects.',reviewed_original_frames=124)]
    p.write(p.SOURCE_DIR/'delivery.json',delivery)
    print('Prepared closed-mouth claw strike v2; rejected physical-melee v1 preserved.',flush=True)
