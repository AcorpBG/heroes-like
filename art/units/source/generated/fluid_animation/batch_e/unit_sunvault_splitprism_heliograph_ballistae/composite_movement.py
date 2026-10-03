"""Bake observed spinning H3 wheels behind the original H3 chassis.

Fixed scales per original component; hub registration is measured from the
original chassis, never variable ink extents. No invented rotation or poses.
"""
import json
import cv2
import numpy as np
from PIL import Image, ImageDraw
import produce as p

BODY=p.SOURCE_DIR/'move_h3_v4'
WHEELS=p.SOURCE_DIR/'wheel_assembly_h3_v1'
OUT=p.SOURCE_DIR/'move_composite_v1'
PARTS=[dict(name='far',source_hub=[264,290],source_crop=[98,110,425,465],
            scale=.36,body_hub=[412,492],erase_center=[404,489],erase_radii=[57,68],
            occluder=[[430,414],[528,416],[532,469],[501,500],[473,519],[440,500],[436,468]]),
       dict(name='near',source_hub=[722,386],source_crop=[525,185,870,590],
            scale=.34,body_hub=[558,507],erase_center=[545,506],erase_radii=[61,72],
            occluder=[[511,418],[566,433],[558,449],[576,457],[566,470],[548,465],[537,481],[527,479],[525,459],[505,462]])]

def ellipse_mask(size,center,radii,angle=9):
    yy,xx=np.indices((size[1],size[0]));dx=xx-center[0];dy=yy-center[1]
    t=np.deg2rad(angle);u=dx*np.cos(t)+dy*np.sin(t);v=-dx*np.sin(t)+dy*np.cos(t)
    return Image.fromarray(((u/radii[0])**2+(v/radii[1])**2<=1).astype('uint8')*255)

def main():
    OUT.mkdir(exist_ok=True);(OUT/'matte').mkdir(exist_ok=True)
    records={k:json.loads((v/'matte.json').read_bytes()) for k,v in [('body',BODY),('wheels',WHEELS)]}
    template=np.asarray(Image.open(BODY/'matte/rgba_000.png').convert('RGB'))
    trace=[];hashes=[]
    for i in range(124):
        bf=BODY/'matte'/f'rgba_{i:03}.png';wf=WHEELS/'matte'/f'rgba_{i:03}.png'
        assert p.sha(bf)==records['body']['rgba_sha256'][i]
        assert p.sha(wf)==records['wheels']['rgba_sha256'][i]
        body=Image.open(bf).convert('RGBA');wheel=Image.open(wf).convert('RGBA')
        rgb=np.asarray(body.convert('RGB'));foreground=body.copy();back=Image.new('RGBA',body.size)
        contacts=[]
        for spec in PARTS:
            x,y=spec['body_hub'];r=12;search=25
            patch=template[y-r:y+r+1,x-r:x+r+1]
            crop=rgb[y-r-search:y+r+search+1,x-r-search:x+r+search+1]
            scores=cv2.matchTemplate(crop,patch,cv2.TM_CCOEFF_NORMED)
            _,score,_,loc=cv2.minMaxLoc(scores);dx,dy=loc[0]-search,loc[1]-search
            assert score>.40,(i,spec['name'],score)
            center=[spec['erase_center'][0]+dx,spec['erase_center'][1]+dy]
            mask=ellipse_mask(body.size,center,spec['erase_radii'])
            occlusion=Image.new('L',body.size);d=ImageDraw.Draw(occlusion)
            d.polygon([(a+dx,b+dy) for a,b in spec['occluder']],fill=255)
            mask=np.asarray(mask).copy();mask[np.asarray(occlusion)>0]=0
            # Residual old rim below the actual wheel cannot be chassis. Keep
            # the conservative upper contour to preserve the original fork.
            yy,xx=np.indices(mask.shape)
            bottom=(yy>y+dy+(55 if spec['name']=='far' else 58))&(yy<y+dy+82)&(abs(xx-center[0])<70)
            mask[bottom]=255
            if spec['name']=='far':
                mask[(xx>330+dx)&(xx<438+dx)&(yy>465+dy)&(yy<575+dy)]=255
            mask[np.asarray(occlusion)>0]=0
            a=np.asarray(foreground).copy();a[mask>0]=0;foreground=Image.fromarray(a)
            source=wheel.crop(tuple(spec['source_crop']))
            # Keep only the wheel silhouette, excluding the connecting axle.
            c=spec['source_crop'];hub=spec['source_hub']
            ec=[(699 if spec['name']=='near' else 258)-c[0],(386 if spec['name']=='near' else 287)-c[1]]
            er=[170,200] if spec['name']=='near' else [161,178]
            keep=ellipse_mask(source.size,ec,er)
            wa=np.asarray(source).copy();wa[np.asarray(keep)==0]=0;source=Image.fromarray(wa)
            factor=spec['scale'];source=source.resize((round(source.width*factor),round(source.height*factor)),Image.Resampling.LANCZOS)
            pos=[round(x+dx-(hub[0]-c[0])*factor),round(y+dy-(hub[1]-c[1])*factor)]
            back.alpha_composite(source,tuple(pos))
            contacts.append(dict(wheel=spec['name'],body_hub=[x+dx,y+dy],score=score,offset=[dx,dy],paste=pos))
        back.alpha_composite(foreground)
        file=OUT/'matte'/f'rgba_{i:03}.png';back.save(file);hashes.append(p.sha(file))
        trace.append(dict(frame=i,body_sha256=p.sha(bf),wheel_sha256=p.sha(wf),contacts=contacts))
    p.write(OUT/'recipe.json',dict(body='move_h3_v4',wheels='wheel_assembly_h3_v1',parts=PARTS,
        frame_correspondence='Identical chronological source indices at24fps, no reversal/interpolation.',
        anatomical_scale=.45,ground_anchor=[480,576],registration='Original gold axle hub25px template, measured translation only; fixed source scales; original foreground chassis occludes wheel parts.',
        source_rotation='Observed original near-wheel spoke correlation: -711.5 degrees over124frames, minimum adjacent correlation.863; no software rotation.',frames=trace))
    p.write(OUT/'matte.json',dict(rgba_sha256=hashes,recipe_sha256=p.sha(OUT/'recipe.json')))
    p.write(OUT/'config.json',dict(unit_id=p.SOURCE_DIR.name,action='move',scale=.45,anchor=[480,576],canvas=[960,704],composite=True))
    indices=list(range(0,124,2))
    p.write(OUT/'selection.json',dict(source_frames=indices,frame_msec=84,review_note='Observed two-wheel rolling with original operator crank cycle. Full composite/native review pending.'))
    print('COMPOSITE124 original chronological wheel/body pairs; no synthetic motion',flush=True)

if __name__=='__main__':main()
