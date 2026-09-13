#!/usr/bin/env python3
"""Validate published audio and exercise Godot's actual audio owners.

Python owns this test; its temporary GDScript harness is an execution adapter.
Requires numpy/soundfile for signal checks and Godot 4.6 for --godot.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art/audio/source/stable_audio_3_v1'


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def validate_manifest(path):
    manifest = read(path)
    assert manifest['legacy_regeneration_protected'] is True
    assert manifest['sample_rate_hz'] == 44100 and manifest['channel_count'] == 2
    assert manifest['production_status'] in {'technical_checks_passed_listening_review_pending', 'accepted'}
    if manifest['production_status'] == 'accepted':
        approval = manifest['listening_acceptance']
        assert approval['reviewer'] == 'owner' and approval['date']
        assert approval['evidence'] == 'docs/audio-production-implementation.md'
    for cue in manifest['cues'].values():
        asset = ROOT / cue['path'].removeprefix('res://')
        assert asset.is_file(), asset
        assert -60 <= cue['volume_db'] <= 0
        if '/production/' in cue['path']:
            assert hashlib.sha256(asset.read_bytes()).hexdigest() == cue['sha256'], asset
            provenance = read(ROOT / cue['provenance'].removeprefix('res://'))
            assert abs(cue['duration_msec'] - provenance['edit']['runtime_statistics']['seconds'] * 1000) <= 1
    return len(manifest['cues'])


def validate_assets(signals=True):
    if signals:
        import numpy as np
        import soundfile as sf
    jobs = read(SOURCE / 'jobs.json')['jobs']
    assert len(jobs) == 520 and len({j['id'] for j in jobs}) == 520
    hashes = set()
    duration = 0.0
    for job in jobs:
        r = read(SOURCE / 'provenance' / (job['id'] + '.json'))
        assert r['status'] == 'technical_checks_passed'
        assert r['model_revision'] == '96fc663283cde94cb631bc84f6c9ece7bbe2bf25'
        for key in ['source', 'master', 'runtime']:
            p = ROOT / r[key + '_path'].removeprefix('res://')
            assert p.is_file(), p
            assert hashlib.sha256(p.read_bytes()).hexdigest() == r[key + '_sha256'], p
        assert r['runtime_sha256'] not in hashes, job['id']
        hashes.add(r['runtime_sha256'])
        if job['category'] in ['music', 'stingers']:
            assert '_orchestral_' in job['id'] and 'orchestra' in job['prompt'].lower()
        if signals:
            wave, rate = sf.read(p, always_2d=True, dtype='float32')
            seconds = len(wave) / rate
            assert rate == 44100 and wave.shape[1] == 2 and np.isfinite(wave).all(), p
            assert float(np.max(np.abs(wave))) < .98, p
            assert float(np.sqrt(np.mean(wave**2))) > .00001, p
            assert seconds >= .06, p
            if job['loop']:
                assert seconds > (40 if job['category'] == 'music' else 55), p
                assert float(np.max(np.abs(wave[0] - wave[-1]))) < .08, p
            duration += seconds
    for name in ['ui_sfx','presentation_sfx','battle_sfx','ambient_sfx','music_runtime']:
        validate_manifest(ROOT / 'content' / (name + '_manifest.json'))
    music = read(ROOT / 'content/music_runtime_manifest.json')['cues']
    assert sum(c.get('playback_mode') == 'full_mix' for c in music.values()) == 25
    palette = read(ROOT / 'content/audio_production_banks.json')
    assert len(palette['cues']) == 430 and len(palette['banks']) == 170
    assert set(palette['unit_profiles']) == {u['id'] for u in read(ROOT/'content/units.json')['items']}
    assert set(palette['spell_banks']) == {s['id'] for s in read(ROOT/'content/spells.json')['items']}
    for profile in palette['unit_profiles'].values():
        for gesture in ['move','attack','hit','defeat']:
            assert profile['body_bank'] + '_' + gesture in palette['banks']
        for key in ['weapon_bank','impact_bank']:
            assert not profile[key] or profile[key] in palette['banks'], profile
    for row in palette['spell_banks'].values():
        for gesture in ['cast','effect','expire']:
            assert not row[gesture] or row[gesture] in palette['banks'], row
    return {'jobs':len(jobs),'banks':len(palette['banks']),'seconds':round(duration,2),'signal_checks':signals}


HARNESS = r'''
extends SceneTree
var Palette
const Loader = preload("res://scripts/audio/RuntimeAudioLoader.gd")
var failures: Array = []
var checks := 0
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label)
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    Palette = load("res://scripts/audio/AudioPalette.gd")
    var music = root.get_node("MusicAudio")
    var ambient = root.get_node("AmbientAudio")
    var presentation = root.get_node("PresentationAudio")
    var settings = root.get_node("SettingsService")
    var content = root.get_node("ContentService")
    settings.settings = settings.build_default_settings()
    var manifest: Dictionary = content.load_json("res://content/music_runtime_manifest.json")
    for id in manifest.cues:
        if manifest.cues[id].get("playback_mode", "") != "full_mix": continue
        var layers: Array = music._layers_for_context("menu", id, {})
        check(layers.size() == 1, "one full mix " + id)
        check(Loader.load_stream(manifest.cues[id].path).get_length() > 40, "music length " + id)
    check(music._layers_for_context("menu", "missing_legacy_cue", {}).size() == 3, "legacy layered compatibility")
    music._music_runtime_manifest = manifest.duplicate(true)
    music._music_runtime_manifest.cues.music_menu_theme.path = "res://missing_audio_validation.ogg"
    var missing: Dictionary = music.sync_context("menu", "missing_full_mix", {})
    check(missing.layers.size() == 1 and missing.layers[0].generated_fallback_count == 1, "missing full mix has one fallback")
    music._music_runtime_manifest = manifest.duplicate(true)
    music.validation_reset()
    var first: Dictionary = music.sync_context("overworld", "test", {"day":1,"player_faction_id":"faction_embercourt"})
    check(first.layers.size() == 1 and first.layers[0].imported_asset_count == 1, "full mix imported")
    check(not music.sync_context("overworld", "test", {"day":3,"player_faction_id":"faction_embercourt"}).changed, "day does not restart music")
    music.sync_context("town", "test", {"town_faction_id":"faction_thornwake"})
    await create_timer(.5).timeout
    check(music.validation_summary().current_player_count == 1 and music.validation_summary().outgoing_player_count == 0, "crossfade frees old score")
    check(music.play_stinger("stinger_battle_win", "test_win").played, "stinger plays")
    await create_timer(.5).timeout
    check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MusicScore")) < -7, "score stays ducked")
    check(not music.play_stinger("stinger_battle_win", "test_win").played, "stinger event deduplicated")
    music.stop_stinger()
    await create_timer(.5).timeout
    check(abs(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MusicScore"))) < .01, "duck recovers")
    var palette: Dictionary = content.load_json("res://content/audio_production_banks.json")
    var all_cues: Dictionary = palette.cues.duplicate(true)
    for name in ["ui_sfx","presentation_sfx","battle_sfx","ambient_sfx","music_runtime"]:
        all_cues.merge(content.load_json("res://content/" + name + "_manifest.json").cues)
    for id in all_cues:
        var stream = Loader.load_stream(all_cues[id].path)
        check(stream != null, "runtime resource loads " + id)
        if stream != null:
            check(abs(stream.get_length() * 1000 - float(all_cues[id].duration_msec)) < 3, "imported duration " + id)
    var Catalog = load("res://scripts/core/AnimationCueCatalog.gd")
    check(Catalog.event_cue_catalog_report().ok, "audio catalog ownership is valid")
    for entry in content.load_json("res://content/animation_event_cues.json").entries:
        for cue in entry.audio_cue_ids:
            check(all_cues.has(cue), "catalog audio resolves " + cue)
    for event_id in ["overworld_object_idle", "overworld_object_ambient"]:
        check(Catalog.cue_playback_policy_for_event(event_id).selected_audio_cue_ids.is_empty(), "object idle leaves ambience to its owner")
    for terrain in ["grass","dirt","stone","bridge","mire","sand","snow","water","underground"]:
        check(Palette.select(Palette.ground_bank(terrain),0) != "", "ground bank exists " + terrain)
    check(Palette.ground_bank("dirt",1) == "move_underground", "underground movement has its own bank")
    check(Palette.ground_bank("water",1) == "move_shallow_water", "underground water retains wet footsteps")
    for id in palette.unit_profiles:
        for event_id in ["battle_unit_move","battle_unit_melee_attack","battle_unit_hit","battle_unit_death"]:
            var cues: Array = Palette.battle_cues({"event_id":event_id,"battle_id":"actor","serial":3},[{"battle_id":"actor","unit_id":id}],[])
            check(not cues.is_empty() and cues.size() <= 2, "unit route " + id + event_id)
            for cue in cues: check(not Palette.cue(cue).is_empty(), "unit cue exists")
    for id in palette.spell_banks:
        for gesture in ["cast","effect","expire"]:
            var bank: String = Palette.spell_bank(id, gesture)
            if bank != "": check(Palette.select(bank,0) != "", "spell bank " + id + gesture)
    check(Palette.battle_cues({"event_id":"battle_stack_idle"},[],["legacy"]).is_empty(), "idle silent")
    check(Palette.select("weapon_bow",0) != Palette.select("weapon_bow",1), "variants rotate")
    presentation.validation_reset()
    var effect: Dictionary = presentation.play_bank("weapon_bow", "test")
    check(effect.played and effect.duration_msec > 50 and effect.generated_fallback_count == 0, "effect file and lifetime")
    check(not presentation.play_bank("weapon_bow", "test").played, "cooldown covers variants")
    settings.settings.audio.effects_volume_percent = 0
    check(not presentation.play_bank("weapon_blade", "test").played, "effect mute")
    settings.settings.audio.effects_volume_percent = 75
    presentation.validation_reset()
    var objectives := {"objective": {"complete":false,"defeated":0}}
    presentation.observe_progress("test_session",1,[{"id":"hero","level":1}],objectives)
    presentation.observe_progress("test_session",1,[{"id":"hero","level":1}],objectives)
    check(presentation.validation_records().is_empty(), "refresh and baseline silent")
    presentation.observe_progress("test_session",2,[{"id":"hero","level":1}],objectives)
    check(presentation.validation_records().size() == 1, "committed day notification")
    presentation.observe_progress("test_session",2,[{"id":"hero","level":1}],objectives)
    check(presentation.validation_records().size() == 1, "day notification not repeated")
    objectives.objective.defeated = 1
    presentation.observe_progress("test_session",2,[{"id":"hero","level":1}],objectives)
    check(presentation.validation_records().back().cue_id.begins_with("production_notice_objective_update"), "structured objective progress")
    objectives.objective.complete = true
    presentation.observe_progress("test_session",2,[{"id":"hero","level":1}],objectives)
    check(presentation.validation_records().back().cue_id.begins_with("production_notice_objective_complete"), "structured objective completion")
    presentation.reset_progress()
    var count: int = presentation.validation_records().size()
    presentation.observe_progress("test_session",8,[{"id":"hero","level":4}],objectives)
    check(presentation.validation_records().size() == count, "restored progress establishes silent baseline")
    var Factory = load("res://scripts/core/ScenarioFactory.gd")
    var session = Factory.create_session("river-pass")
    var before: Dictionary = session.to_dict().duplicate(true)
    var snapshot: Dictionary = Palette.objective_snapshot(session)
    presentation.observe_session_progress(session)
    check(session.to_dict() == before, "audio observation preserves simulation and save state")
    check(not snapshot.purge_mire.complete, "authored objective initially incomplete")
    session.flags.mire_cleared = true
    check(Palette.objective_snapshot(session).purge_mire.complete, "objective snapshot follows committed state")
    check(root.get_node("UiAudio").play_cue("audio_placeholder_ui_invalid", "test").cue_id == "ui_invalid", "catalog invalid alias")
    var Board = load("res://scenes/battle/BattleBoardView.gd")
    var board = Board.new()
    root.add_child(board)
    board.validation_reset_audio_mix()
    var bow: String = Palette.select("weapon_bow",0)
    check(board.validation_play_audio_cue(bow).played, "battle owner imports bank cue")
    check(not board.validation_play_audio_cue(Palette.select("weapon_bow",1)).played, "battle owner shares bank cooldown")
    settings.settings.audio.effects_volume_percent = 0
    check(not board.validation_play_audio_cue(Palette.select("weapon_blade",0)).played, "battle owner respects mute")
    settings.settings.audio.effects_volume_percent = 75
    board.validation_reset_audio_mix()
    for bank in ["weapon_bow","weapon_blade","weapon_blunt","weapon_bolt","weapon_sling","weapon_thrown","weapon_siege","weapon_arcane","weapon_chain"]:
        board.validation_play_audio_cue(Palette.select(bank,0))
    check(board._active_audio_players.size() <= 8, "battle normal voice cap")
    settings.settings.accessibility.reduce_repetitive_sounds = true
    board.validation_play_audio_cue(Palette.select("impact_metal",0))
    check(board._active_audio_players.size() <= 4, "battle reduced voice cap")
    check(board._audio_mix_policy(bow).repeat_cooldown_msec == 280, "reduced bank cooldown")
    board.validation_reset_audio_mix()
    settings.settings.accessibility.reduce_repetitive_sounds = false
    board.queue_free()
    ambient.validation_reset()
    for faction in ["embercourt","mireclaw","sunvault","thornwake","brasshollow","veilmourn"]:
        var town: Dictionary = ambient.sync_town_context("faction_" + faction)
        check(town.layers.size() == 1 and town.layers[0].imported_asset_count == 1, "town ambience " + faction)
    ambient.stop_overworld_ambient("test_exit")
    check(ambient.validation_summary().active_player_count == 0, "ambient scene exit")
    var saves = root.get_node("SaveService")
    var router = root.get_node("AppRouter")
    # Retain the old progress baseline to exercise the router's reset, while
    # excluding notification records deliberately produced by earlier checks.
    presentation._records.clear()
    var save_name := "Audio validation " + str(Time.get_ticks_usec())
    session.day = 8
    session.overworld.hero.level = 4
    var saved: Dictionary = saves.save_runtime_file_session(session, save_name)
    check(bool(saved.get("ok", false)), "named save written in isolated profile")
    if bool(saved.get("ok", false)):
        var summary: Dictionary = saves.inspect_save_file(save_name)
        check(router.resume_summary(summary), "saved session resumes through app router")
        await create_timer(1.0).timeout
        var restored = root.get_node("SessionState").active_session
        check(restored.day == 8 and bool(restored.flags.get("mire_cleared", false)), "save preserves gameplay progress")
        check(current_scene != null and current_scene.scene_file_path == "res://scenes/overworld/OverworldShell.tscn", "resume enters the actual overworld")
        var notices: Array = presentation.validation_records().filter(func(row): return String(row.get("cue_id", "")).begins_with("production_notice_"))
        check(notices.is_empty(), "resume does not replay day, level or objective notices")
        check(music.validation_summary().current_player_count == 1, "resumed overworld plays one full mix")
    music.validation_reset()
    presentation.validation_reset()
    await process_frame
    print("AUDIO_RUNTIME_RESULT=" + JSON.stringify({"checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
'''


def validate_runtime(godot, pack=None):
    folder = ROOT / '.artifacts/audio-production' / ('package-test' if pack else 'runtime-test')
    folder.mkdir(parents=True, exist_ok=True)
    adapter = folder / 'audio_test.gd'
    adapter.write_text(HARNESS, encoding='utf-8')
    env = os.environ.copy()
    env['APPDATA'] = str(folder / 'profile')
    env['XDG_DATA_HOME'] = str(folder / 'profile')
    command = [godot,'--headless'] + (['--main-pack',str(Path(pack).resolve())] if pack else ['--path',str(ROOT)]) + ['--script',str(adapter)]
    # Packaged runs start outside the checkout and load the explicit pack, so a
    # source .godot cache cannot accidentally satisfy missing exported resources.
    proc = subprocess.run(command, cwd=folder, env=env, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=180)
    output = proc.stdout + proc.stderr
    (folder/'godot.log').write_text(output, encoding='utf-8')
    line = next((line for line in proc.stdout.splitlines() if line.startswith('AUDIO_RUNTIME_RESULT=')), '')
    assert line, output[-8000:]
    report = json.loads(line.split('=',1)[1])
    assert not report['failures'], report
    assert proc.returncode == 0 and 'SCRIPT ERROR' not in output, output[-8000:]
    return report


def validate_release(executable):
    executable = Path(executable).resolve()
    folder = ROOT / '.artifacts/audio-production/release-startup'
    folder.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env['APPDATA'] = env['XDG_DATA_HOME'] = str(folder / 'profile')
    proc = subprocess.run([str(executable), '--headless', '--quit-after', '60'],
                          cwd=executable.parent, env=env, capture_output=True,
                          text=True, encoding='utf-8', errors='replace', timeout=90)
    output = proc.stdout + proc.stderr
    for path in (folder / 'profile').rglob('godot.log'):
        output += path.read_text(encoding='utf-8', errors='replace')
    (folder / 'startup.log').write_text(output, encoding='utf-8')
    assert proc.returncode == 0, output[-6000:]
    assert not any(token in output for token in ['SCRIPT ERROR', 'Failed loading resource', 'GDExtension dynamic library not found', 'Parse Error']), output[-6000:]
    return {'executable': str(executable), 'exit_code': proc.returncode}


def validate_pack(pack):
    if str(ROOT) not in sys.path: sys.path.insert(0, str(ROOT))
    from tools.compact_export_pck import read_directory
    data = Path(pack).read_bytes()
    _, rows = read_directory(data)  # Also verifies every payload digest and bound.
    entries = {row.path: row for row in rows}
    assert not any('/source/' in path for path in entries), 'Source assets leaked into the export'
    for name in ['ui_sfx_manifest','presentation_sfx_manifest','battle_sfx_manifest',
                 'ambient_sfx_manifest','music_runtime_manifest','audio_production_banks']:
        path = 'content/' + name + '.json'
        row = entries[path]
        assert json.loads(data[row.offset:row.offset + row.size]) == read(ROOT / path), path
    jobs = read(SOURCE / 'jobs.json')['jobs']
    for job in jobs:
        provenance = read(SOURCE / 'provenance' / (job['id'] + '.json'))
        path = provenance['runtime_path'].removeprefix('res://')
        assert path in entries or path + '.import' in entries, path
    return {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
            'required_audio': len(jobs), 'source_assets_excluded': True}


def validate_repo_contracts():
    import importlib.util
    spec = importlib.util.spec_from_file_location('audio_repo_validation', ROOT / 'tests/validate_repo.py')
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    errors = []
    names = ['validate_runtime_audio_loader', 'validate_ui_audio_cue_runtime',
             'validate_presentation_audio_runtime', 'validate_overworld_ambient_audio_runtime',
             'validate_music_audio_runtime', 'validate_animation_event_cue_catalog']
    for name in names:
        getattr(module, name)(errors)
    assert not errors, '\n'.join(errors)
    return {'validators': names, 'failures': errors}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot')
    parser.add_argument('--runtime-pack', help='Run the audio harness against this exported PCK')
    parser.add_argument('--release-executable', help='Check the release binary startup without path overrides')
    parser.add_argument('--repo-contracts', action='store_true')
    parser.add_argument('--runtime-only', action='store_true')
    parser.add_argument('--no-signals', action='store_true')
    args = parser.parse_args()
    result = {}
    if not args.runtime_only: result['assets'] = validate_assets(not args.no_signals)
    if args.godot: result['runtime'] = validate_runtime(args.godot, args.runtime_pack)
    if args.runtime_pack: result['pack'] = validate_pack(args.runtime_pack)
    if args.release_executable: result['release_startup'] = validate_release(args.release_executable)
    if args.repo_contracts: result['repo_contracts'] = validate_repo_contracts()
    target = ROOT / '.artifacts/audio-production' / ('package-validation.json' if args.runtime_pack else 'validation.json')
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
