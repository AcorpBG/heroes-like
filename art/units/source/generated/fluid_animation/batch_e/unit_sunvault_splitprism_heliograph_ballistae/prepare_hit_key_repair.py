"""Preserve targeted original edge repair and prepare one physical jolt."""
import copy
import json
import shutil
from PIL import Image
import produce as p


def main():
    S=p.SOURCE_DIR
    folder=S/'rolling_rotation_key_v4';folder.mkdir(exist_ok=True)
    original=p.Path('C:/Users/acorp/.codex/generated_images/01a0965d-a98e-7560-8e9d-802269b3760b/exec-f068cbd6-1559-4361-8d71-5766846670aa.png')
    file=folder/'original.png'
    if not file.exists():shutil.copyfile(original,file)
    assert p.sha(file)==p.sha(original)
    shutil.copyfile(S/'rolling_rotation_key_v4.prompt.txt',folder/'prompt.txt')
    ref=S/'rolling_rotation_key_v2/original.png'
    p.write(folder/'generation.json',dict(tool='built-in image_gen.imagegen',original_tool_path=str(original),original_sha256=p.sha(file),prompt_path=(folder/'prompt.txt').relative_to(p.ROOT).as_posix(),prompt_sha256=p.sha(folder/'prompt.txt'),references=[dict(source=ref.relative_to(p.ROOT).as_posix(),sha256=p.sha(ref))],transparent_background=False,original_size=list(Image.open(file).size)))
    p.write(folder/'reference.json',dict(name='repaired original alternate wheel phase',source=file.relative_to(p.ROOT).as_posix(),rects=[[0,0,*Image.open(file).size]],anchor=[746,899],scale=.21,review='Full original RGB identity/spoke phase inspected. Semantic matte and native registration/edge review pending; not yet used for H3.'))
    p.write(S/'rolling_rotation_key_v3/visual_review.json',dict(status='rejected_key_pose',examined='Full original painting compared with prior wheel-phase key.',defect='Clean edges but wheel spoke orientation again resembles the original movement guide, rather than a clear half-spoke phase. It provides insufficient new rolling control.',reassessment='Repair colored edges on v2 while explicitly preserving its already different spoke orientation. Do not repeat wheel-only rotation on the original guide.'))
    c=copy.deepcopy(json.loads((S/'hit_h3_v1/config.json').read_bytes()))
    identity=c['prompt'].split('Use the same flat pale blue-gray background')[0]
    c.update(seed=2026100384,guides=[[40,1]],prompt=identity+'Use the same flat pale blue-gray background over the entire image in every frame. Animate exactly one brief rearward mechanical jolt and recovery. The single operator bends elbows and knees while leaning backward, then restores his original two-handed crank grip and upright stance. The original lens mount tilts slightly backward with him and smoothly returns. All three gold star feet remain planted; the two wheels remain still. Both solid crystalline rods, including their blue and amber triangular ends, stay attached and INERT throughout. Nothing launches, fires, shines, explodes or leaves this carriage. The empty background stays entirely empty. One physical backward jolt followed by return to the original ready pose; no repeated action or whole-carriage rotation.',correction_of='hit_h3_v1',visual_review='pending_original_source; exact original guide bytes retained',selection='not_selected')
    target=S/'hit_h3_v2';target.mkdir(exist_ok=True)
    assert not (target/'sampling_submission.json').exists()
    p.write(target/'config.json',c);p.prepare(target,c);p.verify(target,c)
    for i in range(len(c['references'])):
        assert p.sha(target/f'guide_{i}_chroma.png')==p.sha(S/'hit_h3_v1'/f'guide_{i}_chroma.png')
    print('WHEEL_V4_ORIGINAL_PRESERVED_MATTE_PENDING; HIT_V2_PREPARED_UNSUBMITTED',flush=True)


if __name__=='__main__':main()
