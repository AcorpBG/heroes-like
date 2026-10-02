"""Download pinned official matting weights into isolated H: cache."""
import hashlib,json,subprocess,sys,urllib.request,os
from pathlib import Path
BASE=Path(os.environ.get('HEROES_MATTING_ROOT','H:/ai/minimax-h3/matting' if os.name=='nt' else '~/.cache/heroes-like/matting')).expanduser()
BASE.mkdir(parents=True,exist_ok=True)
DEPS=BASE/'dependencies';DEPS.mkdir(exist_ok=True)
subprocess.run([sys.executable,'-m','pip','download','--no-cache-dir','--no-deps','timm==1.0.30','--dest',str(DEPS)],check=True)
from huggingface_hub import snapshot_download
REV='eccde0a8cbdce7ac5fecfeb06340fe7b949e85d9'
MODEL=BASE/'BiRefNet-matting'
snapshot_download('ZhengPeng7/BiRefNet-matting',revision=REV,local_dir=MODEL,cache_dir=BASE/'hf-cache',allow_patterns=['config.json','BiRefNet_config.py','birefnet.py','model.safetensors','README.md'])
items={p.name:dict(bytes=p.stat().st_size,sha256=hashlib.file_digest(p.open('rb'),'sha256').hexdigest()) for p in [*(MODEL/n for n in ['config.json','BiRefNet_config.py','birefnet.py','model.safetensors','README.md']),*DEPS.glob('timm*.whl')]}
(BASE/'model_manifest.json').write_text(json.dumps(dict(repository='ZhengPeng7/BiRefNet-matting',revision=REV,model_directory=str(MODEL),dependency_directory=str(DEPS),files=items),indent=2)+'\n')
print(json.dumps(items))
