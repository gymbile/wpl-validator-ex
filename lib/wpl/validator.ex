defmodule WPL.Validator do
  @moduledoc """
  Validates compiled WPL JSON against the canonical schema and semantic invariants.

  Two passes:
    1. JSON Schema validation (Draft 2020-12).
    2. Semantic invariants (duplicate-id detection, ref resolution, prescription
       validity, etc.) — only runs if Pass 1 passes.

  ## Usage

      {:ok, plan} = Jason.decode(json_string)
      result = WPL.Validator.validate(plan)

      if result.valid? do
        IO.puts("ok")
      else
        for err <- result.errors, do: IO.inspect(err)
      end

  See `WPL.Validator.Error` and `WPL.Validator.Result` for return shapes.
  """

  alias WPL.Validator.{Error, Pass1, Pass2, Result}

  @type opts :: [catalog: catalog(), require_catalog: boolean()]
  @type catalog :: %{
          optional(:exercises) => MapSet.t(String.t()),
          optional(:meals) => MapSet.t(String.t()),
          optional(:meditations) => MapSet.t(String.t())
        }

  @spec validate(any(), opts()) :: Result.t()
  def validate(input, opts \\ []) do
    pass1_errors = Pass1.run(input)

    # The v1.9.0 schema added enums for personalization action `type` and `scope`.
    # Legacy conformance fixtures expect INVALID_PERSONALIZATION_RULE (semantic) for
    # actions that have a `scope` field — suppress schema-level violations for those
    # actions so Pass2 can produce the richer canonical error. Actions with only a
    # `type` field (no `scope`) are caught by schema alone (SCHEMA_VIOLATION).
    {suppressed, pass1_kept} =
      Enum.split_with(pass1_errors, &personalization_action_schema_error?(&1, input))

    if pass1_kept == [] and suppressed == [] do
      pass2_errors = Pass2.run(input, opts)
      valid? = Enum.all?(pass2_errors, &(&1.severity != :error))
      %Result{valid?: valid?, errors: pass2_errors}
    else
      # Run Pass2 for semantic errors even when only suppressed schema errors exist.
      pass2_errors = if pass1_kept == [], do: Pass2.run(input, opts), else: []
      all_errors = pass1_kept ++ pass2_errors
      %Result{valid?: false, errors: all_errors}
    end
  end

  # Returns true for schema violations on personalization action paths where the
  # action in the input has a `scope` field. When scope is present, the semantic
  # validator (Pass2) provides richer context via INVALID_PERSONALIZATION_RULE.
  # When scope is absent, the schema-level enum violation is the canonical error.
  @personalization_action_prefix_re ~r{^/plan/personalization/rules/(\d+)/actions/(\d+)}
  defp personalization_action_schema_error?(%Error{code: :schema_violation, path: path}, input) do
    case Regex.run(@personalization_action_prefix_re, path, capture: :all_but_first) do
      [rule_i, action_i] ->
        ri = String.to_integer(rule_i)
        ai = String.to_integer(action_i)

        action =
          get_in(input, ["plan", "personalization", "rules"])
          |> List.wrap()
          |> Enum.at(ri, %{})
          |> Map.get("actions", [])
          |> Enum.at(ai, %{})

        is_map(action) and Map.has_key?(action, "scope")

      _ ->
        false
    end
  end

  defp personalization_action_schema_error?(_error, _input), do: false

  @doc """
  Convenience: pull every actionable `repair_hint` out of a Result.

  Designed for agentic completion loops — the orchestrator gets a flat
  list of repair actions without having to inspect each error's optional
  field. Errors without a hint (e.g. `:cyclic_subplan`) are skipped.
  """
  @spec repair_hints(Result.t()) ::
          [%{code: atom(), path: String.t(), hint: WPL.Validator.RepairHint.t()}]
  def repair_hints(%Result{errors: errors}) do
    errors
    |> Enum.filter(&(&1.repair_hint != nil))
    |> Enum.map(fn e -> %{code: e.code, path: e.path, hint: e.repair_hint} end)
  end
end
