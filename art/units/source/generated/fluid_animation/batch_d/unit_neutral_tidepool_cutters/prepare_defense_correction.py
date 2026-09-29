"""Correct background drift using original chroma guides; retain clean hit motion."""
import json
import produce as p

out=p.SOURCE_DIR/'defend_h3_v2'
out.mkdir(exist_ok=False)
c=json.loads((p.SOURCE_DIR/'defend_h3_v1/config.json').read_bytes())
c.update(seed=2026092962,guides=[[45,1],[90,1]])
c['prompt']+=' Keep the exact bright saturated magenta plate visible at every instant; no fade to black or change of background lighting. The only movement is the woman raising her two blades and settling into the original crouch.'
p.prepare(out,c)
p.write(out/'config.json',c)
p.write(p.SOURCE_DIR/'defend_h3_v1/rejection.json',dict(status='rejected',reason='Full original chronology reviewed. Background fades to near-black during the brace, overlapping dark hair, boots and coat. No threshold relaxation or guessed matte. Repeat with original bright chroma crouch guides during the take.'))

out=p.SOURCE_DIR/'hit_h3_v1'
indices=list(range(22,31))+[34,38,42]+list(range(45,73))
p.write(out/'selection.json',dict(source_frames=indices,frame_msec=32,review_note='Full chronology and enlarged22/23/24/28/40/48/56/68 reviewed. Discard invented incoming beam16..21; clean22..72 contains continued backward recoil, weighted two-boot balance and original return with both blades retained. Shorten held recoil with original samples only. Native-scale review pending.'))
p.write(out/'rejection.json',dict(status='full_take_rejected_valid_interval_retained',reason='Invented projectile and overlapping flash16..21 excluded entirely. No erasure of overlapping subject pixels. Effect-free recoil/recovery22..72 retained for native review.'))
p.build(out,json.loads((out/'config.json').read_bytes()))
