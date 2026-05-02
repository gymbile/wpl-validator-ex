defmodule WPL.Validator.Rules.PhaseDurationMismatch do
  @moduledoc false
  use WPL.Validator.Rule

  alias WPL.Validator.{Error, WalkContext}

  @impl true
  def enter_phase(ctx, phase, path) do
    dur = Map.get(phase, "duration")
    weeks = phase |> Map.get("weeks", []) |> List.wrap()

    with true <- is_map(dur),
         true <- weeks != [],
         value when is_number(value) <- Map.get(dur, "value"),
         unit when is_binary(unit) <- Map.get(dur, "unit"),
         true <- mismatch?(value, unit, length(weeks)) do
      WalkContext.emit(ctx, %Error{
        path: path,
        code: :phase_duration_mismatch,
        message:
          "Phase duration (#{value} #{unit}) does not match weeks array (#{length(weeks)} items)",
        severity: :warning,
        meta: %{
          declared_value: value,
          declared_unit: unit,
          weeks_count: length(weeks)
        }
      })
    else
      _ -> ctx
    end
  end

  defp mismatch?(value, "weeks", weeks_count) do
    value != weeks_count
  end

  defp mismatch?(value, "days", weeks_count) do
    expected_weeks = trunc(value / 7)
    expected_weeks > 0 and abs(expected_weeks - weeks_count) > 1
  end

  defp mismatch?(_value, _unit, _weeks_count), do: false
end
