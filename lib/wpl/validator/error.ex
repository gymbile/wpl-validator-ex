defmodule WPL.Validator.Error do
  @moduledoc """
  A single validation finding.

  Fields:
    * `:path` — RFC 6901 JSON Pointer to the offending node (string).
    * `:code` — atom, e.g. `:duplicate_id` or `:schema_violation`.
    * `:message` — human-readable description.
    * `:severity` — `:error` or `:warning`.
    * `:meta` — code-specific extra fields (map, may be empty).
  """

  @type code ::
          :schema_violation
          | :duplicate_id
          | :unresolved_ref
          | :empty_phases_for_type
          | :invalid_prescription
          | :invalid_personalization_rule
          | :invalid_points_rule
          | :phase_duration_mismatch
          | :cyclic_subplan

  @type severity :: :error | :warning

  @type t :: %__MODULE__{
          path: String.t(),
          code: code(),
          message: String.t(),
          severity: severity(),
          meta: map()
        }

  @enforce_keys [:path, :code, :message, :severity]
  defstruct [:path, :code, :message, :severity, meta: %{}]
end
