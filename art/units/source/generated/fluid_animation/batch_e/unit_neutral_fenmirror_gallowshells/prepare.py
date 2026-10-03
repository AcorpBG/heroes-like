"""Original Gallowshell guides at one fixed anatomical scale per source."""
import json, hashlib, sys
from pathlib import Path
from PIL import Image, ImageDraw

S=Path(__file__).resolve().parent
ROOT=next(p for p in S.parents if (p/'project.godot').exists())
sys.path.insert(0,str(ROOT/'tools'))
from integrate_fluid_creature_animation import source_pose

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,x): p.write_text(json.dumps(x,indent=2)+'\n',encoding='utf-8')

def main():
    source=ROOT/'art/units/source/generated/fluid_animation/batch_e/unit_neutral_cindervane_censerwings'
    substitutions={'Cindervane Censerwing':'Fenmirror Gallowshell','cindervane_censerwing':'fenmirror_gallowshell','unit_neutral_cindervane_censerwings':'unit_neutral_fenmirror_gallowshells'}
    for name in ['produce.py','stage_video.py','segment.py']:
        text=(source/name).read_text(encoding='utf-8')
        if name=='produce.py': text=text.split('\ndef build(')[0]
        for a,b in substitutions.items(): text=text.replace(a,b)
        target=S/name
        if target.exists(): assert target.read_text(encoding='utf-8')==text
        else: target.write_text(text,encoding='utf-8')
    write(S/'matting_model.json',json.loads((source/'matting_model.json').read_bytes()))
    original=json.loads((S/'original_reference_poses.json').read_bytes())['frames']
    for ref in original: assert sha(ROOT/ref['source'])==ref['source_sha256']
    new=S/'support_guide_v1/original.png'
    assert Image.open(new).size==(1243,1265)
    support=dict(name='closed_pincer_salute_original',source=new.relative_to(ROOT).as_posix(),rects=[[0,0,1243,1265]],anchor=[704,1190],scale=.225,source_sha256=sha(new))
    # Body/head and carapace dimensions match the original reference. Raised
    # claw height is not used to normalize scale. All extracted video frames
    # will retain one .42 scale and the exact [480,584] ground origin.
    write(S/'support_registration.json',dict(reference=original[12],support=support,reason='One original master scale0.225 matches torso width and carapace height against original scale0.62; eye horizontal offset and walking-foot clearance match the old anchor. No individual frame fit, stabilization or anatomical repaint.',visual_review='personally_reviewed_native128_and_enlarged2x_both_facings_dark_light; key pose only, video acceptance pending'))
    out=ROOT/'.artifacts/parallel_animation_20261003'/S.name
    out.mkdir(parents=True,exist_ok=True)
    for facing in [0,1]:
        sheet=Image.new('RGB',(1280,640));d=ImageDraw.Draw(sheet)
        for row,bg in enumerate([(29,39,32),(222,216,199)]):
            for col,ref in enumerate([original[12],support]):
                x,y=col*640,row*320;sheet.paste(bg,(x,y,x+640,y+320))
                pose,offset=source_pose(dict(ref,scale=ref['scale']*.5),8)
                for native,center in [(True,x+170),(False,x+430)]:
                    magnify=1 if native else 2
                    im=pose.resize((pose.width*magnify,pose.height*magnify),Image.Resampling.NEAREST)
                    px=center+offset[0]*magnify;py=y+280+offset[1]*magnify
                    if facing: im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT);px=center-offset[0]*magnify-im.width
                    sheet.paste(im,(px,py),im)
                d.line((x+5,y+280,x+635,y+280),fill=(117,138,92))
                d.text((x+10,y+10),ref['name']+' native128 / enlarged2x',fill=(161,119,66))
        sheet.save(out/f'support_registration_facing{facing}.png')
    identity='One original armored Fenmirror Gallowshell crab, exactly six jointed walking legs in three pairs and exactly two separate serrated pincer arms. Blue-gray peatglass carapace, bronze edge armor, moss tufts, curved back arch with original hanging bronze rings and moss cords, amber eyes. Low broad torso, original proportions. Fixed elevated three-quarter tactical camera, facing RIGHT. No camera movement, body growth, duplicate limbs, changed claw identities, new ornaments, glow, sparks, particles, projectile, fog, scenery, shadow floor or text. Entire creature and every claw and leg tip safely inside the frame. Opaque flat pale blue-gray background. '
    actions={
        'move_h3_v1':([0,2,4,3],[[20,1],[40,2],[60,3],[80,2],[100,1]],0,'move','Crawl naturally in place through reciprocal alternating support tripods. Opposite near/far legs lift, pass, contact, load and extend; weight transfers across three planted feet without root translation. Both original pincer arms remain distinct, slightly balancing the torso. Back arch ornaments sway subtly from leg effort. Two coherent crawl cycles and settle to the original ready stance.'),
        'attack_h3_v1':([0,5,6],[[24,1],[45,2]],0,'attack','One physical upper forward pincer attack. Draw that pincer back and open its serrated jaws, thrust it toward RIGHT, close the jaws for an unmistakable snap contact, recoil the same arm, then smoothly recover ready. Lower foreground pincer stays separate and counterbalances. Six walking legs brace in place. No energy slash, connecting ring, beam or second attacker.'),
        'hit_h3_v1':([0,8],[[36,1]],0,'hit','One brief physical impact reaction without an attacker. Both original claws lift apart while torso rocks back, feet remain planted, then original shoulders and claws recover to ready. Not a collapse or salute. No red color pulse, damage glow or new effects.'),
        'defend_h3_v1':([0,7],[[58,1]],1,'defend','Lower body and bring the two separate pincer arms into a compact protective guard in front of torso. Six legs spread and load, carapace tips slightly forward. Reach the original dedicated brace and HOLD it to the end. Do not return to ready.'),
        'cast_h3_v1':([original[0],support],[[48,1]],0,'cast','A nonmagical closed-pincer support salute. Keep six walking legs planted, lift the upper forward pincer with jaws CLOSED beside the curved carapace arch, hold a deliberate upward affirmation, lower that same closed pincer, and recover original ready. Lower foreground claw counterbalances without changing identity. No spell or recoil.'),
        'death_h3_v1':([0,11],[],1,'death','One continuous physical collapse: walking knees buckle, six legs lose support and fold naturally, carapace lowers and rolls slightly toward the original grounded corpse, both pincers slacken and come to rest. Back arch, moss and bronze rings settle with weight. End in the original low corpse, motionless on the same ground. No fade, dissolve, popping, disappearing armor, resurrecting or return to ready.')}
    for n,(refs,guides,last,action,beats) in actions.items():
        refs=[original[r] if isinstance(r,int) else r for r in refs]
        c=dict(unit_id=S.name,canvas=[960,704],scale=.42,anchor=[480,584],key_rgb=[190,206,222],seed=2026100300+list(actions).index(n),references=refs,guides=guides,last=last,prompt=identity+beats,action=action,tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4),visual_review='pending',selection='not_selected')
        dest=S/n;dest.mkdir(exist_ok=True)
        if (dest/'sampling_submission.json').exists(): assert json.loads((dest/'config.json').read_bytes())==c
        else: write(dest/'config.json',c)
        import produce
        produce.prepare(dest,c)
    guides=list(S.glob('*_h3_v1/guide_*_chroma.png'))
    sheet=Image.new('RGB',(1920,((len(guides)+3)//4)*376),(29,39,32));d=ImageDraw.Draw(sheet)
    for i,g in enumerate(guides):
        x,y=i%4*480,i//4*376
        im=Image.open(g).resize((480,352),Image.Resampling.LANCZOS)
        sheet.paste(im,(x,y+24));d.text((x+5,y+4),g.parent.name+'/'+g.name,fill=(205,193,154))
    sheet.save(out/'all_original_h3_guides.png')
    print('SIX ORIGINAL GUIDE SETS PREPARED; NO VIDEO ACCEPTED')

if __name__=='__main__': main()
