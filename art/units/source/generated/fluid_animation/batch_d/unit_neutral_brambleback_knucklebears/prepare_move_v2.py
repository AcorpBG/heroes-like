"""Prepare one targeted gait correction with an explicit hind-paw passing guide."""
import json
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_erosion
import produce as p
import prepare_h3 as prep


if __name__ == '__main__':
    folder = p.SOURCE_DIR / 'guides'
    master = folder / 'passing_near_hind_v1.png'
    prompt = folder / 'passing_near_hind_v1.prompt.txt'
    reference = p.SOURCE_DIR / 'move_h3_v1/guide_1_chroma.png'
    p.write(folder / 'passing_near_hind_v1.json', dict(unit_id=prep.UID, generator='built-in image_gen image edit',
        image=master.relative_to(p.ROOT).as_posix(), image_sha256=p.sha(master),
        prompt=prompt.relative_to(p.ROOT).as_posix(), prompt_sha256=p.sha(prompt),
        original_tool_output='C:/Users/acorp/.codex/generated_images/01a0f615-67c7-7ef1-ac53-345d29d5700f/exec-bc221ea9-e419-4b5e-abe8-182be108caaa.png',
        references=[dict(path=reference.relative_to(p.ROOT).as_posix(), sha256=p.sha(reference))],
        review='Two original front arms with distinct grounded paws; near hind hip/knee bent and paw visibly unloaded/advanced, far hind foot planted beneath rear torso. Original camera/torso proportions retained on a 1536x1024 canvas; one source-wide .3125 scale maps the 1.6x guide resolution without bounds normalization.'))
    rgba, matte = p.key(Image.open(master).convert('RGB'), dict(key_rgb=[0,0,255], protected_foreground_chroma=9))
    rgba.save(folder / 'passing_near_hind_rgba.png')
    p.write(folder / 'passing_near_hind_rgba.json', dict(unit_id=prep.UID,
        source=master.relative_to(p.ROOT).as_posix(), source_sha256=p.sha(master),
        output_sha256=p.sha(folder/'passing_near_hind_rgba.png'), matte=matte,
        rule='Flat plate extraction only, original anatomy unmodified. Fixed source-wide .3125 scale and [752,896] anchor map 1536x1024 to original 960x640 guide.'))
    old = p.SOURCE_DIR / 'move_h3_v1'
    p.write(old / 'visual_review.json', dict(status='rejected',
        reviewed_original_frames=list(range(124)), reviewed_matte_frames=list(range(124)),
        defects=['Abrupt front contact exchanges at original11 to12,25 to26 and42 to43.',
            'Near hind paw stays effectively planted; no clear reciprocal near-hind unload, passing and forward contact.',
            'Repeated front-contact blocks cannot be trimmed into a continuous supported gait.'],
        next_correction='Add explicit near-hind lifted/advanced passing and far-hind planted support guide before one targeted v2.'))
    config = json.loads((old / 'config.json').read_bytes())
    config['seed'] = 2026100190
    config['references'] = [prep.ref(2), dict(name='near_hind_passing_load_transfer',
        source=(folder/'passing_near_hind_rgba.png').relative_to(p.ROOT).as_posix(),
        rects=[[0,0,1536,1024]], anchor=[752,896], scale=.3125, alpha_noise_cutoff=8),
        config['references'][2], prep.ref(0)]
    config['guides'] = [[25,1],[55,2],[85,3],[110,0]]
    config['last'] = 0
    config['prompt'] = ' '.join(part.strip() for part in [prep.IDENTITY,
        'One continuous slow reciprocal knucklewalk cycle in place, with no abrupt contact pose changes or static repeated blocks. '
        'Begin with near front knuckles loaded. Gradually shift chest weight while both front paws stay traceable shoulder to elbow to wrist. '
        'At the first passing guide, visibly lift and advance the near hind paw by flexing its hip and knee; the far hind foot stays planted, '
        'and both front paws briefly share load. Then plant that advancing near hind paw, lift the far front paw, swing it low forward and '
        'plant its knuckles, transferring chest load to the far front arm as the near front paw bends and unloads. '
        'Next lift and pass the far hind paw under the hip while the near hind and near front contacts take weight. '
        'Swing the near front knuckles low forward, plant them and return smoothly to the initial near loaded contact. '
        'All four limbs must articulate through loading, lift, low passing and contact; no hind paw remains fixed through the complete cycle. '
        'Keep three paw contacts during slow load transfer whenever possible, never float or hop. '
        'Maintain one constant torso/head size and bark/fur design between every guide. No cutting or teleporting at keyframes.', prep.PLATE])
    config['registration_note'] = 'Original paintings .6; opposed-contact master .215/[768,1000]; passing master .3125/[752,896] from known 1.6x output canvas mapping. Fixed source-wide scales register torso/head anatomy, never each pose bounds.'
    config['correction_reason'] = 'V1 retained/rejected: abrupt front contact swaps and stationary near hind paw. One targeted correction adds explicitly unloaded advancing near hind limb with far hind support.'
    out = p.SOURCE_DIR / 'move_h3_v2'
    out.mkdir(exist_ok=False)
    p.prepare(out, config)
    images = []
    bands = []
    for i in range(len(config['references'])):
        image = Image.open(out/f'guide_{i}_rgba.png')
        pixels = np.asarray(image).astype(float)
        mask = binary_erosion(pixels[:,:,3]>240, iterations=3)
        bands.append(float((pixels[:,:,2]-np.maximum(pixels[:,:,0],pixels[:,:,1]))[mask].max()))
        images.append(image)
    config['protected_foreground_chroma'] = max(0,int(max(bands))+2)
    config['foreground_measurement'] = dict(per_guide_max=bands,separation=255-config['protected_foreground_chroma'],
        rule='Eroded opaque blue-minus-max(red,green) maximum plus two across original/opposed/passing guides.')
    p.write(out/'config.json',config)
    profile=json.loads((p.SOURCE_DIR/'runtime_profile.json').read_bytes())
    profile['generation_authorization']='Prepared movement v2 only; separate exclusive GPU grant required. No submission or model unload during guide preparation.'
    p.write(out/'runtime_profile.json',profile)
    sheet=Image.new('RGB',(1920,700),(39,45,36));draw=ImageDraw.Draw(sheet)
    for i,image in enumerate(images):
        image.thumbnail((470,620),Image.Resampling.LANCZOS)
        sheet.paste(image,(i*480,40),image)
        draw.text((i*480+4,8),['Original near loaded','Near hind passing / shared front load','Opposed far loaded','Original grounded return'][i])
    sheet.save(p.ROOT/'.artifacts/knucklebear_h3_20261001/movement_v2_guides.png')
    print('Prepared targeted movement v2; protected blue:',config['protected_foreground_chroma'])
