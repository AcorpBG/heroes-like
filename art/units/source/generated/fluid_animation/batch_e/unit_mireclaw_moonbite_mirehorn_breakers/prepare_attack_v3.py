"""Preserved original guides, with space for a continuous quiet thrust."""
import json
import produce as p
if __name__ == '__main__':
 old=p.SOURCE_DIR/'attack_h3_v2';out=p.SOURCE_DIR/'attack_h3_v3'
 assert not out.exists();out.mkdir()
 c=json.loads((old/'config.json').read_bytes())
 c['seed']=2026110352;c['guides']=[[24,1],[70,2]]
 c['prompt']+=' Gradual connected four-paw movement throughout. Ease from ready into the low crouch, progressively straighten the hind-paw joints as the shoulders and horned head lean forward into the supplied forward posture, then ease the weight backward and lift into ready. Each part of the body follows the same continuous movement, including mantle, attached lamps, staff and handler. Smooth intermediate grounded postures connect the supplied crouch and forward posture over the whole interval between them.'
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
 p.write(out/'correction.json',dict(rejected_take='attack_h3_v2',original_rgb_reviewed=124,alpha_reviewed=124,native_and_reflected_selected_reviewed=35,defect='Repeated reference holds freeze windup through47 then substitute full contact at48; no continuous thrust.',change='Same original ready/windup/four-paw contact, original painting scales, anchor and all model/quality settings. Two separated non-repeated intermediate guides24 and70 replace six repeated holds, allowing46 original frames for connected movement. Continuous grounded positive motion wording.',acceptance='Pending complete original RGB/alpha and enlarged/native review; do not publish this preparation.'))
 print('PREPARED_QUIET_CONTINUOUS_ATTACK_V3',flush=True)
