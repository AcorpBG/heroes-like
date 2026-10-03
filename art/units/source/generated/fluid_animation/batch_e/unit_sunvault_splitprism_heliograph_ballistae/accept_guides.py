"""Record actual personal guide review; never accept an ungenerated action."""
import json
from PIL import Image
import produce as p

def main():
    S=p.SOURCE_DIR
    inspected={}
    for folder in sorted(S.glob('*_h3_v1')):
        c=json.loads((folder/'config.json').read_bytes());p.verify(folder,c)
        guide_record=json.loads((folder/'reference.json').read_bytes())
        guides=[]
        for i,ref in enumerate(guide_record['guides']):
            rgba=Image.open(folder/f'guide_{i}_rgba.png')
            assert rgba.size==tuple(c['canvas']) and rgba.mode=='RGBA'
            b=rgba.getchannel('A').point(lambda a:255 if a>127 else 0).getbbox()
            assert b and 0<b[0]<b[2]<rgba.width-1 and 0<b[1]<b[3]<rgba.height-1
            guides.append(dict(image=ref['input_file'],sha256=ref['input_sha256'],source=ref['source_frame']['source'],source_sha256=ref['source_sha256'],anchor=c['anchor'],output_scale=c['scale']))
        inspected[folder.name]=dict(action=c['action'],guides=guides,source_pose_guide_review='personally reviewed original masters, complete 960x704 guide canvases and fixed native128/enlarged2x originals on dark/light both facings; correct two wheels, three star feet, single two-arm/two-leg operator, blue-front LEFT/amber-rear RIGHT and original lens. These are conditioning keys only.',video_review='pending; no selected frame indices or generated motion accepted')
    assert len(inspected)==7
    p.write(S/'guide_review.json',dict(unit_id=S.name,actions=inspected,new_key_master='contact_support_keys_v1/original.png',new_key_note='Built-in original contact/support pair .26 fixed master scale, anchors tied to frontal star-foot contact; no per-pose bounds fit. Old legacy melee guide rejected before video for scale/camera inconsistency and archived without destruction. New keys personally checked in both facings at native128/2x on dark/light. Video identity/continuity remain pending.',idle_preservation='Eight idle16-23 individually reviewed; preserve exact240ms original battle and map pixels and anchor. Qualifying hand-crank movement, coherent cape and stable wheels/stabilizers; no generated idle needed.'))
    brief=json.loads((S/'brief.json').read_bytes())
    brief['status']='in_progress_original_h3_generation'
    brief['guide_review']='Seven genuine action guide sets personally reviewed, including new original physical contact and lens-calibration keys. All generated clips pending, no production acceptance.'
    p.write(S/'brief.json',brief)
    generation=json.loads((S/'contact_support_keys_v1/generation.json').read_bytes())
    generation['visual_review']='personally inspected as two H3 original keys at native128/enlarged2x dark/light both facings; one fixed .26 master scale; no generated motion or clip acceptance'
    p.write(S/'contact_support_keys_v1/generation.json',generation)
    print('SEVEN KEY SETS PERSONALLY REVIEWED; PRESERVE EIGHT IDLE POSES; ALL NEW VIDEO MOTION PENDING')

if __name__=='__main__':main()
