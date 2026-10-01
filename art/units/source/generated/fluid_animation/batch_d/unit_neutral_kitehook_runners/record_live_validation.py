"""Record actual completed live source/runtime checks without changing art."""
import json
import produce as p

path=p.SOURCE_DIR/'delivery.json'
delivery=json.loads(path.read_bytes())
delivery['live_validation']={
    'isolated_profile_import_exit_code':0,
    'fixture':'tests/fluid_creature_animation_regression.py --live --unit unit_neutral_kitehook_runners --overview-only --render',
    'contacts_only':False,'exit_code':0,'checks':160,'failures':[],
    'original_rgb_frames_verified':744,'published_source_frames_verified':79,
    'preserved_idle_frames':8,'other_catalog_rows_unchanged':231,
    'published_atlas_size':[2368,3120],'rgba_bytes':29552640,
    'coverage':'Unmodified shared full fixture: authored timing/contacts, Normal/Fast/reduced, audio/VFX, session/save equality, actual BattleShell input/finish/focus/committed-save equality, live imported atlas dimensions, real map shader frame changes and reduced-motion pixel stability.',
    'visual_review':'All live native phases, three actual BattleShell captures, and map-idle phases inspected. Continuous source/retimed playback unavailable; no continuous preview claim.',
    'scope':'Exactly four new actions plus preserved original idle8; move and hit remain rejected v1 and unsubmitted corrections.'}
p.write(path,delivery)
