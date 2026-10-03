"""Full source chronology, enlarged alpha, and fixed native anatomical origin."""
import argparse, hashlib, json
from pathlib import Path
import av
import numpy as np
from PIL import Image,ImageDraw
import produce as p

def inspect(take,rgb_only=False):
    folder=p.SOURCE_DIR/take;c=json.loads((folder/'config.json').read_bytes());record=json.loads((folder/'original.json').read_bytes())
    assert p.sha(folder/'original_lossless.mkv')==record['sha256']
    target=p.ROOT/'.artifacts/fenmirror_gallowshell_h3'/take;target.mkdir(parents=True,exist_ok=True)
    frames=[]
    with av.open(str(folder/'original_lossless.mkv')) as video:
        for index,f in enumerate(video.decode(video=0)):
            rgb=f.to_image().convert('RGB');assert hashlib.sha256(rgb.tobytes()).hexdigest()==record['decoded_rgb_sha256'][index]
            frames.append(rgb)
    assert len(frames)==124
    for page in range(8):
        sheet=Image.new('RGB',(1536,1320),(26,34,28));d=ImageDraw.Draw(sheet)
        for j,index in enumerate(range(page*16,min(124,(page+1)*16))):
            x,y=j%4*384,j//4*330
            im=frames[index].resize((384,round(frames[index].height*384/frames[index].width)),Image.Resampling.LANCZOS)
            sheet.paste(im,(x,y+26));d.text((x+7,y+5),f'original RGB {index}, {index/24:.3f}s',fill=(206,196,160))
        sheet.save(target/f'original_rgb_{page:02}.png')
    if rgb_only:
        print('FULL124_ORIGINAL_RGB_REVIEW_READY',take,flush=True)
        return
    matte=json.loads((folder/'matte.json').read_bytes())
    rgba=[];border=[]
    for index in range(124):
        file=folder/'matte'/f'rgba_{index:03}.png';assert p.sha(file)==matte['rgba_sha256'][index]
        im=Image.open(file).convert('RGBA');assert im.size==frames[index].size
        a=np.asarray(im)[:,:,3]>=8;touch=int(a[0,:].sum()+a[-1,:].sum()+a[1:-1,0].sum()+a[1:-1,-1].sum())
        if touch:border.append(dict(frame=index,alpha8_border_pixels=touch))
        rgba.append(im)
    bounds=[im.getchannel('A').getbbox() for im in rgba];assert all(bounds)
    width,height=frames[0].size
    crop=(max(0,min(b[0] for b in bounds)-16),max(0,min(b[1] for b in bounds)-16),min(width,max(b[2] for b in bounds)+16),min(height,max(b[3] for b in bounds)+16))
    for page in range(8):
        sheet=Image.new('RGB',(1536,1760),(28,38,28));d=ImageDraw.Draw(sheet)
        for j,index in enumerate(range(page*16,min(124,(page+1)*16))):
            x,y=j%4*384,j//4*440
            if j%2:sheet.paste((219,212,197),(x,y,x+384,y+440))
            im=rgba[index].crop(crop);im.thumbnail((380,408),Image.Resampling.LANCZOS)
            sheet.paste(im,(x+(384-im.width)//2,y+26),im);d.text((x+7,y+5),f'original alpha {index}',fill=(154,114,67))
        sheet.save(target/f'enlarged_rgba_{page:02}.png')
    for reflected in [False,True]:
        for page in range(4):
            sheet=Image.new('RGB',(1760,960),(28,38,28));d=ImageDraw.Draw(sheet)
            for j,index in enumerate(range(page*32,min(124,(page+1)*32))):
                x,y=j%8*220,j//8*240
                if j%2:sheet.paste((219,212,197),(x,y,x+220,y+240))
                ref=dict(name=f'original{index}',source=(folder/'matte'/f'rgba_{index:03}.png').relative_to(p.ROOT).as_posix(),rects=[[0,0,width,height]],anchor=c['anchor'],scale=c['scale']*.5)
                im,(dx,dy)=p.source_pose(ref,0)
                if reflected:im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT);dx=-dx-im.width
                assert x<=x+110+dx and x+110+dx+im.width<=x+220,('Observer clipping',index,im.size,dx)
                assert y+30<=y+216+dy and y+216+dy+im.height<=y+240,('Observer vertical clipping',index,im.size,dy)
                sheet.paste(im,(x+110+dx,y+216+dy),im);d.line((x+3,y+216,x+217,y+216),fill=(111,137,86));d.text((x+5,y+4),str(index),fill=(154,114,67))
            sheet.save(target/f'native128_reflected{int(reflected)}_{page}.png')
    p.write(target/'review_inventory.json',dict(all_rgb_frames=124,all_alpha_frames=124,all_native_frames_each_facing=124,border_issues=border,visual_acceptance='pending_personal_review; inventory only'))
    print('FULL124_SOURCE_ALPHA_NATIVE_REVIEW_READY',take,'border_frames',len(border),flush=True)

if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('takes',nargs='+');a.add_argument('--rgb-only',action='store_true');args=a.parse_args()
    for take in args.takes:inspect(take,args.rgb_only)
