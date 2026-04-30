# Random Map Size Class Translation

Status: runtime support note for `random-map-extra-large-runtime-support-10184`.
Date: 2026-04-30.

## Purpose

Player-facing random-map setup must expose HoMM3-style map size classes as explicit generation inputs. Template/profile choice controls topology and content bias; it must not be the only place where map dimensions are hidden.

## Size Classes

The source parity classes are:

| Class | Source dimensions | Current materialization |
|---|---:|---|
| Small | 36x36 | Available at 36x36, with optional second level when the selected template supports it. |
| Medium | 72x72 | Available at 72x72, with optional second level when the selected template supports it. |
| Large | 108x108 | Available at 108x108, with optional second level when the selected template supports it. |
| Extra Large | 144x144 | Available at 144x144, with optional second level when the selected template supports it. |

The current original runtime cap is `144x144x2`, matching the largest exposed source class with the existing two-level limit. Generated-map metadata, provenance, replay metadata, saves, and runtime materialization must report materialized dimensions equal to the selected source dimensions. Requests beyond `144x144x2` must fail validation instead of being silently clamped.

## Runtime Policy

Generated configs carry both source-class provenance and materialized runtime policy:

- `size_class_id`, `size_class_label`, and source dimensions preserve the selected HoMM3-style class.
- `width`, `height`, and `level_count` are the dimensions the runtime materializes.
- `runtime_size_policy.materialization_available` is the launch gate.
- Over-cap custom requests fail validation before session launch, save/writeback, or campaign adoption.

This is an honest materialization contract, not a hidden downscale.
