# Changelog

All notable changes to `:wpl_validator`.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] — 2026-05-02

### Added
- Initial release of `:wpl_validator`. Sister implementation of [`@gymbile/wpl-validator`](https://www.npmjs.com/package/@gymbile/wpl-validator) (TypeScript) — same conformance fixtures, identical `(code, path)` results.
- Pass 1: JSON Schema validation (Draft 2020-12 schema, validated via `ex_json_schema` with a `$schema` Draft-7 compatibility swap; the schema uses only Draft-7-compatible keywords).
- Pass 2: semantic invariants — single tree-walk with rule behaviour. Rules: `:duplicate_id` (5 scopes), `:empty_phases_for_type`, `:invalid_prescription`, `:invalid_personalization_rule` (with nested CompoundCondition recursion), `:invalid_points_rule`, `:phase_duration_mismatch` (warning), `:unresolved_ref` (catalog-optional).
- Public API: `WPL.Validator.validate/2` returns a `WPL.Validator.Result` struct with structured `WPL.Validator.Error` entries (path, code atom, severity, meta).
- Conformance suite vendored from [`gymbile/wpl@v1.1.1`](https://github.com/gymbile/wpl/tree/v1.1.1/conformance) — all 3 valid + 9 invalid fixtures pass.
- Drift-check CI (weekly) against `gymbile/wpl` upstream.
