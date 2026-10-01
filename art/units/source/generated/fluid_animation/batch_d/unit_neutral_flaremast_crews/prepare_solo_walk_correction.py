"""Use a genuinely opposed contact instead of the earlier passing reference."""
import json
from PIL import Image
import produce as p
import prepare_solo_completion as prep

if __name__=='__main__':
    s=p.SOURCE_DIR;name='walk_opposed_contact_v1';source=s/(name+'.png')
    rgba,detail=p.key(Image.open(source).convert('RGB'),dict(key_rgb=[0,255,0],protected_foreground_chroma=24))
    path=s/(name+'_matte.png');rgba.save(path)
    recipe=dict(original=dict(path=source.relative_to(p.ROOT).as_posix(),sha256=p.sha(source)),rgba=dict(path=path.relative_to(p.ROOT).as_posix(),sha256=p.sha(path)),matte=detail,rebuild='prepare_solo_walk_correction.py')
    p.write(s/(name+'_matte.json'),recipe)
    g=json.loads((s/(name+'.generation.json')).read_bytes());g['original_image']=g['image'];g['image']=recipe['rgba'];g['matte_recipe']=dict(path=(s/(name+'_matte.json')).relative_to(p.ROOT).as_posix(),sha256=p.sha(s/(name+'_matte.json')));p.write(s/(name+'_matte.generation.json'),g)
    ref=dict(name=name,source=path.relative_to(p.ROOT).as_posix(),rects=[[0,0,rgba.width,rgba.height]],anchor=[780,888],scale=.3125,alpha_noise_cutoff=0)
    c=json.loads((s/'move_solo_h3_v3/config.json').read_bytes());c.update(seed=2026100351,references=[prep.whole('walk_contact_original48'),ref],guides=[[32,1],[64,0],[96,1]],last=0)
    c['prompt']=c['prompt'].replace('frame0/60/123 and opposite contact30/90','frame0/64/123 and opposite contact32/96')+' NEAR thigh begins under red sash at screen-left hip: on its forward stride it crosses in front of the FAR thigh and the near boot reaches ahead to screen RIGHT, exactly as supplied opposite guide32/96. FAR thigh starts below screen-right pouch and on this phase extends BACK left. Both leg chains remain anatomically distinct through the crossover and passing phases. Neither leg may always remain behind or always be the forward leg.'
    out=s/'move_solo_h3_v4';out.mkdir(exist_ok=False);p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
    print('Prepared true near/far opposite-contact walking correction')
