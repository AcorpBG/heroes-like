# Large Map Town Construction And End Turn Performance

Owner request: profile Large-map building construction and End Turn because both remain too slow. Phase 6 slice: `performance-large-town-build-and-end-turn-20260905`.

Measure an actual successful purchase through Town's construction ledger, not only town entry or view-model assembly. Include selection/confirmation, core mutation, refresh, integrated scene update and feedback. Measure full End Turn request/confirmation, simulation, autosave and usable refreshed UI. Separate the major buckets and name the hot functions.

Use deterministic 108x108 generated sessions, beginning with `large-runtime-profile-10225`, Veilmourn/Orso, signature `7362cf00`, and representative subsequent build/turn states. Keep gameplay resources and build eligibility real; synthetic cases, if needed, must be explicitly labelled. Record hardware/engine, full wall time and meaningful command results; keep benchmarking isolated from exports and other heavy tests.

Any owner-approved optimization must remove redundant computation or allocation, not skip gameplay, change AI policy, drop save fields, weaken transaction recovery or defer the stall outside the measured interval. Preserve town costs/requirements/unlocks, daily progression, enemy choices, source object records, pathing, named/legacy saves and version 9. Use baseline state outputs and matched controls to prove equivalence; profile-disabled normal play must retain the same behavior.

Validation for implementation: focused Python-owned before/after runner; existing town build/progression, End Turn confirmation/stale-state, AI/path, save/recovery tests as affected; `python3 tests/validate_repo.py`; `git diff --check`; serial `python3 tests/packaging_linux_export_smoke.py` and `python3 tests/packaging_windows_export_smoke.py`, including packaged map/Town entry. Both PCKs remain below 250000000 bytes. Update a concise source-backed report and complete the tracker only when the selected behavior and validation are real.

Out of scope: Native RMG generation changes, balancing, visual redesign, copied/new art, save-schema migration, package-limit changes, unrelated cleanup and release certification.
