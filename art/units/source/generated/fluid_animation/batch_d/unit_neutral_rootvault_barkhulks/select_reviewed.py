"""Selected original action intervals after complete chronological/enlarged review."""
import json
import produce as p

def select(take,indices,msec,note,contact=None,durations=None):
    spec=dict(source_frames=indices,frame_msec=msec,review_note=note)
    if contact is not None:spec['contact_frame']=indices.index(contact)
    if durations is not None:spec['frame_durations_msec']=durations
    out=p.SOURCE_DIR/take;p.write(out/'selection.json',spec)
    p.build(out,json.loads((out/'config.json').read_bytes()))
    print(take,len(indices))

if __name__=='__main__':
    select('move_h3_v1',[0]+list(range(18,101,2))+[123],83,'All124 originals reviewed. One complete reciprocal root-knuckle cycle, including opposite rear-leg support and near/far arm passing. Trim initial/final ready waits. Matching ready endpoints;12fps original samples retain each weight transfer, no reverse frames.')
    attack=[0,16,18,20]+list(range(21,46))+list(range(48,55))+[65,75,85,95,102,110,123]
    durations=[42]*len(attack);durations[attack.index(45)]=126
    select('attack_h3_v2',attack,42,'All124 originals and enlarged38-55 contact reviewed. Single original near-root-fist windup, downward stroke and recovery. Exclude46/47 with baked white streak;45/48 are adjacent matching contact/settle poses with126ms interval. No effect erasure or synthesized pose. First take rejected for subject-overlapping arc/debris.',45,durations)
    select('hit_h3_v1',[0,16,20]+list(range(22,32))+[34,40,45,80]+list(range(81,97))+[100,123],33,'All124 originals reviewed. One chest/head recoil with both attached root arms responding; both rear legs brace. Join matching held reaction45/80 to omit long static wait, retain original recovery81-96. No collapse or new limb.')
    select('defend_h3_v1',[0,48,52,54,56]+list(range(57,73))+[76,84,96,123],42,'All124 originals and enlarged48-72 transition reviewed. Trim initial ready wait; original arms close into rooted guard while rear knees flex and chest lowers. End123 is held original defensive stance, not idle.')
    support=[0,16,20]+list(range(24,39))+[45,62,68]+list(range(69,85))+[100,123]
    select('cast_h3_v1',support,42,'All124 originals and enlarged root-wrist contact reviewed. Single physical near-root-fist gesture to the original heartwood disk and recovery. Other arm and rear legs support the mass. Shorten long hold; no spellcasting, props or idle alias.',38)
    death=[0,4,6]+list(range(8,31,2))+[36,42,48,50,52,54,56]+list(range(58,79))+[84,90,102,116,123]
    select('death_h3_v2',death,42,'All124 originals and enlarged support/side landing reviewed. Correct physical kneel/side-rest guide contacts once, then retain continuous original lowering, root-arm loss of support, side landing and settling. Original body/head/disk stay recognizable and attached roots rest beside torso. Hold original corpse123. First take rejected for flung fists and contact overshoot; native-scale acceptance still required.')
    d=json.loads((p.SOURCE_DIR/'delivery.json').read_bytes());d['takes']=['move_h3_v1','attack_h3_v2','hit_h3_v1','defend_h3_v1','cast_h3_v1','death_h3_v2'];p.write(p.SOURCE_DIR/'delivery.json',d)
    p.assemble()
