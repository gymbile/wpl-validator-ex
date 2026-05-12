defmodule WPL.Validator.RepairHint do
  @moduledoc """
  Machine-actionable repair guidance attached to a `WPL.Validator.Error`.

  Designed for agentic completion loops: a higher-level orchestrator reads
  `repair_hint` and constructs a targeted re-generation prompt (e.g. "add
  weeks 2-12 to Phase 1 of this plan") without having to parse free-text
  `message` strings.

  Mirrors the TypeScript `RepairHint` interface in `@gymbile/wpl-validator`
  (1.7.0+).

  Fields:
    * `:action` — atom; one of `:add_weeks`, `:add_days`, `:add_phases`,
      `:fix_activity`, `:fix_prescription`, `:resolve_ref`,
      `:remove_duplicate`.
    * `:target_path` — RFC 6901 JSON Pointer to the parent the repair
      attaches to.
    * `:parent_name` — optional human-readable label of the target.
    * `:missing` — optional list of identifiers the agent should generate
      (e.g. week numbers).
    * `:expected_count` / `:actual_count` — for count-based gaps.
    * `:allowed_values` — for enum-shaped repairs.
    * `:expected_shape` — declared schema/DSL shape the agent must match.
    * `:context_dsl_example` — multi-line DSL snippet illustrating the fix.
  """

  @type action ::
          :add_weeks
          | :add_days
          | :add_phases
          | :fix_activity
          | :fix_prescription
          | :resolve_ref
          | :remove_duplicate

  @type t :: %__MODULE__{
          action: action(),
          target_path: String.t(),
          parent_name: String.t() | nil,
          missing: list(String.t() | number()) | nil,
          expected_count: non_neg_integer() | nil,
          actual_count: non_neg_integer() | nil,
          allowed_values: list(String.t()) | nil,
          expected_shape: String.t() | nil,
          context_dsl_example: String.t() | nil
        }

  @enforce_keys [:action, :target_path]
  defstruct [
    :action,
    :target_path,
    :parent_name,
    :missing,
    :expected_count,
    :actual_count,
    :allowed_values,
    :expected_shape,
    :context_dsl_example
  ]
end
