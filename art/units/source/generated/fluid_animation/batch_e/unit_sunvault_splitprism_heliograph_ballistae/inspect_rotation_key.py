"""Preserve the original wheel-phase key and inspect native identity/edges."""
import shutil
import numpy as np
from PIL import Image,ImageDraw
import produce as p


def main():
    S=p.SOURCE_DIR
    folder=S/'rolling_rotation_key_v2';folder.mkdir(exist_ok=True)
    original=p.Path('C:/Users/acorp/.codex/generated_images/01a0965d-a98e-7560-8e9d-802269b3760b/exec-5ac66c49-8845-4a61-b08d-219f57b4a055.png')
    file=folder/'original.png'
    if not file.exists():shutil.copyfile(original,file)
    assert p.sha(file)==p.sha(original)
    shutil.copyfile(S/'rolling_rotation_key_v2.prompt.txt',folder/'prompt.txt')
    ref=S/'move_h3_v2/guide_0_rgba.png'
    p.write(folder/'generation.json',dict(tool='built-in image_gen.imagegen',original_tool_path=str(original),original_sha256=p.sha(file),prompt_path=(folder/'prompt.txt').relative_to(p.ROOT).as_posix(),prompt_sha256=p.sha(folder/'prompt.txt'),referenced_image_paths=[str(ref)],references=[dict(source=ref.relative_to(p.ROOT).as_posix(),sha256=p.sha(ref))],transparent_background=True))
    im=Image.open(file).convert('RGBA');rgb=np.asarray(im)
    red=(rgb[:,:,0]>180)&(rgb[:,:,1]<90)&(rgb[:,:,2]<90)
    print('Original size',im.size,'red opaque fringe counts',[(a,int((red&(rgb[:,:,3]>=a)).sum())) for a in [1,8,32,128,250]])
    frames=[dict(name='original rolling guide',source=ref.relative_to(p.ROOT).as_posix(),rects=[[0,0,960,704]],anchor=[480,576],scale=.45),dict(name='new wheel-phase key pending review',source=file.relative_to(p.ROOT).as_posix(),rects=[[0,0,*im.size]],anchor=[746,899],scale=.21)]
    target=p.ROOT/'.artifacts/heliograph_ballista_h3/rotation_key_review';target.mkdir(exist_ok=True)
    for reflected in [False,True]:
        sheet=Image.new('RGB',(960,680),(28,38,28));d=ImageDraw.Draw(sheet)
        for j,f in enumerate(frames):
            for native in [True,False]:
                x=j*480;y=0 if native else 340
                sheet.paste((219,212,197) if j else(28,38,28),(x,y,x+480,y+340))
                a=dict(f,scale=f['scale']*(.5 if native else 1))
                pose,(dx,dy)=p.source_pose(a,8)
                if reflected:pose=pose.transpose(Image.Transpose.FLIP_LEFT_RIGHT);dx=-dx-pose.width
                sheet.paste(pose,(x+240+dx,y+310+dy),pose);d.line((x+4,y+310,x+476,y+310),fill=(111,137,86));d.text((x+8,y+8),f['name']+('128' if native else'256'),fill=(154,114,67))
        sheet.save(target/f'native_reflected{int(reflected)}.png')
    p.write(folder/'reference.json',frames[1])
    p.write(folder/'visual_review.json',dict(status='rejected_key_pose',examined='Original full painting,128/256 scale both facings and exact original alpha/RGB fringe measurement.',defect='1843 red fringe pixels remain above alpha128 (1826 above250). They are painted opaque artifacts, not removable alpha noise. Native size is comparable, but this new key is unsuitable as clean original rotation control.',reassessment='Both transparent key attempts introduce the same opaque colored edge problem. Next correction uses the original opaque Comfy guide canvas and asks for a wheel-only edit with its uniform background/margins retained, avoiding transparent-image generation. No RGB channel deletion or increased alpha cutoff.'))
    print('KEY_POSE_NATIVE_REVIEW_PENDING',flush=True)


if __name__=='__main__':main()
