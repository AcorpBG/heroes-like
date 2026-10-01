"""Observed source phases only; correct failed action intervals separately."""
import json
import produce as p

def select(take,indices,msec,note,contact=None):
    out=p.SOURCE_DIR/take
    s=dict(source_frames=indices,frame_msec=msec,review_note=note)
    if contact is not None:s['contact_frame']=indices.index(contact)
    p.write(out/'selection.json',s)
    p.build(out,json.loads((out/'config.json').read_bytes()))

def main():
    select('move_h3_v1',list(range(30,42)),42,'One complete observed reciprocal running cycle,30-41;42 matches next contact. Both leg chains alternate loading/passing/extension, right hand retains pipe and left spares, cloak follows gait. Fixed original body scale and root; no reversed or interpolated padding.')
    select('hit_h3_v2',[0,12]+list(range(14,28))+[32,62,82]+list(range(84,104)),35,'Corrected knee/chest recoil14-27 with left spare bundle drawn close, then84-103 balance recovery. Same short original pipe retained down-left and point length remains fixed; no firing. Condense long recoiled hold; original physical phases only.',26)
    select('defend_h3_v1',[0,8]+list(range(10,38)),40,'Complete original brace0-37 into two spaced pipe grips and low crouched guard. End on37 before the rejected unrelated firing38 onward. Final guard held; no projectile, padded hold or return to idle.',35)
    select('cast_h3_v1',[0,8]+list(range(10,23))+[32,62]+list(range(66,83)),40,'Physical support gesture: original left hand raises three spare needles to shoulder, nod/hold, then lowers; original right hand retains pipe angled down-left. Both boots planted, two arms, same hood/quiver/vials. Condense long shoulder hold; preserve every changing rise/return pose.',62)
    select('attack_h3_v1',[0,12]+list(range(14,27))+[32,40]+list(range(44,50))+[53,62]+list(range(77,98,2))+list(range(98,114)),35,'Original two-handed pipe raise14-26, rigid shove44-49, held contact49/53/62 and77-113 retraction/lowering. Reject malformed settling50-52;49 and53 have matching body/grips and normal attached point, with no active thrust phase removed. The rejected second take is preserved. No emitted projectile or synthetic bridging.',48)
    select('death_h3_v2',[0,20]+list(range(22,39))+[62,72]+list(range(74,96))+[123],40,'Original continuous knee buckle22-38 and side collapse74-95 with cloak settling, two original leg/arm chains and horizontal pipe resting beside grounded head-right corpse123. Condense the long intermediate knee hold. Safe measured green plate, unchanged body scale/root; retain dense fast descent frames.')

if __name__=='__main__':main()
