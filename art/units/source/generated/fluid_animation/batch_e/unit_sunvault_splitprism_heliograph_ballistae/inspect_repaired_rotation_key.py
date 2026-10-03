"""Original wheel-phase key inspection at preserved128/256 anatomy scales."""
import json
from PIL import Image,ImageDraw
import produce as p


def main():
    S=p.SOURCE_DIR;folder=S/'rolling_rotation_key_v4'
    matte=json.loads((folder/'matte.json').read_bytes())
    assert p.sha(folder/'original.png')==matte['source_sha256']
    file=folder/'matte.png';assert p.sha(file)==matte['rgba_sha256']
    im=Image.open(file).convert('RGBA')
    frames=[dict(name='original rolling phase',source=(S/'move_h3_v2/guide_0_rgba.png').relative_to(p.ROOT).as_posix(),rects=[[0,0,960,704]],anchor=[480,576],scale=.45),dict(name='repaired alternate spoke phase',source=file.relative_to(p.ROOT).as_posix(),rects=[[0,0,*im.size]],anchor=[746,899],scale=.21)]
    target=p.ROOT/'.artifacts/heliograph_ballista_h3/rotation_key_v4_review';target.mkdir(exist_ok=True)
    for reflected in [False,True]:
        sheet=Image.new('RGB',(960,680),(28,38,28));draw=ImageDraw.Draw(sheet)
        for j,f in enumerate(frames):
            for native in [True,False]:
                x=j*480;y=0 if native else 340
                sheet.paste((219,212,197) if j else(28,38,28),(x,y,x+480,y+340))
                a=dict(f,scale=f['scale']*(.5 if native else 1))
                pose,(dx,dy)=p.source_pose(a,0)
                if reflected:pose=pose.transpose(Image.Transpose.FLIP_LEFT_RIGHT);dx=-dx-pose.width
                sheet.paste(pose,(x+240+dx,y+310+dy),pose)
                draw.line((x+4,y+310,x+476,y+310),fill=(111,137,86))
                draw.text((x+8,y+8),f['name']+('128' if native else'256'),fill=(154,114,67))
        sheet.save(target/f'native_reflected{int(reflected)}.png')
    p.write(folder/'matte_reference.json',frames[1])
    print('REPAIRED_WHEEL_KEY_NATIVE_COMPARISONS_READY_PENDING_PERSONAL_REVIEW',flush=True)


if __name__=='__main__':main()
