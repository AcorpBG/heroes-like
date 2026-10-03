"""Register a new original small-recoil painting; retain every rejected source."""
import json
import shutil
from pathlib import Path
from PIL import Image
import prepare as prep
import produce as p

GEN=Path("C:/Users/acorp/.codex/generated_images/01a0965d-a98e-7560-8e9d-802269b3760b/exec-d058634c-6f72-4d17-b828-bc54342688f6.png")
MASTER_SHA="ce7d2c9a6162475e596bcee047dad399da6054306a577ba627831ec622ebb52b"
PROMPT="Use case: precise-object-edit. Asset: one corrected hit-recoil animation key pose for our original fantasy strategy game bird. Input image is the edit target and absolute identity/style/camera reference. Change only the bird's physical pose: a modest startled recoil, its sinuous neck bends back and head tucks slightly toward its shoulder, body leans back slightly, folded feather shoulders flinch close to the torso, both thin legs bend slightly and red hooked talons flex. Preserve exactly the original narrow curved red beak, white S-shaped throat, swept curling red crest, dark charcoal/red feathers with ivory stripes and amber oval markings, original cylindrical brass breast censer with the same glowing oval vents attached rigidly to the chest, same attached curled ember feather tail. Exactly TWO thin dark legs and red hooked feet; original FOUR wings (two major upper plus two smaller lower), naturally folded/layered with far wings occluded as in the reference. No oversized overhead wing spread. Keep the same orthographic three-quarter SIDE camera, bird facing SCREEN RIGHT, identical anatomy proportions, materials, painterly crisp raster sprite style, lighting and scale. Keep entire crest, curved beak, tail and talons inside frame, comparable placement with generous empty margin. Single full-body bird, actual transparent background; remove the flat cyan plate. No ground, shadow, environment, text, extra bird, effects, detached flame, projectile or added equipment. This is a small physical hit recoil, no yaw or front-facing rotation. Output one key pose, not a sheet."

def main():
    masters=p.SOURCE_DIR/"hit_guide_v2"; masters.mkdir(exist_ok=True)
    master=masters/"recoil_original.png"
    if not master.exists():
        assert GEN.is_file() and p.sha(GEN)==MASTER_SHA, "Original import source is unavailable"
        shutil.copy2(GEN,master)
    # Rebuild from the preserved repository master on either platform; the
    # original Windows image-tool save directory is only an initial locator.
    assert p.sha(master)==MASTER_SHA, "Never replace original painting"
    im=Image.open(master)
    assert im.mode=="RGBA" and im.getchannel("A").getextrema()[0]==0
    assert im.size==(1465,1073)
    p.write(masters/"generation.json",dict(tool="builtin_imagegen",prompt=PROMPT,
        source_master="recoil_original.png",source_sha256=p.sha(master),
        edit_target=(p.SOURCE_DIR/"hit_h3_v1/guide_0_chroma.png").relative_to(p.ROOT).as_posix(),
        edit_target_sha256=p.sha(p.SOURCE_DIR/"hit_h3_v1/guide_0_chroma.png"),
        transparent_background_requested=True,actual_mode=im.mode,actual_size=list(im.size),
        original_alpha_retained=True,visual_review="Personally inspected complete original identity, two legs, folded near/far feather wings, same attached brass chest censer and curled tail. Head and shoulders recoil modestly without a full overhead fan."))
    ref=dict(name="original_corrected_small_hit_recoil",
        source=master.relative_to(p.ROOT).as_posix(),rects=[[0,0,im.width,im.height]],
        anchor=[737,894],scale=.275,alpha_noise_cutoff=8)
    p.write(masters/"registration.json",dict(source_frame=ref,
        measured_source_censer_center=[950,512],ready_video_censer_center=[597,430],
        uniform_video_scale=.55,
        rule="One fixed whole-reference uniform downsample based on original brass censer and anatomical size. Source anchor737,894 rigidly aligns censer center597,430. Original RGBA master is unmodified. Original low-alpha generation dust<=8 excluded only in reference sampling. No per-video-frame stabilization, scaling, morphology or invented articulation.",
        native_Godot_review="pending"))
    prompt_file=masters/"prompt.txt"
    prompt_file.write_text(PROMPT+"\n",encoding="utf-8")
    paths=[p.SOURCE_DIR/"hit_h3_v1/guide_0_chroma.png",masters/"generation.json",masters/"registration.json"]
    p.write(master.with_suffix(".generation.json"),dict(
        tool="builtin_imagegen",image=dict(path=master.relative_to(p.ROOT).as_posix(),sha256=p.sha(master)),
        prompt=dict(path=prompt_file.relative_to(p.ROOT).as_posix(),sha256=p.sha(prompt_file)),
        references=[dict(path=f.relative_to(p.ROOT).as_posix(),sha256=p.sha(f)) for f in paths]))
    out=p.SOURCE_DIR/"hit_h3_v2"; out.mkdir(exist_ok=True)
    assert not (out/"sampling_submission.json").exists(), "Submitted source is immutable"
    action=("One continuous modest physical startled recoil and recovery. "
            "The white neck curls backward and the head tucks slightly toward its shoulder, "
            "with close-folded feather shoulders flinching toward the body. The two thin legs "
            "bend slightly and both red talons flex. Move smoothly through the supplied "
            "small recoil pose and recover smoothly to the initial ready posture. "
            "Keep original feathers layered and folded close throughout this brief response; "
            "the brass breast censer remains the same attached rigid object. The only "
            "movement is continuous connected original bird anatomy. ")
    c=dict(unit_id=prep.UID,clip="hit",canvas=[960,704],anchor=[480,640],
        scale=.5,key_rgb=[0,255,255],seed=2026109404,
        references=[prep.reference(16),ref],guides=[[40,1]],last=0,
        prompt=(prep.IDENTITY+action+prep.PLATE).strip(),
        tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
    p.write(out/"config.json",c); p.prepare(out,c); p.verify(out,c)
    d=json.loads((p.SOURCE_DIR/"delivery.json").read_bytes())
    d["takes"]=["hit_h3_v2" if t=="hit_h3_v1" else t for t in d["takes"]]
    d.setdefault("rejections",{}).setdefault("hit_h3_v1",{})["correction"]="New original close-folded small recoil painting generated from accepted ready identity. Fixed uniform .55 reference scale, anatomically registered attached censer, single recoil40 control and matching ready endpoints. Removes incompatible legacy full-rotation/fan guide; all rejected original video/mattes preserved."
    if "source_review" in d:
        d["visual_review"].setdefault("source_review",{}).update(d.pop("source_review"))
    p.write(p.SOURCE_DIR/"delivery.json",d)
    print("PREPARED_HIT_V2",Image.open(out/"guide_1_rgba.png").getbbox(),flush=True)

if __name__=="__main__":main()
