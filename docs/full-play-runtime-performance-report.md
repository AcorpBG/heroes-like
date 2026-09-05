# Full-play runtime performance review — 2026-09-05

Phase 6 slice: `performance-full-play-runtime-review-20260905`. Requirements: [full-play runtime performance requirements](full-play-runtime-performance-requirements.md). Control revision: `bd42b459102853f02d7b79174a0ccfc80b1dbf79`. **Implementation and scoped validation completed 2026-09-05; broader campaign, accessibility, balance and visual gaps remain explicitly below.**

## Runtime changes and reasons

- `ContentService._indexed_content_row`: index immutable authored catalogs by path/list/id field; borrow the original first-matching row, never a copied/generic fallback. Replacing the source list, changing its length, or `clear_cache()` invalidates the index. Arbitrary in-place changes to authored identifiers/list membership require `clear_cache()`; generated scenario draft ownership is unchanged. Coverage currently checks 2,828 content/art identities, missing IDs, duplicate-first semantics, alternate keys, borrowed rows and invalidation. Warm five-sample median lookup costs fall from 75–178 ms to about 4 ms per 2,000 calls. This is a lookup benchmark, not a game-wide speedup percentage.
- Active-play save bars: `BattleShell`, `OverworldShell` and explicit `TownShell._refresh_save_slot_picker` reuse the just-verified summary's canonical detail and ask `SaveService` not to construct two stored resume recaps these consumers never present. Battle/Town also stop eagerly inspecting the selected save as a dictionary-default argument. Slot freshness checks, current-state copy, writes, recovery, labels and tooltips remain. The projection defaults to the existing full surface for other consumers, including Outcome's displayed stored recap. Distinct methods extracted from the prior commit verify empty/saved/replaced slots with exact consumed copy and full-state parity.
- `OverworldShell._current_end_turn_warning`: a real Day-5 Large session showed warning inspection normalizing/reordering equal-label AI scouting memories. The second inspection inside request snapshot construction invalidated the pending state hash before Confirm, with no user action. Preserve the AI memory branch across read-only warning construction and reuse the already-built warning for the request snapshot. Do not change AI sort/policy or weaken the real mutation guard.
- `FrontierVisualKit`/`AppRouter`: release the static custom-cursor texture while RenderingServer is alive. The prior rendered exits reported one `CompressedTexture2D` and two texture RIDs; the focused rendered release/reload and shutdown test is clean.
- Battle confirmation teardown: clear embedded exclusivity before hiding, restore it while hidden, and let the existing Confirm handler own OK-time hiding. Actual OK/Cancel buttons preserve modality, cancel non-mutation and one-shot resolution. Godot 4.6.2 restores parent accessibility focus during subwindow removal before clearing the transient exclusive-child link; that could refocus the removed window. Source: [Window implementation](https://github.com/godotengine/godot/blob/4.6.2-stable/scene/main/window.cpp) and [Viewport implementation](https://github.com/godotengine/godot/blob/4.6.2-stable/scene/main/viewport.cpp).
- Controller selection: the physical right-stick test found River Pass's hero `(1,2)` reset to Riverwatch's entrance `(0,2)` by visual-body snapping; Up then snapped back to the same entrance. `_move_controller_route_cursor` and its reset now request exact tile selection. `_set_selected_tile` still defaults to the unchanged artwork-to-entrance resolution for pointer/object callers. Route rules, movement costs and town footprints do not change. The original exact preview/cancel/commit assertions are retained; this is a real input correction, not a relaxed test expectation.

No map-generation, placement, AI policy, combat balance, costs, art, version-9 save schema or package-ceiling changes.

## Play and controls

Python owns orchestration. `LiveValidationHarness` drives the real scenes and router: legal town purchases/recruitment, walking, resource/artifact collection, tactical orders and shipped Quick Resolve, casualty reports, required report-Continue saves, outcome, manual save and menu resume. Repairs to that existing driver open the lazy skirmish browser before checking population, acknowledge the now-mandatory casualty screen, and play River Pass's authored post-capture counterstroke before expecting victory. These driver repairs are not optimizations or gameplay changes.

The first full-arc attempt `final_campaign` reached 79 checkpoints, won River Pass, saved/resumed its outcome and carried progression into Causeway. It then hit the driver's fixed four-battle interruption cap after four **different** guard/raid victories (Reedward Camp, Reed Totemists, a Mireclaw raid, Lockflame Turncoats), not a runtime failure. The driver now budgets from live encounter ownership plus the destination and rejects a repeated resolved-key/encounter/position identity. No guards are removed and no battle result is injected. This failed attempt is retained and is not called a completed campaign arc.

`verified_campaign` reaches 112 checkpoints and wins/save-resumes River Pass and Causeway before entering/saving/resuming Fen Crown. Its route then loses a target during an actual AI turn; the existing resolved-placement predicate is now rechecked after travel as well as before. `campaign_complete_check` reaches 113 checkpoints and correctly observes that resolved placement, but the next planned Waystone Cache (`inner_cache`, `(8,0)`) is already collected in the real Day-3 autosave. The rigid driver cannot claim that consumed target and exits unsuccessfully. These runs prove two real chapter victories and progression/recovery coverage, not a completed three-chapter arc; no campaign/balance changes or artificial wins are made. The final attempt's top-level `errors` is empty because that existing optional claim helper returns its failed route without calling `_require`; its nonzero exit and `ok:false` are retained and rejected by the Python runner.

Focused final component controls: `battle_verified` (rendered, default backend, actual Quick Resolve/Retreat/Surrender OK and Cancel buttons, one-shot routing and cursor release/reload) and `save_projection_final` (headless Overworld/Town copy checks). Mean saved/replaced-slot refresh spans across six samples:

| Consumer | Old method | Current method | Reduction |
| --- | ---: | ---: | ---: |
| Battle | 421.065 ms | 21.852 ms | 94.8% |
| Overworld | 308.460 ms | 27.987 ms | 90.9% |
| Explicit Town save panel | 532.981 ms | 27.950 ms | 94.8% |

These are individual consumer method spans, not whole-action/game speedups. The Overworld/Town extension was made after `final_skirmish`; the later `verified_skirmish` below validates the combined code. `content_lookup/final` passes 2,828 identities and four five-sample lookup medians, 3.98–4.27 ms versus 77.76–181.94 ms per 2,000 calls. The final `content_lookup/final_complete` rerun additionally asserts source-array growth/removal invalidation: 2,828 identities and all checks pass, with 4.00–4.39 ms versus 76.02–188.35 ms lookup medians.

The opt-in authored-session identity `full_play_20260905:<mode>:<scenario>` replaces the initial uptime ID before gameplay so battle damage seeds are comparable. It does not add troops/resources, teleport, alter RNG rules or force victories. Initial launch autosave precedes that fixture identity; subsequent saves preserve it. Full session snapshots are captured outside command timers.

The preserved partial control `baseline_skirmish_ready` reached the winning town assault but its old driver incorrectly expected the outcome before the counterstroke. `indexed_skirmish` completed the 51-step skirmish/outcome/save-resume flow; all 42 shared complete session trees match exactly. That intermediate run still had the subsequently corrected native dialog focus error; its old script-only error classifier did not catch it. It is **not** the final clean validation pass. Final runners reject native `ERROR:` as well as script errors.

`verified_skirmish` completes all 51 steps on the final combined code with the default accessibility backend, zero native/script errors or leaked-RID messages. Its `matched_control_report.json` proves all **42 complete shared session trees equal**. Only the shared prefix's ordered action identities are timed against the partial old control; no whole-run duration speedup is claimed:

| Matched profile event | Count | Prior code | Final code | Reduction |
| --- | ---: | ---: | ---: | ---: |
| Battle refresh | 16 | 21.068 s | 8.245 s | 60.9% |
| Battle ready/entry | 6 | 11.163 s | 5.750 s | 48.5% |
| Town refresh | 10 | 1.885 s | 1.623 s | 13.9% |
| End Turn core event | 3 | 4.202 s | 3.578 s | 14.9% |
| Routed movement | 36 | 17.284 s | 16.723 s | 3.2% |

Timers are inclusive and overlap (entry includes first refresh). The comparison projects only action identity from nested metadata, excluding diagnostic timing/cache history, while checking the complete saved gameplay trees without any projection. The final renderer peak is 1,498,136 KiB versus 1,448,016 KiB for the shorter partial control; unequal run lengths do not support a memory comparison. The inspected 1920×1080 casualty captures preserve 5 friendly and 9 enemy losses, rewards, consequences and the required Continue control.

Large setup uses the unchanged native package signature `7362cf00`, seed `large-runtime-profile-10225`, 108×108, Veilmourn/Orso, four players. The driver clicks the actual owned-town visual body (remote management, hero position unchanged), uses legal available town orders, explores/visits visible resources, processes complete End Turns and any battles/report saves. Reference mode installs the exact prior ContentService script in the disposable test only, removing solely its duplicate global-class declaration. Full native generation and gameplay owners are identical between these lookup controls.

Early driver failures are retained under `.artifacts/full_play_runtime_20260905`: duplicate reference-class registration, routing toward a blocked native town anchor instead of clicking its visual body, and the reproduced Day-5 stale confirmation. The initial ten-day driver did not explore after exhausting nearby resources; the final driver requires actual successful movements. None of those failed/insufficient runs establishes extended-play completion.

### Extended Large result

`large_control_final` and `large_current_final` both reach Day 11 through ten complete End Turns, 22 successful moves, collection/control interactions, a Market Square purchase and a generated-save round trip with all 2,961 source records preserved. All **24 full session trees match exactly**, without omitted fields. The reference swaps only the prior lookup owner; both runs include the read-only warning fix needed to pass Day 5. Therefore these timings isolate lookup effects, not the warning fix or all changes combined.

| Matched action span | Reference | Indexed | Reduction |
| --- | ---: | ---: | ---: |
| Native generation + first entry | 26.696 s | 25.821 s | 3.3% |
| Owned-town body click + entry | 2.145 s | 1.533 s | 28.5% |
| Ledger open + selection + purchase through usable controls | 6.496 s | 4.704 s | 27.6% |
| Ten End Turn requests/confirmations through settled scene | 97.030 s | 82.046 s | 15.4% |

These are one method-matched extended pair on Linux llvmpipe, not universal performance guarantees. The optimized ten core `end_turn` events contain 48.459 s of rules/AI, 17.653 s autosaving, and 6.126 s synchronous refresh; the outer action spans also include warning/stale checking and frame settlement. Autosaves were not removed. Peak child RSS was 2,399,832 KiB reference and 2,537,692 KiB indexed; there is **no memory-reduction claim** from this software-rendered pair.

Seven late exploratory clicks do not move the hero and are not counted as successful movement. Their profile records resolve raw tile `(84,97)` through the persistent Reef Coin Assay visual body to its interaction anchor `(85,97)`, activating `site_response`. This is the existing site interaction, not evidence that movement is globally stuck. The driver is a bounded legal expedition, not an intelligent exploration/completion solver; no Large battle or victory is claimed.

The requested 1280×720 is applied through `SettingsService` in isolated test storage, because engine `--resolution` alone was overwritten by the saved/default display choice. Inspected `large_current_final/day_01_entry.png`, `town_progressed.png` and `final.png` are actual 1280×720 captures with the owned roster, command/footer controls and fog intact. Veilmourn's constructed sprites still visibly stand apart from the scenic painting, and footer copy is abbreviated/visually crowded. Those existing art/layout gaps are not redesigned in this performance slice.

### Accessibility backend boundary

Rendered `large_control` and `large_control_isolated` abort inside Godot 4.6.2's AccessKit Unix dependency with `context.rs:61:78`, `InterfaceNotFound`, exit 134 after Town purchase. A fresh D-Bus session does not cure it. Both accepted Large timing runs explicitly use the engine's **test-only** `--accessibility disabled`; production accessibility defaults and UI focus controls remain unchanged. This is a remaining enabled-AT-SPI release/environment gap, not a claimed fix or an unqualified clean accessibility playthrough. The separate actual Battle OK/Cancel focus regression runs with the default backend.

`stale_turn_verified` replays the preserved real Day-5 state: before/requested/reinspected sessions and hashes remain equal, while an actual gold change invalidates confirmation. `tied_memory_final` independently exercises twenty same-label scouting records with the same assertions. The original swapped records are native resource objects 2444 `(44,97)` and 2420 `(52,105)` in the second enemy's scouting array; their unchanged equal labels/days triggered the normalizer's unstable tie ordering.

The broad rendered Battle controller smoke reproduces the same AccessKit `InterfaceNotFound` abort. With only that backend explicitly disabled, its actual input assertions pass in `input_compatibility_final`; default-backend cursor and focused Battle dialogs pass separately. An initial focused Battle launch with a stale shared D-Bus environment also failed during backend startup; the accepted `battle_verified` uses a fresh session. None of these backend failures is hidden by filtering the logs.

### Regression compatibility and content findings

- `domain_final` is **not** an all-pass run. It exposed stale fixtures, two four-minute runner timeouts and deliberately injected error lines that the first wrapper did not distinguish. `domain_corrected` reruns those cases with exact scoped injected-error classification and a 900-second budget. Music's full scene matrix passes in 246 seconds.
- Terminal River Pass save-failure fixtures now stage its required counterstroke and guard-resolution identities, preserving the original rollback/retry assertions. The Battle controller fixture now expects the already-shipped inline commander summary and excludes the already-hidden numbered save picker from visible rectangle checks. These are fixture compatibility changes, not gameplay changes.
- The route animation fixture measures animation-only redraw after its bounded first layout resize and isolates hero fog from newly implemented owned-town vision. It still requires exact route tiles/endpoints, movement costs, one imported movement cue, stable static/state generations during interpolation, reduced-motion behavior and correct fog. The rendered full report passes in `input_compatibility_final`.
- The old all-in-one keyboard smoke also assumes numbered-slot overwrite, a visible Town TabBar and the pre-casualty-report Battle route, all replaced before this slice. It remains incompatible and is not claimed passed. `active_input_final` stops at that retired Town navigation assertion; `active_input_verified` loses its old fixture observer during the new report handoff. Both failed processes/logs are retained. Python's final bounded runner preserves the four unchanged physical Overworld assertions; current named-file, Town icon/dialog, Battle controller-board and actual dialog-button tests cover the other surfaces separately.
- The old Town layout report referenced the removed three-scene ratio constant. Its updated fixture checks six factions with starting/half/full building sets against the current fixed village-base hotspot, preserving the 18 mapping cases, two resolutions, five direct dialogs and containment/focus assertions. `town_layout_verified` retains the old parse failure; `town_layout_final` passes. No Town rendering or art is changed by this compatibility correction.
- All 32 towns pass rare-build save/resume, same-day guard and Town resume-target checks. **31/32** meet the 30-day development target; Moonbite Reedshrine lacks its Mirehorn Chain Pen at the deadline. `moonbite_control_final` reproduces the identical complete failing report with the old ordered lookup owner and the new index. This proves lookup parity, not balance approval. The dated [save/resume report update](economy-town-development-save-resume-report.md) records the current-content gap without rewriting historical evidence.

## Review coverage and limitations

Inventory: 71 GDScript files across core (25), autoloads (13), persistence (4), UI/audio helpers (2), and scenes (27), about 189k lines including legacy runtime validation helpers. `src/gdextension/CMakeLists.txt` names the eight shipped extension translation units; archived/recovery source blobs and CLI/selftest targets are not counted as shipped gameplay. This is a whole-runtime ownership inventory plus targeted code review, **not** an assertion that every line or every authored campaign was exhaustively reviewed.

| Area | Source owners and inspection depth |
| --- | --- |
| Boot/menu/settings/accessibility | Boot/router preload and save gates, MainMenu ready/lazy browsers, SettingsService transaction/process enablement, UiAccessibility node/focus lifecycle inspected. Full graphics-driver startup not certified. |
| Content | Catalog loaders, all lookup entry points, draft/read-only ownership and validation/index boundaries deeply inspected and changed. |
| Generated packages/editor | ScenarioSelect setup/adoption and native bridge materialization inspected; CMake/runtime binding and editor refresh/handoff owners inventoried. No native parity/recovery or topology change claimed. |
| Overworld | Refresh/read scopes, movement/selection, town body/entry routing, fog/path/render indexes, static/dynamic redraw separation and End Turn confirmation/save pipeline inspected. |
| Town/economy | Existing scoped catalog/preflight, live action/ledger/input-blocker, staged art and exit handoff paths reviewed against the prior measured controls. |
| Heroes/artifacts/spells | Normalization, content-query and action ownership inventoried; command/spell/artifact interactions sampled by live play and domain tests, not every equipment combination. |
| Battle/AI | Refresh/save surface deeply inspected; action resolution, deterministic auto-resolve, report routing, intent caching, board presentation and modal lifecycle inspected. No AI/normalization shortcuts. |
| Strategic AI/objectives/campaign | Decision-local knowledge reuse and normalization, equal-label scouting sort, scenario hook cap/ordering and campaign profile/transition ownership inspected. Policy and native generation remain unchanged. |
| Persistence | Summary/cache freshness, detached/read-scoped copy, runtime transaction writer, current/stored recap construction and router save requirements deeply inspected. |
| Audio/lifecycle | RuntimeAudioLoader source/import fallback, music/ambient context signatures and bounded crossfade player ownership, process enablement, and static renderer resources inspected. |

Remaining candidates are measured rather than silently rewritten: Large AI simulation/normalization, detached save recap construction for screens which actually display it, static-map signature/index rebuild work, and cold software-rendered startup. A clean sample is not release-wide performance or native Windows/GPU certification.

## Final validation

Evidence root: `.artifacts/full_play_runtime_20260905/`. New runners require fresh labels and keep failed attempts. Benchmark revision fields identify the starting HEAD; the measured implementation was the working tree. The final right-stick-only correction is separately exercised after the timing pairs and does not alter their pointer-driven commands or gameplay rules.

| Check | Accepted evidence/result |
| --- | --- |
| Authored live play | `verified_skirmish/report.json` and `matched_control_report.json`: 51 steps, victory/outcome/manual save/resume, default accessibility backend, 42 complete shared state trees equal, zero native/script/RID issues. |
| Extended generated play | `large_current_final/report.json` against `large_control_final`: Day 11, ten turns, 22 moves, Market Square, generated save round trip; 24 exact trees. Explicit test-only disabled accessibility. |
| Prior three-purchase control | `.artifacts/large_town_build_end_turn_20260905/full_play_final/report.json` against `verified_final`: three purchases/turns, 2,961 source records and all 12 complete trees equal. Used as final functional parity, not additional timing evidence because other diagnostic runs overlapped. |
| Lookup/save-copy/read safety | `content_lookup/final_complete`, `battle_verified`, `save_projection_final`, `stale_turn_verified`, `tied_memory_final`: all focused assertions pass. |
| Existing domain sweep | Merge the latest corresponding rows from `domain_final`, `domain_corrected`, `input_compatibility_final`, `town_layout_final`: **24/25** domain reports pass. The only failing domain is the explicitly unchanged Moonbite 30-day balance target; `moonbite_control_final` proves exact old/current report parity. No all-pass claim for the initial suites. |
| Physical input/presentation | `overworld_input_final`: four exact physical movement, right-stick preview/cancel/commit and End Turn dialog cases pass. `input_compatibility_final`: Battle controller-board and full-route animation/fog reports pass. `rendered_domain_verified`: custom cursor passes with default backend. `town_layout_final`: two resolutions, five dialogs and 18 faction/build-state hotspot cases pass. |
| Required prior regression | `validation/large_town_turn_regression.log` and `validation/named_save_files.log`: both required Python regressions pass, including actual named-file input/cancel flows. |
| Repository | `validation/validate_repo_complete.log`: `python3 tests/validate_repo.py` passes. New Python files compile; `git diff --check` passes. |
| Final Linux/Windows | `validation/linux_final/report.json` and `validation/windows_final/report.json` pass exports, native sidecar/payload checks and packaged startup. Both PCKs are **248376908 bytes**, **1623092 bytes below** the unchanged 250000000-byte limit. |
| Packaged map/Town entry | `validation/linux-final-generated-flow/live_validation_report.json` and `validation/windows_final/generated-flow/live_validation_report.json`: all three launch/generated-Overworld/Town steps pass, with no runtime errors. Windows execution is Wine on Linux, not native Windows/GPU certification. |

Final visual inspection covers the actual 1280×720 Large entry/Town/Day-11 captures, 1920×1080 Battle and casualty report, plus the current Town test captures at 1280×720 and 2048×1079. Scenic areas and command buttons remain usable. Built-town sprites still stand apart from the painting; the Town footer has stray resource numbers behind/between buttons, and the Large footer is crowded. These are recorded visual defects, not an unqualified no-overlap or polished-art claim.

Handoff: commit only this slice's runtime, Python orchestration, narrowly updated existing fixtures and relevant docs/tracker. Commit/push and HEAD-versus-origin verification are reported in the final handoff, not presumed by a report entry. Preserve the four pre-existing untracked paths: `docs/artifact-retention-policy.md`, `reports/`, `tools/__pycache__/`, `tools/artifact_retention.py`. This bounded performance review is complete; it does not complete the game, every campaign arc, native accessibility certification or balance approval.
