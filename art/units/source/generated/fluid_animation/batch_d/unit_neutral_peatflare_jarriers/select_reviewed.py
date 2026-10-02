"""Select observed original phases after chronological and enlarged review."""
import json
import numpy as np
from PIL import Image
import produce as p

def selection(take, indices, note, contact=None, separation=None):
    out=p.SOURCE_DIR/take
    value=dict(source_frames=indices,frame_msec=42,review_note=note)
    if contact is not None:value['contact_frame']=indices.index(contact)
    if separation:value['runtime_projectile_separation']=separation
    p.write(out/'selection.json',value)
    p.build(out,json.loads((out/'config.json').read_bytes()))

def support():
    out=p.SOURCE_DIR/'cast_h3_v1'
    guide=np.asarray(Image.open(out/'guide_0_rgba.png').convert('RGBA')).astype(int)
    opaque=guide[:,:,3]>=245
    green=guide[:,:,1]-np.maximum(guide[:,:,0],guide[:,:,2])
    protected=int(green[opaque].max())+2
    settings=json.loads((out/'extraction_settings.json').read_bytes())
    settings['reviewed_key_ranges']=[dict(start=7,end=46,key_rgb=[0,255,0],protected_foreground_chroma=protected)]
    settings['green_original_guide_measurement']=dict(maximum=int(green[opaque].max()),margin=2,opaque_alpha_minimum=245)
    p.write(out/'extraction_settings.json',settings)
    p.write(out/'extract_ranges.json',dict(inclusive_ranges=[[0,3],[7,46],[74,123]],reason='Exclude spatially varying early plate4-6 and color cycling47-73 during held palm. Original gesture rise7-20 and return82-94 remain; no geometry edits or fabricated bridge. Every retained frame must independently pass uniformity and separation checks.'))
    p.process(out,json.loads((out/'config.json').read_bytes()))
    p.review(out,json.loads((out/'config.json').read_bytes()))

def select_valid_originals():
    selection('attack_h3_v1',[0,8,10,12,14,16,17,18,19,20,21,22,24,34]+list(range(35,41))+list(range(54,61))+list(range(75,95))+list(range(102,116))+[123],
        'Chronological original0-123 and enlarged hands/contact reviewed: stow right jar, protect with left fist, right shoulder windup, punch55-60, retract75-94, retrieve jar102-115. Condense held windup41-53 and contact61-74; no active gesture erased, duplicated, reversed or interpolated. Exactly original two arms and hands. Native-scale review still required.',60)
    selection('cast_h3_v1',[0]+list(range(8,23))+[35,45,81]+list(range(82,96))+[102,110,123],
        'Chronological original0-123 and enlarged palm rise/return reviewed: right jar retained, left empty palm rises8-22, held45/81, lowers82-95 to original ready. Unsafe4-6 and background cycling47-73 excluded during unchanged ready/held gesture. Original independently keyed uniform green7-46 and magenta retained intervals pass unchanged gates. Fixed original anatomical scale; no artificial bridge. Native-scale review still required.')

def select_corrected_actions():
    selection('move_h3_v2',list(range(0,32,2)),
        'All124 original frames and enlarged0/8/16/24 contacts reviewed. Original near thigh moves from rear support0 through crossing8 to front extension16; original far leg exchanges oppositely. Fixed centered run, compact right jar retained, left empty arm swings. Sixteen original poses span one complete reciprocal gait; end30 to0 same support phase. No duplicates/interpolation or frame normalization; native review required.')
    selection('hit_h3_v2',[0]+list(range(7,21))+list(range(46,63))+[70,123],
        'All124 originals and enlarged7-20/46-70 reviewed: knee/chest/head recoil, left empty forearm pulled protectively to ribs, compact original right jar gripped; torso/forearm recovers to ready. Reject invented incoming projectile and jar loss from v1. Condense peak hold21-45 and long ready tail. Native review required.')
    selection('defend_h3_v2',[0,8]+list(range(14,24))+[45]+list(range(50,87))+[123],
        'All124 originals and enlarged50-82 reviewed: secure held jar at belt, raise both empty protective fists, gradually flex knees and hips into deep guarded crouch held at123. Reject abrupt43-44 cut and cycling cyan plate from v1. No pose morph/duplicates or artificial intermediate; native review required.')
    selection('ranged_h3_v2',[0]+list(range(28,40))+list(range(52,61))+[66]+list(range(80,103))+[108,114,123],
        'All124 originals and enlarged30-38/52-57/82-90 reviewed. Original right hand cocks one compact jar, empty left arm aims; single physical overarm extension53-55 opens right fingers55; empty follow-through, lower arm and reload original jar. No left-hand emission as in rejected v1. Game owns flight: separate only fully detached generated jar55 above empty source rows72-76 and jar56 beyond empty columns758-762; complete original matte/video retained, all character pixels protected. No glove/equipment erasure; native review required.',55,
        {'55':dict(axis='y',split_y=74,reason='Detached jar above body; empty5-row gap protects full raised right hand and head.'),'56':dict(axis='x',split_x=760,reason='Detached flight right of entire character; empty5-column gap protects full hand and cloak.')})

def select_collapse():
    selection('death_h3_v3',[0]+list(range(18,57))+[62,65,123],
        'All124 original frames and enlarged18-40/49-65/123 reviewed: knees buckle and descend, empty left hand braces, hips and shoulder roll sideways, cloak settles, head-right corpse remains grounded. Compact round jar stays visibly gripped in original right hand against chest throughout; no floating/released jar. Reject v1 barrel morph and v2 orbiting loose jar. Dense original collapse and final grounded terminal frame; no duplicate/reversed/interpolated padding. Native review required.')
    delivery=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())
    delivery['takes']=['move_h3_v2','attack_h3_v1','hit_h3_v2','defend_h3_v2','cast_h3_v1','death_h3_v3','ranged_h3_v2']
    p.write(p.SOURCE_DIR/'delivery.json',delivery);p.assemble()

if __name__=='__main__':
    import sys
    if '--collapse' in sys.argv:select_collapse()
    elif '--corrected' in sys.argv:select_corrected_actions()
    else:
        support()
        select_valid_originals()
