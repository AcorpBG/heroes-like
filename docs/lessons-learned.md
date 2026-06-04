# Lessons Learned

Document role: durable engineering lessons for future coding-agent work.

## Native RMG Recovery Discipline

Owner corrective note from the Small/Medium native RMG density investigation:

- Treating disassembly or partial decompile as "complete source" was a failure.
- Patching from final map deltas instead of proving each private buffer matches after each phase was a failure.
- Translating HoMM3 object semantics into native object categories too early was a failure.
- Accepting report/gate progress where byte/state parity checkpoints were needed was a failure.
- Letting one worker iterate experiments instead of freezing a failing phase and saying "this function/data structure is not actually recovered" was a failure.

These are not style preferences. Future native RMG work must use them as hard operating rules.

Before touching native RMG code or parity tooling, agents must read this section and treat any unrecovered function, buffer, or data structure as an explicit blocker for behavior changes in that phase. If a phase cannot be proven from source-backed state, the correct output is a named recovery gap, not another heuristic, density gate, or final-map delta patch.

The required standard is phase/private-state proof. A native RMG change is not source-backed just because the final generated map looks closer, a report improved, or a gate passed. First prove the relevant recovered H3MapEd function, descriptor, buffer, and mutation rule; then implement it. If that proof cannot be made, stop the phase and name the missing recovery target.

## Native RMG: Parity Is Source Behavior, Not Summary Counts

The most important lesson from the native RMG work is that matching headline object counts is not proof of H3MapEd parity. If native does not preserve the source generator's phase behavior, template selection, and passability semantics, it can produce a map that looks statistically close while playing materially worse.

For Medium one-level land generation, native reached a superficially close total object count against a same-template H3MapEd reference, but the generated map still behaved differently because the object surface was wrong: movement-blocked tiles, decoration footprints, type mix, guard-controlled topology, roads, and blocker bodies did not line up. A map can have nearly the same number of objects and still play worse if native picks too many tiny decorative bodies, underuses large mountain/tree-style blockers, overproduces rewards, redraws road surfaces differently, or mutates exact H3M passability masks.

What went wrong in the RMG work was treating evidence surfaces as progress surfaces. Reports, gates, validators, count deltas, and aggregate density charts helped expose drift, but they did not themselves move native closer to H3MapEd. The useful fixes came only when they were tied to a specific recovered source behavior, such as template acceptance or exact object-passability handling. The bad direction was trying to make numbers pass through broad gates, density multipliers, brute-force retries, or guessed post-processing rules.

The deeper process mistake was overclaiming recovery. A disassembly note or partial decompile is not complete source unless the private buffers, descriptor fields, phase inputs, phase outputs, and mutation rules can be checked against H3MapEd state. When a phase still drifts, the right response is to freeze that phase and say which function or data structure is not actually recovered yet, not to keep iterating guesses until a final-map report looks less bad.

Future native RMG work should treat these as hard rules:

- Do not treat disassembly or partial decompile as complete source until the relevant private state is proven.
- Add byte/state parity checkpoints after each recovered phase. Final map deltas are too late to diagnose source behavior.
- Do not patch from final object-density deltas unless the responsible private buffer mismatch has already been identified.
- Keep HoMM3 object semantics intact through generation as long as possible. Translating too early into native categories hides whether towns, guards, rewards, blockers, roads, and decoration matched their source roles.
- Reports and gates are only validation surfaces. They are not progress unless they are backed by recovered-function or recovered-data implementation.
- If a phase is failing and the underlying function or data structure is not recovered, stop that phase and document the missing recovery target instead of adding compensating heuristics.
- Compare same-template H3MapEd references before drawing conclusions. Template mismatch makes Small/Medium density claims misleading.
- Prefer recovered phase behavior over count multipliers, extra gates, brute-force retries, or hand-tuned density scalars.
- H3M passability/body masks are gameplay data, not diagnostics. If a recovered H3M object has non-passable body cells, native movement blocking must preserve them unless there is source-backed evidence otherwise.
- Object-count parity must be subordinate to movement surface parity: body tiles, block tiles, guarded reachability, road topology, category/type mix, and per-object footprints matter more than total records.
- Source-backed mismatches should be fixed at the phase rule that caused them. Do not compensate later with density scalars, synthetic gates, or package-time mask trimming.
- Rejected experiments are useful evidence. The decorative-overlap probe proved overlap behavior exists, while the guessed post-stamp bit clearing underfilled Medium badly; that should guide the next source-backed investigation rather than being polished into a workaround.
- Reports should explain and validate implementation. They must not become the work itself, and they must not hide that the generator is still behaviorally incomplete.

The practical standard is: native RMG is only closer to production when a generated map plays closer to H3MapEd at the route, guard, blocker, reward, road, and footprint surfaces. A better-looking summary count is not enough, and any fix that works by hiding the discrepancy instead of matching the recovered `h3maped.exe` behavior is the wrong fix.
