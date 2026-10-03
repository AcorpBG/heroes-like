"""Close actual reviewed results without changing delivered pixels or timings."""
import json
import produce as p
from creature_animation_lock import exclusive

uid = 'unit_mireclaw_moonbite_mirehorn_breakers'
reviews = p.ROOT / '.artifacts/parallel_animation_20261002' / uid
for case in ['candidate/native', 'candidate/mirror', 'live/native', 'live/mirror']:
    lines = (reviews / case / 'console.log').read_text(encoding='utf-8').splitlines()
    reports = [json.loads(line.split('FLUID_ANIMATION_REPORT ', 1)[1]) for line in lines if line.startswith('FLUID_ANIMATION_REPORT ')]
    assert len(reports) == 1 and not reports[0]['failures'], case
assert 'MIREHORN_BREAKER_IMPORTED_ATLAS_OK' in (reviews / 'import/pixels.log').read_text(encoding='utf-8')
review = json.loads((p.SOURCE_DIR / 'source_review.json').read_bytes())
assert review['live_personal_visual_review']['passed']
with exclusive('content'):
    catalog = p.ROOT / 'content/unit_animation_manifest.json'
    map_catalog = p.ROOT / 'art/overworld/creature_idle.json'
    catalogs_before = [catalog.read_bytes(), map_catalog.read_bytes()]
    published = p.ROOT / 'art/animation/source/fluid' / uid
    old = json.loads((published / 'reviewed_handoff.json').read_bytes())
    delivery = json.loads((p.SOURCE_DIR / 'delivery.json').read_bytes())
    notes = delivery['visual_review']['notes'].replace('Imported/live checks still pending.', 'Imported RGBA and both published live action routes passed; actual normal/Fast/reduced/static/dead/contact/interrupt/RNG/save and animated/reduced map checks are recorded in completion.json.')
    delivery['visual_review']['notes'] = notes
    p.write(p.SOURCE_DIR / 'delivery.json', delivery)
    p.assemble()
    new = json.loads((p.SOURCE_DIR / 'handoff.json').read_bytes())['units'][0]
    before = old['units'][0]
    assert before['frames'] == new['frames'] and before['clips'] == new['clips']
    before['visual_review'] = new['visual_review']
    before['provenance'] = new['provenance']
    provenance = json.loads((published / 'provenance.json').read_bytes())
    atlas = p.ROOT / 'art/animation/runtime/fluid' / (uid + '.png')
    assert provenance['atlas_sha256'] == p.sha(atlas)
    provenance['review'] = new['visual_review']
    p.write(published / 'reviewed_handoff.json', old)
    p.write(published / 'provenance.json', provenance)
    assert [catalog.read_bytes(), map_catalog.read_bytes()] == catalogs_before
    assert provenance['atlas_sha256'] == p.sha(atlas)
print('ACTUAL_REVIEW_CLOSED_PIXELS_AND_TIMINGS_UNCHANGED', flush=True)
