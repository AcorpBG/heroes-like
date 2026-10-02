"""Targeted correction recipes; retain every original v1 take unchanged."""
import json
import numpy as np
from PIL import Image
import produce as p
from prepare import ref, IDENTITY

plate=(' Locked original elevated three-quarter orthographic camera facing SCREEN RIGHT. '
       'Full original body and both ends of the single spear stay inside960x544. '
       'Fixed body size, fixed camera, root centered. The entire empty background '
       'remains uniform saturated BLUE RGB0,0,255 in EVERY frame. No ground, shadow, '
       'other figure, detached leaves, glitter, ribbon, streak, slash, flare, particle, '
       'spell, changing illumination or camera motion. Amber painted equipment stays '
       'the same brightness throughout; it does not emit light. ')

def correction(clip, refs, guides, last, action, seed):
    out=p.SOURCE_DIR/(clip+'_h3_v2'); out.mkdir(exist_ok=True)
    assert not (out/'submission.json').exists()
    c=dict(unit_id=p.SOURCE_DIR.name,clip=clip,canvas=[960,544],anchor=[480,480],
           scale=.5,key_rgb=[0,0,255],seed=seed,references=refs,guides=guides,
           last=last,prompt=(IDENTITY+action+plate).strip(),protected_foreground_chroma=0,
           tiled_decode=dict(tile_size=512,overlap=64,temporal_size=16,temporal_overlap=4))
    p.prepare(out,c)
    measured=[]
    for i in range(len(refs)):
        a=np.asarray(Image.open(out/f'guide_{i}_rgba.png')).astype(int)
        measured.append(int((a[:,:,2]-np.maximum(a[:,:,0],a[:,:,1]))[a[:,:,3]>=245].max()))
    c['protected_foreground_chroma']=max(measured)+2
    assert 255-c['protected_foreground_chroma']>=80
    p.write(out/'config.json',c);p.verify(out,c)
    p.write(out/'foreground_measurement.json',dict(blue_minus_max_red_green=measured,
            opaque_alpha_minimum=245,margin=2,protected_foreground_chroma=c['protected_foreground_chroma']))

if __name__=='__main__':
    # The original recoil reference contains a separately connected six-pixel
    # floating dash above the helmet. Rectangles omit only that empty-background
    # fragment; every creature pixel, anchor and anatomical scale is preserved.
    h=dict(source=(p.SOURCE_DIR/'hit_h3_v1/guide_1_rgba.png').relative_to(p.ROOT).as_posix(),
           rects=[[0,0,960,75],[0,75,512,85],[525,75,960,85],[0,85,960,544]],
           anchor=[480,480],scale=.5,alpha_noise_cutoff=8)
    correction('hit',[ref(13),h],[[18,0],[34,1],[62,0]],0,
        'One silent physical balance check and recovery. The guardian suddenly leans '
        'chest and head backward while knees bend34, keeping BOTH hands on their '
        'original equipment. Then regain balance through hips, knees and elbows62 '
        'and hold original ready. Only the intact body and held equipment move. '
        'Nothing flies off or passes across the body. No incoming attack is depicted. ',2026102603)
    correction('cast',[ref(13),ref(6)],[[18,0],[38,1],[58,1],[84,0]],0,
        'One quiet physical arm exercise. Both boots stay planted. RIGHT elbow '
        'bends and raises the same full-length wooden spear diagonally above RIGHT '
        'shoulder38, holds that ordinary mechanical position58, and lowers it '
        'progressively84 to the original upright ready. LEFT forearm keeps its '
        'original shield. No thrust, magical action, brightening or visual effect. ',2026102605)
    correction('death',[ref(13),ref(10),ref(11),ref(12)],[[24,1],[44,2],[68,3]],3,
        'One continuous collapse from standing through knee bend24 and side fall44 '
        'to fully grounded corpse68. Antlered head ends SCREEN LEFT, boots SCREEN '
        'RIGHT. Original spear lowers intact and lies horizontally on the ground '
        'in front; original shield rests on fallen torso and ground. Legs and leaf '
        'mantle settle. No long kneeling pause, hovering equipment or shrinking '
        'anatomy. The final second is completely motionless. ',2026102606)
    for clip,reason in [('hit','Detached flakes and white slash ribbons in original frames33-52.'),
                        ('cast','Gold star flares in original frames28-43; backdrop switches magenta/green.'),
                        ('death','Repeated magenta/green backdrop changes and excessively held kneeling phase.')]:
        p.write(p.SOURCE_DIR/(clip+'_h3_v1')/'review_rejection.json',
                dict(status='rejected',reviewed_original_frames=124,reason=reason,
                     correction=clip+'_h3_v2',originals_preserved=True))
    d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
    d['takes']=[n+'_h3_'+('v2' if n in ['hit','cast','death'] else 'v1') for n in ['move','attack','hit','defend','cast','death']]
    p.write(p.SOURCE_DIR/'delivery.json',d)
    p.write(p.SOURCE_DIR/'move_h3_v1/extraction_settings.json',
            dict(protected_foreground_chroma=12,reviewed_key_ranges=[],
                 reason='Original clean ready reference max opaque magenta chroma6. '
                        'Walking guides contain legacy purple edge contamination, not a pink costume. '
                        'Measured brown/green/amber identity retained; small margin protects muted edge colors.'))
    c=json.loads((p.SOURCE_DIR/'move_h3_v1/config.json').read_bytes())
    p.process(p.SOURCE_DIR/'move_h3_v1',c);p.review(p.SOURCE_DIR/'move_h3_v1',c)
