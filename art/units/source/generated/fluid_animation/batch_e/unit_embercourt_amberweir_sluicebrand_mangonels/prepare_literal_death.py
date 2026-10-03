"""CPU-only literal conditioning for the unsampled original collapse."""
import json
import produce as p
out=p.SOURCE_DIR/'death_h3_v1'
assert not (out/'sampling_submission.json').exists()
c=json.loads((out/'config.json').read_bytes())
identity=json.loads((p.SOURCE_DIR/'unit_brief.json').read_bytes())['identity']
c['prompt']=identity+" One continuous physical lowering and final rest of original wood machine AND BOTH original adult humans. Original wooden chassis fractures downward, the original three axles buckle, three original wheels tip and splay on their same hubs, the single throwing arm folds into the broken original wood frame. Each original person releases his original grip, bends the same knees to the original kneeling38 reference, lowers hips and connected shoulders/elbows beside his own station and comes fully prone on the same floor82. Viewer-left original pump person and viewer-right original rope person both remain separately visible, with their own two connected arms and two legs, original red cloth, brass helmet/red plume and brown boots. Original brass counterweight, glass pumps and three gauges settle among their own original broken wood and three grounded wheels. The single original stone remains beside its original cup as its contained warm color gradually darkens into the cold stone of the original grounded82 reference. Finish110 through123 in the original cold grounded wreck: BOTH original people fully prone, all original hardware still, cold dark stone. Keep complete two-person physical group and original hardware inside960x544 with generous margins. Fixed original three-quarter orthographic camera, original body scale and perspective throughout. Uniform flat magenta RGB255,0,255 backdrop. Steady original painted material colors; physical wood, brass, original cloth and people only."
p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
print('ORIGINAL_LITERAL_COLLAPSE_CPU_READY',flush=True)
