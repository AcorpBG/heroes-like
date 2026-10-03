# RMG reverse-engineering evidence storage

Local reverse-engineering evidence belongs under `.artifacts/rmg_recovery/`.
It remains ignored and excluded from releases. A clone or pull does not supply
these files. Preserve traces, disassembly, Ghidra databases, reference inputs,
maps, saves and provenance; directory names alone do not establish disposability.

## Layout

- Existing recovery subdirectories: original decompiler exports, traces,
  private-state payloads and recovery summaries. Their file contents are unchanged.
- `ghidra_project/h3maped_rmg_recovery.gpr` and its adjacent `.rep` directory:
  the original Ghidra analysis project. Keep both together.
- `support/`: the formerly separate H3MapEd reference runs, seed58 private traces,
  historical native comparison runs and supporting research files. Names beneath
  this directory retain their original identities.
- `storage/restore-20261003/`: the original server hash manifest, reference-map
  snapshot, shared reference inputs, Linux link definitions and separate copies
  of two files that differed locally. Existing local versions were preserved.
- `storage/consolidation-20261003/`: the current integrity manifest, exact old/new
  path map, relocation journal and itemized cleanup receipt.

The source was `root@pleyc.com:/root/dev/heroes-like` at
`32ed167aac8b8a6c3fdee732a507320efadf6a06`. The server was not changed or pulled.
The consolidated manifest covers 22,899 retained files / 11,212,692,907 bytes;
all passed SHA-256 read-back after relocation. Evidence payloads and historical
records keep their original bytes, including embedded historical paths. Use
`path-map.json` to translate those paths; current tool defaults and tracked
recovery references use the consolidated locations.

## Verification and platforms

From the repository root, run:

```text
python tools/verify_rmg_evidence.py
```

This read-only verifier works with Windows and Linux paths and fails on missing,
changed, duplicated or escaping manifest entries. Its integrity and containment
tests and the restored binary/trace checks were run on Windows. Linux/Wine replay
was not run. An existing Linux checkout must relocate its evidence using the
recorded path map before using the updated defaults; its server files still use
the original layout. Preserve its full Wine installation when migrating there.

Windows could not create the original Linux symlinks. Their definitions remain
in `storage/restore-20261003/remote-symlinks.json`, with the four LOD inputs and
referenced executable stored once in `shared-reference-data/`. Reconnect these
inputs and provision Wine when preparing a replay environment.

## Cleanup boundary

The consolidation removed 42 reviewed disposable files (155,851,175 bytes):
generic game-export validation reports/logs, two packaged native binary copies,
and obsolete one-time restore scaffolding. Production build tooling, all source
evidence, reference maps, saves, caches and the original server copies remain.
Other pre-existing art, caches and unrelated local work were not swept.

Temporary game validation/export output defaults stay outside the protected
recovery tree. Clean those outputs after validation under `AGENTS.md`; do not
start treating everything inside `support/` as disposable. Restoration and
consolidation do not establish native RMG parity or implementation completion.
Follow `docs/lessons-learned.md` before using this material for native changes.
