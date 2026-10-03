# RMG reverse-engineering evidence storage

The tracked recovery code and ledgers depend on local evidence that Git does not
carry. `.artifacts/` and `tmp/` are ignored. A clone or pull does not restore their
contents; ignoring a directory does not delete it. Preserve RMG evidence in these
directories during cleanup, including historical traces and Ghidra projects.

## Verified restore

Restored 23,085 files (11,320,919,416 bytes, 10.543 GiB); 1,160 files were already
identical. All 24,245 selected regular files passed local SHA-256 read-back against
the server manifest. All 330 explicit evidence references checked across six key
recovery ledgers exist locally. The main `.artifacts/rmg_recovery/` tree contains
all 19,122 server regular files (5.644 GiB). Two differing local inspection files
were preserved, with the server versions saved separately.

## Local recovery locations

The 2026-10-03 restore reads `root@pleyc.com:/root/dev/heroes-like`, whose source
checkout is `32ed167aac8b8a6c3fdee732a507320efadf6a06`. It copies evidence without
pulling that checkout's old Git history or replacing differing local files.

- `.artifacts/rmg_recovery/`: decompiler exports, disassembly, private-state
  traces, recovered payloads, reference runtimes and recovery summaries.
- Other `.artifacts/rmg_*`, native RMG, H3MapEd, disassembly and related probe
  paths: supporting reference runs and comparison evidence, at original paths.
- `tmp/rmg_recovery/ghidra_project/h3maped_rmg_recovery.gpr` and the adjacent
  `.rep` directory: the original Ghidra analysis project. Keep both together.
- `.artifacts/rmg-restore-20261003/reference-maps/maps/`: the server's historical
  reference map snapshot, kept outside the current game's map catalogue.
- `.artifacts/rmg-restore-20261003/shared-reference-data/`: the four shared LOD
  inputs and the separately referenced H3MapEd executable from `/root/Downloads`.

The restore directory retains `manifest.json` (source paths, local destinations,
sizes, timestamps and SHA-256), `transfer-plan.json`, `verification.json`, and
`conflicts.json`. Differing server copies are under its `conflicts/` directory;
the existing local versions stay in place. The task's `restore.py verify` command
checks all selected regular-file contents against the remote hash manifest.

`remote-symlinks.json` preserves the Linux link definitions. File symlinks cannot
be created with the current Windows privileges, so their shared data is stored
once in `shared-reference-data`; the Linux absolute paths are not installed as
Windows links. A Linux replay environment must reconnect the recorded inputs and
provision Wine. This restore does not claim that every historical harness runs
unchanged on Windows.

Rebuildable exported game packages, Wine system files, and the downloadable
Ghidra application distribution are not part of the evidence restore. Their
server copies remain untouched. The Ghidra analysis database itself is retained.
`excluded-rebuildable.json` records the package and Wine-file exclusions.

Keep this bulk material outside Git and release packages. Future clones need an
explicit evidence restore from a retained source such as the server; a successful
Git pull is not evidence that these recovery inputs exist locally. Restoration
is a storage operation and does not change native RMG implementation or parity
status. Follow `docs/lessons-learned.md` before using these materials.
