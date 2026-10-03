"""Record personal key review and prospective crawl selection, not acceptance."""
import json
import produce as p

def main():
    registration=p.SOURCE_DIR/'attack_closed_registration.json'
    row=json.loads(registration.read_bytes());row['visual_review']='personally reviewed original full RGBA, native128 and enlarged2x, normal/reflected, dark/light; same torso/eye/carapace scale and ground origin. Both claws and all visible walking-foot tips complete. Original closed master qualifies as H3 guide only; animation not yet accepted.'
    p.write(registration,row)
    generated=p.SOURCE_DIR/'attack_closed_guide_v2/original.generation.json';g=json.loads(generated.read_bytes());g['review']=row['visual_review'];p.write(generated,g)
    p.write(p.SOURCE_DIR/'move_h3_v1/selection.json',dict(source_frames=list(range(20,100,2)),frame_msec=50,review_note='Forty chronological original poses spanning a complete reciprocal crawl cycle, original A contact20 through passing40, opposite B contact60, passing80 and back toward A100. Every124 RGB, enlarged alpha and native128 normal/reflected original inspected; full extracted RGB remains unchanged. Provisional50ms retime; native engine loop and cadence still pending. No duplicated or reversed frames.'))
    print('ORIGINAL CLOSED KEY QUALIFIED; CRAWL CANDIDATE40; NO RUNTIME ACCEPTANCE')

if __name__=='__main__':main()
