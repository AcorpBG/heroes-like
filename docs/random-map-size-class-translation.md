# Random Map Size Class Translation

Status: scoped correction note for `random-map-size-class-parity-correction-10184`.
Date: 2026-04-29.

## Purpose

Player-facing random-map setup must expose HoMM3-style map size classes as explicit generation inputs. Template/profile choice controls topology and content bias; it must not be the only place where map dimensions are hidden.

## Size Classes

The source parity classes are:

| Class | Source dimensions | Current materialization |
|---|---:|---|
| Small | 36x36 | Available at 36x36, with optional second level when the selected template supports it. |
| Medium | 72x72 | Unavailable under the current 64x48 materialized runtime cap. |
| Large | 108x108 | Unavailable under the current 64x48 materialized runtime cap. |
| Extra Large | 144x144 | Unavailable under the current 64x48 materialized runtime cap. |

The current original runtime cap is `64x48x2`. Until that cap is lifted and validated, generated-map metadata and UI must not present capped output as a full Medium, Large, or Extra Large map.

## Runtime Policy

Generated configs carry both source-class provenance and materialized runtime policy:

- `size_class_id`, `size_class_label`, and source dimensions preserve the selected HoMM3-style class.
- `width`, `height`, and `level_count` are the dimensions the current runtime is allowed to materialize.
- `runtime_size_policy.materialization_available` is the launch gate.
- Oversized classes fail validation before session launch, save/writeback, or campaign adoption.

This is an accepted original-game runtime boundary, not a hidden downscale.
