# Changelog

All notable changes to `:wpl_validator`.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.9.0] — 2026-06-18

### Added
- **Matcher vocabulary SSOT**: `WPL.Enforce.MatcherVocab` (qualifier_tokens/short_plurals) is
  generated from a vendored `wpl/data/matcher-vocab.json`; `WPL.Enforce.Matcher` sources its
  vocab from it; adds matcher-vocab drift-check. Matcher logic unchanged.

## [1.8.0] — 2026-06-17

### Added
- **Pass-3 enforcement engine**: `WPL.Enforce.enforce/3,4` evaluates personalization
  rules against a `ClientContext` and strips forbidden activities from a compiled plan.
  Exports: `WPL.Enforce`, `WPL.Enforce.Matcher`, `WPL.Enforce.RuleEvaluator`,
  `WPL.Enforce.Cycle`. Fail-closed diagnostics: `UNKNOWN_CONDITION_FIELD`,
  `UNKNOWN_ACTION_TYPE`.
- Enforcement conformance fixtures (`priv/conformance/enforcement/`) — 6 cross-language
  fixtures shared with `@gymbile/wpl-validator@1.8.0`.
- `forbid_exercise` accepted by `WPL.Validator.Rules.InvalidPersonalizationRule`.
- `in` / `not_in` condition ops tested (already pass; schema sync completes support).
- Strict catalog mode: `validate(plan, require_catalog: true)` emits `:catalog_required`
  instead of silently skipping entity resolution when no catalog is supplied.
- `:catalog_required` added to `WPL.Validator.Error.@type code`.

### Changed
- Catalog ref resolution is now case-insensitive (lowercases both ref and catalog entries
  before comparing). Mirrors `@gymbile/wpl-validator@1.8.0` `hasRef` behavior.
- Vendored schema updated to WPL v1.7.0.

## [1.6.6] — 2026-05-05

### Changed

- **ACTIVITY_BLOCK_MISMATCH allowed-activity table relaxed for warmup and cooldown** — `exercise` is now allowed in both `warmup` and `cooldown` blocks. Mirrors `@gymbile/wpl-validator@1.6.6`.

### Removed

- Conformance fixture `invalid/activity-block-mismatch-exercise-in-cooldown` (no longer a violation).

## [1.6.5] — 2026-05-04

### Added
- Pass-2 rule `:activity_block_mismatch` rejects activities whose `type` is not allowed in the parent block's `type` (e.g. `exercise` in a `cooldown` block). `:activity_block_mismatch` added to `WPL.Validator.Error.code` typespec. See `conformance/error-codes.md` for the full allowed-activity table.

## [1.6.0] — 2026-05-04

### Changed
- Sync vendored schema + conformance suite from `gymbile/wpl@v1.6.0` (was `v1.5.0`).

### Added
- **Contraindication tightening.** Optional `severity` (`low | moderate | high`) and `action: "require_clearance"`.
- **Cardio interval consistency.** `CardioPrescription.intervals.work.duration` / `.rest.duration` accept a full `Duration` object alongside bare seconds.
- **Cardio intensity slots.** `intensity.target` gains typed slots (`zone`, `min_bpm`/`max_bpm`, `min_watts`/`max_watts`, `value`+`unit` for pace).
- **Resistance extras.** `Reps.amrap: bool`, `ExercisePrescription.to_failure: bool`, `Weight.metric` enum (`1RM | e1RM | training_max | daily_max`).
- **Typed progress measurements.** `Checkpoint.measurements[]` items accept a free string or a typed `MeasurementSpec` with `MeasurementMetric` enum and `Questionnaire` enum.
- **Recovery typing.** `RecoveryExercise` gains `modality`, `intensity_rpe`, `pnf` block, and `body_part`.
- 5 new valid conformance fixtures: `contraindication-clearance`, `cardio-intervals-duration`, `amrap-to-failure`, `checkpoint-typed-measurements`, `recovery-pnf-smr`.
- 5 new invalid conformance fixtures: `contraindication-bad-severity`, `contraindication-bad-action`, `checkpoint-bad-metric`, `recovery-bad-modality`, `weight-bad-metric`.

### Notes
All schema changes are additive; every plan valid under 1.5.0 continues to validate under 1.6.0.

## [1.4.0] — 2026-05-03

### Added
- Pass-2 rule `:cyclic_subplan`. Detects sub-plan reference self-cycles (a `SubPlanActivity` whose `sub_plan_ref` equals the containing plan's `id`). Cross-plan cycles deferred pending a `sub_plans` resolution map in the validate API.
- `:cyclic_subplan` added to `WPL.Validator.Error.code` typespec.

### Changed
- Sync vendored schema + conformance suite from `gymbile/wpl@v1.5.0` (was `v1.4.0`).

### Notes
99/99 tests pass.

## [1.3.0] — 2026-05-03

### Changed
- Sync vendored schema + conformance suite from `gymbile/wpl@v1.4.0` (was `v1.3.0`).

### Notes
Schema v1.4.0 adds per-bodyweight scaling for macros/calories/load and documented controlled-vocabulary prefixes for telemetry sources and clinical contraindications. All additive. 41/41 conformance + full validator suite pass.

## [1.2.0] — 2026-05-03

### Fixed
- Pass 1 now drills into the best-matching branch for `oneOf` schema failures, matching ajv's native behavior. Previously, an invalid inner field on (e.g.) an `ExerciseActivity` produced a generic `oneOf` error at the activity level instead of the specific (e.g. `enum`) error at the offending field. Surfaced by the round-3 `bad-muscle-group` conformance fixture; codified in `error-codes.md`.

### Changed
- Sync vendored schema + conformance suite from `gymbile/wpl@v1.3.0` (was `v1.2.0`).

### Notes
Schema v1.3.0 adds optional `primary_muscles`/`secondary_muscles`/`movement_pattern` on `ExerciseActivity`, plan-level `athlete_thresholds`, and `intensity.zone_model` on cardio. 94/94 tests pass.

## [1.1.0] — 2026-05-03

### Changed
- Sync vendored schema + conformance suite from `gymbile/wpl@v1.2.0` (was `v1.1.1`).

### Notes
Schema v1.2.0 is purely additive: `Phase.type` enum, `Week.is_deload` boolean, and a structured `Tempo` shape (alongside the existing string form). No new validator rules; Pass 1 (schema validation) covers all three additions. Plans authored against v1.1.x continue to validate unchanged.

## [1.0.0] — 2026-05-02

### Added
- Initial release of `:wpl_validator`. Sister implementation of [`@gymbile/wpl-validator`](https://www.npmjs.com/package/@gymbile/wpl-validator) (TypeScript) — same conformance fixtures, identical `(code, path)` results.
- Pass 1: JSON Schema validation (Draft 2020-12 schema, validated via `ex_json_schema` with a `$schema` Draft-7 compatibility swap; the schema uses only Draft-7-compatible keywords).
- Pass 2: semantic invariants — single tree-walk with rule behaviour. Rules: `:duplicate_id` (5 scopes), `:empty_phases_for_type`, `:invalid_prescription`, `:invalid_personalization_rule` (with nested CompoundCondition recursion), `:invalid_points_rule`, `:phase_duration_mismatch` (warning), `:unresolved_ref` (catalog-optional).
- Public API: `WPL.Validator.validate/2` returns a `WPL.Validator.Result` struct with structured `WPL.Validator.Error` entries (path, code atom, severity, meta).
- Conformance suite vendored from [`gymbile/wpl@v1.1.1`](https://github.com/gymbile/wpl/tree/v1.1.1/conformance) — all 3 valid + 9 invalid fixtures pass.
- Drift-check CI (weekly) against `gymbile/wpl` upstream.
