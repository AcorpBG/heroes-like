"""Fix the unsubmitted death endpoint with a genuinely grounded original pose."""
import json
import shutil
from pathlib import Path
from PIL import Image
import produce as p

GEN=Path("C:/Users/acorp/.codex/generated_images/01a0965d-a98e-7560-8e9d-802269b3760b/exec-9d3c4dc0-d580-4142-baaf-0948f4265fb3.png")
MASTER_SHA="1d08aa475fd3cf86bda3c2e705e0bf8926016d17856a292c82600f5f497660a4"
PROMPT="Use case: precise-object-edit. Asset: a single grounded final corpse key pose for an original fantasy strategy-game bird. Input image is the edit target: preserve this exact Cindervane Censerwing bird identity, right-facing orthographic three-quarter side camera, crisp painterly raster sprite style, feather texture and palette. Correct only the fallen pose: the exhausted bird lies genuinely resting on its SIDE, original breast and folded lower feathers supported on one horizontal invisible ground contact plane. Original attached brass cylindrical chest censer rests with the breast, not airborne. Fold the FOUR original feather wings alongside the body; two larger upper and two smaller lower wings may naturally overlap/occlude. Exactly TWO dark thin legs and red hooked talons lie relaxed beside/below the body, visibly attached. Preserve narrow curved red beak, white sinuous throat, same curled crest and attached red/charcoal ember feather tail, ivory feather stripes and amber oval markings, identical proportions. Lower and relax head/neck so head/beak rests naturally near the same contact plane as the breast/feathered body, not a dangling beak below a floating body. Tail rests naturally alongside the body. Keep entire bird crest/beak/tail/talons comfortably inside the canvas. Single full-body side-resting original bird on actual transparent background, remove cyan plate. No drawn ground, cast shadow, environment, extra bird, extra limbs, detached fire, effects, particles, weapon, text or sprite sheet. One grounded corpse pose only, same side camera, do not rotate to a frontal view or change the creature."

def main():
    out=p.SOURCE_DIR/"death_h3_v1"
    assert not (out/"sampling_submission.json").exists() and not (out/"submission.json").exists(), "Submitted original is immutable"
    masters=p.SOURCE_DIR/"grounded_corpse_guide"; masters.mkdir(exist_ok=True)
    for name in ["config.json","reference.json","guide_3_rgba.png","guide_3_chroma.png","prompt.txt"]:
        target=masters/("previous_"+name)
        if not target.exists(): shutil.copy2(out/name,target)
    master=masters/"corpse_original.png"
    if not master.exists():
        assert GEN.is_file() and p.sha(GEN)==MASTER_SHA, "Original import source is unavailable"
        shutil.copy2(GEN,master)
    assert p.sha(master)==MASTER_SHA, "Never replace the preserved original"
    im=Image.open(master); assert im.mode=="RGBA" and im.size==(1465,1073)
    assert im.getchannel("A").getextrema()[0]==0
    prompt_file=masters/"prompt.txt"; prompt_file.write_text(PROMPT+"\n",encoding="utf-8")
    ref=dict(name="original_grounded_side_resting_censerwing",source=master.relative_to(p.ROOT).as_posix(),
        rects=[[0,0,im.width,im.height]],anchor=[826,875],scale=.2,alpha_noise_cutoff=8)
    p.write(masters/"registration.json",dict(source_frame=ref,uniform_video_scale=.4,
        measured_opaque_bounds=[176,533,1312,875],registered_video_ground_y=640,
        measured_original_video_horizontal_extent=[220,681],
        registered_new_video_horizontal_extent=[220,675],
        rule="One fixed whole-reference anatomical scale .4 preserves original collar/body width. Original alpha and all body pixels retained. Source anatomical rest contact y875 maps to logical video ground640. No per-video-frame normalization, morphology or synthetic motion.",
        visual_review="Personally inspected full original corpse: attached original breast censer, close layered wings, two relaxed attached legs/talons and original neck/beak/tail. Body is side-resting rather than suspended; final Godot proof pending."))
    p.write(masters/"generation.json",dict(tool="builtin_imagegen",prompt=PROMPT,
        source_sha256=p.sha(master),actual_mode=im.mode,actual_size=list(im.size),original_alpha_retained=True,
        edit_target=(masters/"previous_guide_3_chroma.png").relative_to(p.ROOT).as_posix(),
        edit_target_sha256=p.sha(masters/"previous_guide_3_chroma.png"),transparent_background_requested=True))
    paths=[masters/"previous_guide_3_chroma.png",masters/"generation.json",masters/"registration.json"]
    p.write(master.with_suffix(".generation.json"),dict(tool="builtin_imagegen",
        image=dict(path=master.relative_to(p.ROOT).as_posix(),sha256=p.sha(master)),
        prompt=dict(path=prompt_file.relative_to(p.ROOT).as_posix(),sha256=p.sha(prompt_file)),
        references=[dict(path=f.relative_to(p.ROOT).as_posix(),sha256=p.sha(f)) for f in paths]))
    c=json.loads((out/"config.json").read_bytes()); c["references"][3]=ref
    original=json.loads((masters/"previous_config.json").read_bytes())
    c["prompt"]=(original["prompt"]+" Final body, breast, folded lower feathers and attached censer settle onto the same ground contact plane as the relaxed talons, head and beak, matching the supplied grounded side-resting endpoint. No suspended breast or dangling airborne corpse.").strip()
    p.write(out/"config.json",c); p.prepare(out,c); p.verify(out,c)
    d=json.loads((p.SOURCE_DIR/"delivery.json").read_bytes())
    d["visual_review"].setdefault("guide_corrections",{})["death_h3_v1"]=dict(
        reason="Old original endpoint has suspended breast/tail and a beak hanging below the body, with lowest ink22 video pixels above ground640. Corrected before any source submission.",
        source=master.relative_to(p.ROOT).as_posix(),sha256=p.sha(master),
        method="Builtin imagegen original-pose correction, uniform reference scale and anatomical rest anchor; video sources remain untouched.",native_Godot_review="pending")
    p.write(p.SOURCE_DIR/"delivery.json",d)
    print("PREPARED_GROUNDED_DEATH_ENDPOINT",Image.open(out/"guide_3_rgba.png").getbbox(),flush=True)

if __name__=="__main__":main()
