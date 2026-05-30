# Strategic AI Guarded Object Claim Routing Report

Status: implementation evidence for `strategic-ai-guarded-object-claim-routing-10184`.

## Implemented Behavior

- Resource and artifact arrival resolution now checks for unresolved explicit guard links and generated object guards before claim execution.
- `_resource_guard_encounter_for_node` finds active encounters with `guards_resource_node` links or generated object-guard metadata protecting the resource placement.
- `_artifact_guard_encounter_for_node` finds active encounters with artifact/reward guard links or generated object-guard metadata protecting the artifact placement.
- `_redirect_claim_to_guard_encounter` retargets the raid from the guarded resource/artifact to the guard encounter, records `guarded_claim_target_id`, emits public-safe `ai_target_assigned`, and leaves the original claim task active.
- Unguarded claim paths still resolve normally: resources can still be seized and artifacts can still be secured/equipped after no guard protects the target.

## Focused Evidence

- `guarded_resource_claim_retargets_to_guard`: a strong Mireclaw host reaches the player-held `river_free_company` resource while `river_free_company_guard` has an explicit `guards_resource_node` link. The site remains player-held, no `ai_site_seized` event is emitted, and the raid retargets to the guard with `guard_clearance` / `guarded_resource_claim`.
- `guarded_artifact_claim_retargets_to_guard`: a strong Mireclaw host reaches `warcrest_ruin` while `warcrest_ruin_guard` protects it. The relic is not collected or equipped, no `ai_artifact_secured` event is emitted, and the raid retargets to the guard with `guard_clearance` / `guarded_artifact_claim`.

No save migration is introduced; `SAVE_VERSION` remains unchanged.

## Boundary

No full strategic AI quality claim. This slice closes one concrete production behavior hole: AI objective claim execution cannot bypass unresolved guards. Broader release-ready strategic AI still needs long-run generated-map behavior, smarter multi-week army planning, coordinated multi-hero pressure, retreat timing review, and manual live-client pacing checks.
