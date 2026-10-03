"""Preserve new original key-pose attempts and their exact tool inputs."""
import shutil
from PIL import Image
import produce as p


def main():
    S=p.SOURCE_DIR
    target=S/'rolling_rotation_keys_v1'
    target.mkdir(exist_ok=True)
    original=p.Path('C:/Users/acorp/.codex/generated_images/01a0965d-a98e-7560-8e9d-802269b3760b/exec-0ebadc61-9662-41e1-828f-6024db59a83a.png')
    image=target/'original.png'
    if not image.exists():shutil.copyfile(original,image)
    assert p.sha(image)==p.sha(original)
    shutil.copyfile(S/'rolling_rotation_keys_v1.prompt.txt',target/'prompt.txt')
    refs=[S/'move_h3_v2/guide_0_rgba.png',p.ROOT/'art/units/source/curated'/f'{S.name}.png']
    p.write(target/'generation.json',dict(tool='built-in image_gen.imagegen',original_tool_path=str(original),original_sha256=p.sha(image),prompt_path=(target/'prompt.txt').relative_to(p.ROOT).as_posix(),prompt_sha256=p.sha(target/'prompt.txt'),referenced_image_paths=[str(ref) for ref in refs],references=[dict(source=ref.relative_to(p.ROOT).as_posix(),sha256=p.sha(ref)) for ref in refs],transparent_background=True))
    with Image.open(image) as im:
        assert im.mode=='RGBA'
        p.write(target/'visual_review.json',dict(status='rejected_key_pose',examined='Full returned original2172x724 painting, paired wheel/equipment/alpha boundaries compared to original rolling guide.',defect='Multicolored red/yellow/cyan fringe appears along the mirror, chassis and rims; spoke-phase difference remains too ambiguous for a wheel-rotation control guide. Do not erase opaque artifacts with high alpha cutoff or feed these as accepted H3 guides.',alpha_range=list(im.getchannel('A').getextrema()),selected=[]))
    print('ORIGINAL_ROTATION_KEY_ATTEMPT_PRESERVED_REJECTED',flush=True)


if __name__=='__main__':main()
