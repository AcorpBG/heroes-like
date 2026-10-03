"""Retain original new key master, crop lineage and fixed-scale comparisons."""
import json
from PIL import Image,ImageDraw
import produce as p

def main():
    S=p.SOURCE_DIR;folder=S/'contact_support_keys_v1';master=folder/'original.png'
    image=Image.open(master);assert image.size==(1983,793) and image.mode=='RGBA'
    refs=[dict(name='original_physical_counterthrust',source=master.relative_to(p.ROOT).as_posix(),rects=[[0,0,991,793]],anchor=[444,720],scale=.26,alpha_noise_cutoff=8),
          dict(name='original_lens_calibration_peak',source=master.relative_to(p.ROOT).as_posix(),rects=[[991,0,1983,793]],anchor=[1454,724],scale=.26,alpha_noise_cutoff=8)]
    generation=dict(tool='built-in image_gen',generated_master=master.relative_to(p.ROOT).as_posix(),master_sha256=p.sha(master),prompt=(folder/'prompt.txt').relative_to(p.ROOT).as_posix(),prompt_sha256=p.sha(folder/'prompt.txt'),tool_original_path='C:/Users/acorp/.codex/generated_images/01a0965d-a98e-7560-8e9d-802269b3760b/exec-56a5e771-a630-4827-b2a3-6f695821db9e.png',reference='art/units/source/curated/'+S.name+'.png',reference_sha256=p.sha(p.ROOT/'art/units/source/curated'/f'{S.name}.png'),usage='Two physical H3 conditioning keys only, never standalone completed clips.',visual_review='pending fixed-scale key registration')
    p.write(folder/'generation.json',generation);p.write(folder/'references.json',refs)
    baseline=json.loads((S/'original_pose_references.json').read_bytes())[0]
    out=p.ROOT/'.artifacts/heliograph_ballista_h3/guides'
    for reflected in [False,True]:
        sheet=Image.new('RGB',(1920,1000),(27,38,29));draw=ImageDraw.Draw(sheet)
        for row,bg in enumerate([(27,38,29),(221,213,197)]):
            for column,ref in enumerate([baseline]+refs):
                x,y=column*640,row*500;sheet.paste(bg,(x,y,x+640,y+500))
                pose,(dx,dy)=p.source_pose(dict(ref,scale=ref['scale']*.5),8)
                if reflected:pose=pose.transpose(Image.Transpose.FLIP_LEFT_RIGHT);dx=-dx-pose.width
                for multiplier,origin in [(1,(x+180,y+200)),(2,(x+330,y+455))]:
                    im=pose.resize((pose.width*multiplier,pose.height*multiplier),Image.Resampling.NEAREST)
                    px,py=origin[0]+dx*multiplier,origin[1]+dy*multiplier
                    assert x<=px and px+im.width<=x+640 and y+25<=py and py+im.height<=y+500
                    sheet.paste(im,(px,py),im);draw.line((x+8,origin[1],x+630,origin[1]),fill=(105,132,81))
                draw.text((x+9,y+8),ref['name']+f'; original master scale {ref["scale"]}',fill=(153,113,65))
        sheet.save(out/f'new_keys_registration_facing{int(reflected)}.png')
    print('TWO ORIGINAL PHYSICAL KEYS AND PROVENANCE PRESERVED; REGISTRATION REVIEW PENDING')

if __name__=='__main__':main()
