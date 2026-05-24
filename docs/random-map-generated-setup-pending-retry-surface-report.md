# Random Map Generated Setup Pending Retry Surface Report

Slice: `random-map-generated-setup-pending-retry-surface-20260524-10184`

## Scope

This corrective slice keeps the current strict Small H3MapEd generated-map path player-facing without claiming validation before validation has run.

The generated skirmish setup preview now reports a configured state with `pending launch validation`, labels the command `Validate & Launch`, and explains that native H3MapEd validation plus bounded retry run only when the player launches. Once validation fails, the normal generated setup surface formats the blocked state, disables launch, and keeps the failure boundary visible.

## Runtime Boundaries

- The public setup surface remains strict Small 36x36, one-level, land-only.
- Unsupported water, underground, and broader size-class controls remain hidden or rejected.
- Generated launch still validates through the current bounded retry policy before creating a session.
- Failed validation creates no session, no save, no campaign adoption, no authored writeback, and no alpha/parity claim.
- This slice does not change native map topology, object placement, roads, rewards, towns, or guard behavior.

## Validation

`tests/random_map_player_setup_retry_ux_report.tscn` now gates:

- setup preview carries `pending_launch_validation` with zero attempts before launch;
- retry policy expectations derive from `ScenarioSelectRules.RANDOM_MAP_PLAYER_RETRY_POLICY`;
- the launch command stays enabled as `Validate & Launch` for configured setup;
- forced validation failure uses the normal generated setup surface, disables launch, and reports bounded retry exhaustion;
- successful generated launch still resolves native H3MapEd template/profile provenance without campaign or authored JSON writeback.

`tests/validate_repo.py` gates the report, menu tokens, focused test tokens, and this document.
