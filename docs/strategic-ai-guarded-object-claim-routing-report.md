# Strategic AI Guarded Object Claim Routing Report

Status: implementation evidence for `strategic-ai-guarded-object-claim-routing-10184`.

## Implemented Behavior

- Resource and artifact arrival resolution now checks for unresolved explicit guard links and generated object guards before claim execution.
- `_resource_guard_encounter_for_node` finds active encounters with `guards_resource_node` links or generated object-guard metadata protecting the resource placement.
- `_artifact_guard_encounter_for_node` finds active encounters with artifact/reward guard links or generated object-guard metadata protecting the artifact placement.
- `_redirect_claim_to_guard_encounter` retargets the raid from the guarded resource/artifact to the guard encounter, records `guarded_claim_target_id`, emits public-safe `ai_target_assigned`, and leaves the original claim task active.
- `_resume_guarded_claim_after_guard_clear` restores the original resource/artifact target after the guard encounter is cleared, clears transient `guarded_claim_*` metadata, emits public-safe `ai_target_assigned`, and keeps the claim task active until the actual prize is secured.
- `_guarded_claim_resume_target` rechecks that no unresolved guard still protects the original target before resuming the claim.
- Unguarded claim paths still resolve normally: resources can still be seized and artifacts can still be secured/equipped after no guard protects the target.

## Focused Evidence

- `guarded_resource_claim_resumes_and_secures_after_guard_clear`: a strong Mireclaw host reaches the player-held `river_free_company` resource while `river_free_company_guard` has an explicit `guards_resource_node` link. The site remains player-held during redirect and guard clearance, no `ai_site_seized` event is emitted until the guard is gone, the raid resumes the original resource target with `guard_cleared` / `guarded_resource_claim`, and the later claim completes the resource task.
- `guarded_artifact_claim_resumes_and_secures_after_guard_clear`: a strong Mireclaw host reaches `warcrest_ruin` while `warcrest_ruin_guard` protects it. The relic is not collected or equipped during redirect and guard clearance, no `ai_artifact_secured` event is emitted until the guard is gone, the raid resumes the original artifact target with `guard_cleared` / `guarded_artifact_claim`, and the later claim completes the artifact task.

No save migration is introduced; `SAVE_VERSION` remains unchanged.

## Boundary

No full strategic AI quality claim. This slice closes one concrete production behavior hole: AI objective claim execution cannot bypass unresolved guards. Broader release-ready strategic AI still needs long-run generated-map behavior, smarter multi-week army planning, coordinated multi-hero pressure, retreat timing review, and manual live-client pacing checks.
