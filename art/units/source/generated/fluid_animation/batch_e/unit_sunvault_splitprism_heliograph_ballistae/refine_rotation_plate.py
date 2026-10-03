"""Remove spatial plate contamination using the preserved semantic alpha."""
import json
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import distance_transform_edt
import produce as p


def main():
    folder=p.SOURCE_DIR/'rolling_rotation_key_v4'
    record=json.loads((folder/'matte.json').read_bytes())
    assert p.sha(folder/'original.png')==record['source_sha256']
    assert p.sha(folder/'matte.png')==record['rgba_sha256']
    rgb=np.array(Image.open(folder/'original.png').convert('RGB')).astype(np.float32)
    previous=np.array(Image.open(folder/'matte.png').convert('RGBA'))
    alpha=previous[:,:,3].astype(np.float32)/255
    safe=(alpha==0)&(distance_transform_edt(alpha<.01)>=3)
    assert safe.sum()>alpha.size*.1
    _,nearest=distance_transform_edt(~safe,return_indices=True)
    plate=rgb[nearest[0],nearest[1]]
    color=np.clip((rgb-(1-alpha[:,:,None])*plate)/np.maximum(alpha[:,:,None],.001),0,255)
    out=np.dstack((color,alpha*255)).astype('uint8')
    out[alpha==0]=0
    assert np.array_equal(out[:,:,3],previous[:,:,3]),'No change to semantic foreground geometry'
    solid=previous[:,:,3]==255
    assert np.array_equal(out[:,:,:3][solid],rgb.astype('uint8')[solid]),'Opaque original RGB must remain exact'
    target=folder/'matte_spatial_plate.png'
    assert not target.exists(),'Preserve previous extraction versions'
    Image.fromarray(out).save(target)
    p.write(folder/'matte_spatial_plate.json',dict(
        source_sha256=record['source_sha256'], semantic_matte_sha256=record['rgba_sha256'],
        rgba_sha256=p.sha(target), unchanged_alpha=True, opaque_source_rgb_exact=True,
        recipe='Preserve the existing pinned BiRefNet alpha byte for byte. Recompute only soft-edge RGB from original pixels using nearest confidently excluded spatial plate (alpha0, distance at least3px from alpha>=.01). Uniform corner unmix previously left pale gray/white contamination in spoke gaps and under the rods. No foreground coordinates, anatomy, wheel phase or opaque colors change.',
        tool_sha256=p.sha(p.Path(__file__)), visual_review='pending personal dark/light/native review'))
    rev=p.ROOT/'.artifacts/heliograph_ballista_h3/rotation_key_v4_spatial_review'
    rev.mkdir(exist_ok=True)
    im=Image.fromarray(out)
    for bg,name in [((28,38,28),'dark'),((219,212,197),'light')]:
        view=Image.new('RGB',im.size,bg);view.paste(im,(0,0),im);view.save(rev/(name+'.png'))
    ref=dict(name='alternate actual painted wheel phase',source=target.relative_to(p.ROOT).as_posix(),rects=[[0,0,*im.size]],anchor=[746,899],scale=.21)
    initial=dict(name='original rolling phase',source=(p.SOURCE_DIR/'move_h3_v2/guide_0_rgba.png').relative_to(p.ROOT).as_posix(),rects=[[0,0,960,704]],anchor=[480,576],scale=.45)
    for reflected in [False,True]:
        view=Image.new('RGB',(960,680),(28,38,28));draw=ImageDraw.Draw(view)
        for j,f in enumerate([initial,ref]):
            for native in [True,False]:
                x=j*480;y=0 if native else 340
                if j:view.paste((219,212,197),(x,y,x+480,y+340))
                pose,(dx,dy)=p.source_pose(dict(f,scale=f['scale']*(.5 if native else 1)),0)
                if reflected:pose=pose.transpose(Image.Transpose.FLIP_LEFT_RIGHT);dx=-dx-pose.width
                view.paste(pose,(x+240+dx,y+310+dy),pose)
                draw.line((x+4,y+310,x+476,y+310),fill=(111,137,86))
                draw.text((x+8,y+8),f['name']+('128' if native else'256'),fill=(154,114,67))
        view.save(rev/f'native_reflected{int(reflected)}.png')
    p.write(folder/'matte_spatial_reference.json',ref)
    print('SPATIAL_PLATE_UNMIX_READY; ALPHA_AND_OPAQUE_ORIGINAL_RGB_EXACT',flush=True)


if __name__=='__main__':main()
