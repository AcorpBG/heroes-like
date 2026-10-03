from pathlib import Path
import json,hashlib
S=Path(__file__).parent;host=json.loads((S/'host_verification.json').read_bytes());R=next(p for p in S.parents if (p/'project.godot').exists());prior=json.loads((R/'art/units/source/generated/fluid_animation/batch_e/unit_thornwake_woundroot_rootmaul_behemoths/host_verification.json').read_bytes())
for item in host['models']:
 p=Path(item['path']);before=p.stat();assert before.st_size==item['bytes'] and before.st_mtime_ns==item['mtime_ns'];item['sha256']=hashlib.file_digest(p.open('rb'),'sha256').hexdigest();after=p.stat();assert after.st_size==before.st_size and after.st_mtime_ns==before.st_mtime_ns;assert item['sha256']==prior[p.name]['sha256'];print('EXACT_INSTALLED_MODEL_SHA',p.name,item['sha256'],flush=True)
(S/'host_verification.json').write_text(json.dumps(host,indent=2)+'\n')
master=json.loads((S/'landing_hawk_v1.generation.json').read_bytes());master['prompt']='landing_hawk_v1.prompt.txt';master['prompt_sha256']=hashlib.sha256((S/'landing_hawk_v1.prompt.txt').read_bytes()).hexdigest();(S/'landing_hawk_v1.generation.json').write_text(json.dumps(master,indent=2)+'\n')
