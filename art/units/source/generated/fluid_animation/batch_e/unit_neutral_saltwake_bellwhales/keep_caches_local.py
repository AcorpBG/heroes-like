"""Untrack only this unit's byte-proven Python caches, retaining local files."""
import json
from pathlib import Path
import produce as p
from commit_selected import git
from creature_animation_lock import exclusive

assert json.loads((p.SOURCE_DIR / 'completion.json').read_bytes())['status'] == 'complete_selected_unit'
with exclusive('git'):
    assert git('branch', '--show-current').decode().strip() == 'main'
    cache_dir = p.SOURCE_DIR / '__pycache__'
    relative = cache_dir.relative_to(p.ROOT).as_posix()
    files = git('ls-tree', '-r', '--name-only', 'HEAD', '--', relative).decode().splitlines()
    assert len(files) == 5 and all(f.startswith(relative + '/') and f.endswith('.pyc') for f in files)
    contents = {f: (p.ROOT / f).read_bytes() for f in files}
    assert all(git('show', 'HEAD:' + f) == raw for f, raw in contents.items())
    helpers = [(p.SOURCE_DIR / name).relative_to(p.ROOT).as_posix() for name in ['.gitignore', 'commit_selected.py', 'keep_caches_local.py', 'recover_empty_git_lock.py']]
    # Resume only this exact own partial transaction, never foreign staging.
    staged_before = git('diff', '--cached', '--name-only').decode().splitlines()
    assert set(staged_before) <= set(files + helpers), staged_before
    for path in staged_before:
        if path in files:
            assert git('diff', '--cached', '--name-status', '--', path).decode().strip() == 'D\t' + path
        else:
            assert git('show', ':' + path) == (p.ROOT / path).read_bytes()
    tracked = git('ls-files', '--', relative).decode().splitlines()
    assert set(tracked) <= set(files)
    if tracked:
        git('rm', '--cached', '--', *tracked)
    git('add', '--', *helpers)
    assert set(git('diff', '--cached', '--name-only').decode().splitlines()) == set(files + helpers)
    assert all((p.ROOT / f).read_bytes() == raw for f, raw in contents.items())
    git('commit', '--quiet', '-m', 'Keep Bellwhale Python caches local')
    sha = git('rev-parse', 'HEAD').decode().strip()
    print('CACHE_ONLY_FOLLOWUP_COMMIT', sha, flush=True)
    git('-c', 'http.version=HTTP/1.1', '-c', 'http.postBuffer=1073741824', 'push', 'origin', 'main')
    assert not git('diff', '--cached', '--name-only').strip()
    assert all((p.ROOT / f).read_bytes() == raw for f, raw in contents.items())
    assert not git('status', '--short', '--', p.SOURCE_DIR.relative_to(p.ROOT).as_posix()).strip()
    print('CACHE_ONLY_FOLLOWUP_PUSHED_LOCAL_BYTES_PRESERVED', sha, len(files), flush=True)
