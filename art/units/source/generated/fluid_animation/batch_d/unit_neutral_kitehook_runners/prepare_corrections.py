"""Prepare unsubmitted measured green corrections; GPU authorization is separate."""
import json
import shutil
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_erosion
import produce as p
from prepare_h3 import ref, IDENTITY

if __name__ == '__main__':
    guides=p.SOURCE_DIR/'guides'
    raw=guides/'opposed_attempt_v4.png'
    # Generated uniform plate is extracted with the original measured costume
    # band. The exact original master and provider prompt remain immutable.
    raw_pixels=np.asarray(Image.open(raw).convert('RGB')).astype(float)
    chroma=raw_pixels[:,:,1]-np.maximum(raw_pixels[:,:,0],raw_pixels[:,:,2])
    interior=binary_erosion(chroma<100,iterations=6)
    protected=max(72,int(chroma[interior].max())+2)
    rgba,details=p.key(Image.open(raw).convert('RGB'),dict(key_rgb=[0,255,0],protected_foreground_chroma=protected))
    target=guides/'opposed_contact_rgba.png';rgba.save(target)
    generation=json.loads((guides/'opposed_attempt_v4.generation.json').read_bytes())
    generation.update(derived_rgba={'path':target.relative_to(p.ROOT).as_posix(),'sha256':p.sha(target)},extraction=dict(details,protected_foreground_chroma=protected,measurement='Six-pixel eroded nonplate interior green chroma<100, bounded below by measured original costume72; no body geometry changes.'),review_note='Pending fixed global anatomical scale/anchor guide review; only plate extraction, no authored transformations.')
    p.write(target.with_suffix('.generation.json'),generation)
    opposed=dict(source=target.relative_to(p.ROOT).as_posix(),rects=[[0,0,rgba.width,rgba.height]],anchor=[908,953],scale=.185,alpha_noise_cutoff=8)
    shared=dict(unit_id='unit_neutral_kitehook_runners',canvas=[960,640],anchor=[470,560],scale=.5,key_rgb=[0,255,0],tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
    move=dict(shared,clip='move',seed=2026100160,references=[ref(2),ref(17),opposed],guides=[[18,1],[35,2],[52,1],[70,0],[87,1],[105,2]],last=0,
        prompt=IDENTITY+'Run in place for two complete reciprocal running cycles. Begin the original near-leg-forward contact, load the contacting foot, pass through the supplied both-feet-grounded stance, then reverse to the supplied far-leg-forward contact with the near knee visibly bent back. Repeat the opposite sequence with the feet taking turns carrying body weight. Each leg moves on its own side without crossing the knees. The hips stay centered and every contacting boot stays planted during its loading phase. Both hands retain the original compact hook pole. End in exactly the first contact, creating a continuous loop with meaningful opposite contacts and passing/loading phases. Fixed elevated three-quarter orthographic camera facing right; unchanged original body scale and identity. Background perfectly flat pure green RGB0,255,0 throughout, no hue changes, floor, shadows, scenery or effects.')
    hit0=json.loads((p.SOURCE_DIR/'hit_h3_v1/config.json').read_bytes())
    hit=dict(hit0,seed=2026100161,key_rgb=[0,255,0],prompt=hit0['prompt'].replace('magenta RGB255,0,255','green RGB0,255,0'))
    thumbs=[]
    for name,c in [('move_h3_v2',move),('hit_h3_v2',hit)]:
        out=p.SOURCE_DIR/name;out.mkdir(exist_ok=False)
        p.prepare(out,c)
        bands=[]
        for i in range(len(c['references'])):
            im=Image.open(out/f'guide_{i}_rgba.png');a=np.asarray(im).astype(float)
            mask=binary_erosion(a[:,:,3]>240,iterations=3)
            bands.append(float((a[:,:,1]-np.maximum(a[:,:,0],a[:,:,2]))[mask].max()))
            thumbs.append((name+':'+str(i),im.copy()))
        c['protected_foreground_chroma']=max(0,int(max(bands))+2)
        c['foreground_measurement']=dict(rule='Three-source-pixel eroded opaque green-minus-max(red,blue) maximum plus two across current fixed-scale guides.',per_guide_max=bands,separation=255-c['protected_foreground_chroma'])
        assert c['foreground_measurement']['separation']>=80
        c['correction_note']='Unsubmitted v2; original v1 immutable and rejected. Measured uniform green replaces hue-cycling magenta; movement adds explicit opposite contact and original grounded passing, with one fixed anatomical scale per painting.'
        p.write(out/'config.json',c)
        p.prepare(out,c)
        p.verify(out,c)
    sheet=Image.new('RGB',(len(thumbs)*360,640),(43,48,43));d=ImageDraw.Draw(sheet)
    for i,(name,im) in enumerate(thumbs):
        im.thumbnail((355,600));sheet.paste(im,(i*360,30),im);d.text((i*360+4,4),name)
    sheet.save(p.ROOT/'.artifacts/kitehook_h3/correction_guides.png')
