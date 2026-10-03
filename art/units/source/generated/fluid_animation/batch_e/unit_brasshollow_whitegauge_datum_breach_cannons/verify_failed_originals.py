"""Verify retained rejected footage without promoting it into any clip."""
import hashlib,json
import av
import produce as p

if __name__=='__main__':
 count=0
 for name in json.loads((p.SOURCE_DIR/'delivery.json').read_bytes())['failed_takes']:
  take=p.SOURCE_DIR/name;record=json.loads((take/'original.json').read_bytes())
  assert p.sha(take/'original_lossless.mkv')==record['sha256']
  with av.open(str(take/'original_lossless.mkv')) as video:
   hashes=[hashlib.sha256(f.to_image().convert('RGB').tobytes()).hexdigest() for f in video.decode(video=0)]
  assert len(hashes)==124 and hashes==record['decoded_rgb_sha256'];count+=len(hashes)
  assert not (take/'handoff.json').exists(),name
  for guide in json.loads((take/'reference.json').read_bytes())['guides']:
   assert p.sha(take/guide['input_file'])==guide['input_sha256']
   assert p.sha(p.ROOT/guide['source_frame']['source'])==guide['source_sha256']
 print('Rejected original RGB poses retained and verified:',count)
