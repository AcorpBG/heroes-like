"""Calibrate original lying-body ground contact before death submission."""
import json
import produce as p
from prepare import reference

if __name__=='__main__':
 out=p.SOURCE_DIR/'death_h3_v1';assert not (out/'sampling_submission.json').exists(),'Submitted original is immutable'
 c=json.loads((out/'config.json').read_bytes());c['references'][3]=reference(13)
 c['prompt']=c['prompt'].replace('Near right hand keeps stock/trigger grip; far left hand supports forward barrel.','At initial ready, near hand grips stock/trigger and far hand supports barrel. Both hands naturally release the same rifle during the original falling guide; it settles intact in front of the corpse.').replace('exact two grips','original two hands and initial grips')
 c['prompt']=c['prompt'].replace('Fixed boot contact plane y576. Planted boots stay grounded;','Fixed anatomical ground reference y576. Initial boots planted; fallen body and dropped rifle settle into the original projected corpse footprint with near forearm/body contact grounded. Fallen boots and foreground rifle/tag need not share one image y;')
 p.write(out/'config.json',c);p.prepare(out,c);p.verify(out,c)
 registration=json.loads((p.SOURCE_DIR/'runtime_registration.json').read_bytes());registration['corpse_guide']=c['references'][3]
 registration['corpse_reference_review']='Original fall guide explicitly releases the rifle. Lying-body/near-forearm contact is grounded; the dropped rifle/tag projects26 reference pixels in front/below, instead of using lowest tag as body ground. Whole original reference adjusted once before sampling; unchanged960x640 canvas, .5 extraction and480,576 video ground. Complete tag remains inside source margin.'
 p.write(p.SOURCE_DIR/'runtime_registration.json',registration)
