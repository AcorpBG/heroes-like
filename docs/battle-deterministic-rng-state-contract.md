# Battle Deterministic RNG State Contract

## Authority

`battle.combat_seed` is the authoritative seed for combat damage randomness.
Every new battle resolves and persists a nonzero value before the first damage
roll. The damage stream is battle-local and versioned independently of the
top-level save format.

## Draw and persistence rules

- A new stream is initialized by assigning the authoritative seed through
  `RandomNumberGenerator.seed`; the resulting valid state is persisted.
- Player and AI primary attacks restore only that persisted state.
- Each real call that rolls damage consumes exactly one value and immediately
  persists the resulting state and incremented roll count. A retaliation is the
  next draw in the same stream.
- Validation, previews, target scoring, invalid orders, presentation playback,
  tactical briefings, text, dictionary key order, and other inert metadata do
  not initialize, consume, or alter the stream.

## Save and migration behavior

The battle payload stores a stream version, exact state string, diagnostic roll
count, and SHA-256 integrity guard over the version, seed, state, and count.
These fields travel through the existing versioned session snapshot. A malformed
current stream or unsupported future stream version emits a warning and
deterministically reinitializes from the authoritative seed instead of assigning
an arbitrary value to Godot RNG state.
An older in-progress battle without them deterministically initializes the
current stream from its persisted combat seed; if its historical seed was zero,
the existing session/encounter/round fallback is resolved once and persisted.
Its next damage may differ from the pre-fix unsupported whole-dictionary hash,
but repeated restores of the same old snapshot produce the same continuation.

Godot documents its PCG implementation as an implementation detail. Windows and Linux release packages therefore use the same pinned Godot version. Exact
continuity across a future engine RNG change requires a separately selected,
repository-owned versioned RNG algorithm and migration.

## Validation boundary

Focused runtime proof must compare identical seed/action sequences across inert
metadata changes, player and AI execution, retaliation order, uninterrupted and
save-restored sessions, and repeated legacy-field fallback. Broad combat and
active-scenario suites must be rerun, and changed deterministic signatures must
be recorded as an intentional architecture baseline rather than silently
treated as comparable with pre-fix live balance evidence.
