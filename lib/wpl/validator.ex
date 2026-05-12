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

  alias WPL.Validator.{Pass1, Pass2, Result}

  @type opts :: [catalog: catalog()]
  @type catalog :: %{
          optional(:exercises) => MapSet.t(String.t()),
          optional(:meals) => MapSet.t(String.t()),
          optional(:meditations) => MapSet.t(String.t())
        }

  @spec validate(any(), opts()) :: Result.t()
  def validate(input, opts \\ []) do
    pass1_errors = Pass1.run(input)

    if pass1_errors == [] do
      pass2_errors = Pass2.run(input, opts)
      valid? = Enum.all?(pass2_errors, &(&1.severity != :error))
      %Result{valid?: valid?, errors: pass2_errors}
    else
      %Result{valid?: false, errors: pass1_errors}
    end
  end

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
