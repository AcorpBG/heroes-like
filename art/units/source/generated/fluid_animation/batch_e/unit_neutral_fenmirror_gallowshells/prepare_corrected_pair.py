"""Prepare a reviewed closed-pincer master and quiet physical joint motion."""
import json
from PIL import Image,ImageDraw
import prepare as p
import produce

def main():
    refs=json.loads((p.S/'original_reference_poses.json').read_bytes())['frames']
    originals=[p.S/'references/extended_open_pincer_original.png',p.S/'references/ready_original.png',p.ROOT/'art/units/source/curated'/f'{p.S.name}.png']
    for version,external in [(1,'exec-3a4fb2d6-7aef-4b6b-87d5-18bc08a1fa40.png'),(2,'exec-8f25a599-7551-47f3-9c4c-396a7b36e292.png')]:
        folder=p.S/f'attack_closed_guide_v{version}';image=folder/'original.png';im=Image.open(image)
        bounds=im.getchannel('A').point(lambda a:255 if a>=8 else 0).getbbox()
        referenced=originals if version==1 else [p.S/'attack_closed_guide_v1/original.png',*originals[1:]]
        p.write(folder/'original.generation.json',dict(tool='built-in image_gen',external_original=f'C:/Users/acorp/.codex/generated_images/01a0965d-a98e-7560-8e9d-802269b3760b/{external}',original_sha256=p.sha(image),size=list(im.size),mode=im.mode,alpha8_bounds=bounds,prompt=f'attack_closed_guide_v{version}.prompt.txt',prompt_sha256=p.sha(p.S/f'attack_closed_guide_v{version}.prompt.txt'),references=[dict(path=f.relative_to(p.ROOT).as_posix(),sha256=p.sha(f)) for f in referenced],review='rejected: original left foot cut by canvas' if version==1 else 'pending native-scale registration review; unmodified original generated pixels'))
    new=p.S/'attack_closed_guide_v2/original.png';assert Image.open(new).size==(1506,1044)
    closed=dict(name='closed_horizontal_pincer_original',source=new.relative_to(p.ROOT).as_posix(),rects=[[0,0,1506,1044]],anchor=[658,935],scale=.225,source_sha256=p.sha(new))
    p.write(p.S/'attack_closed_registration.json',dict(reference=refs[6],closed=closed,reason='One original master scale0.225 and anchor[658,935] match original head/torso and eye-to-ground registration; extended claw is not used to normalize anatomy. No individual video-frame fitting or repaint.',visual_review='pending_personal_registration_review'))
    out=p.ROOT/'.artifacts/parallel_animation_20261003'/p.S.name
    for facing in [0,1]:
        sheet=Image.new('RGB',(1600,680));d=ImageDraw.Draw(sheet)
        for row,bg in enumerate([(29,39,32),(222,216,199)]):
            for col,ref in enumerate([refs[6],closed]):
                x,y=col*800,row*340;sheet.paste(bg,(x,y,x+800,y+340))
                im,(dx,dy)=p.source_pose(dict(ref,scale=ref['scale']*.5),8)
                for n,center in [(1,x+190),(2,x+570)]:
                    pose=im.resize((im.width*n,im.height*n),Image.Resampling.NEAREST)
                    px=center+dx*n;py=y+300+dy*n
                    if facing:pose=pose.transpose(Image.Transpose.FLIP_LEFT_RIGHT);px=center-dx*n-pose.width
                    sheet.paste(pose,(px,py),pose)
                d.line((x+5,y+300,x+795,y+300),fill=(117,138,92));d.text((x+10,y+10),ref['name']+' native128 / enlarged2x',fill=(161,119,66))
        sheet.save(out/f'attack_closed_registration_facing{facing}.png')
    old=json.loads((p.S/'attack_h3_v1/config.json').read_bytes())
    identity='A quiet anatomical joint-motion study of exactly one original armored Fenmirror Gallowshell crab on a completely empty opaque flat pale blue-gray plate. Fixed elevated three-quarter camera, facing RIGHT throughout, no camera movement. Original blue-gray peatglass and aged bronze carapace with moss, amber eyes, curved back arch with exactly three hanging bronze rings/moss cords. Exactly two original serrated pincer arms and six original jointed walking legs in three pairs, far feet naturally occluded. Same original torso dimensions, registration, material colors, limb identity and full uncropped silhouette. Every motion uses only this creature\'s anatomical joints. No other objects, actor, projectile, flying ring, connecting beam, flashes, starburst, sparks, particles, aura, text, fog, floor or shadow. '
    attack=dict(old,seed=2026100311,references=[refs[0],refs[5],refs[6],closed],guides=[[18,1],[32,2],[42,3],[52,3],[78,0]],prompt=identity+'The upper forward pincer draws back while opening, the same arm extends horizontally into empty space toward screen RIGHT, its serrated jaws close together to the closed guide, briefly hold CLOSED, then the same arm retracts and lowers smoothly to the original ready posture. Lower foreground closed pincer remains lowered and separate, counterbalancing the torso. Six walking legs brace without stepping. The three bronze rings stay attached only to the back arch. One deliberate extension, jaw closure and recovery; nothing is held, caught, thrown or emitted.',visual_review='pending',selection='not_selected')
    folder=p.S/'attack_h3_v2';folder.mkdir(exist_ok=True);assert not (folder/'sampling_submission.json').exists();p.write(folder/'config.json',attack);produce.prepare(folder,attack)
    hit_folder=p.S/'hit_h3_v1';assert not (hit_folder/'sampling_submission.json').exists()
    hit=json.loads((hit_folder/'config.json').read_bytes());hit['prompt']=identity+'A single brief startled flinch: the torso leans backward modestly and both original pincer arms lift apart to the provided wide-claw guide while the walking feet stay planted. Then the torso and same two arms settle smoothly to the original ready posture. Keep the original amber eyes and bronze material colors constant. Body remains upright; no collapse or upward salute. Nothing approaches or touches the creature. Only joint movement, no visual or lighting effects.'
    p.write(hit_folder/'config.json',hit);produce.prepare(hit_folder,hit)
    guides=list((p.S/'attack_h3_v2').glob('guide_*_chroma.png'))+list(hit_folder.glob('guide_*_chroma.png'))
    sheet=Image.new('RGB',(1920,752),(29,39,32));d=ImageDraw.Draw(sheet)
    for i,g in enumerate(guides):
        x,y=i%4*480,i//4*376;sheet.paste(Image.open(g).resize((480,352),Image.Resampling.LANCZOS),(x,y+24));d.text((x+5,y+4),g.parent.name+'/'+g.name,fill=(205,193,154))
    sheet.save(out/'corrected_pair_guides.png')
    print('CORRECTED ORIGINAL KEY AND TWO UNACCEPTED MOTION GUIDE SETS READY')

if __name__=='__main__':main()
