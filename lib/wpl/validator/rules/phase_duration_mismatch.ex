defmodule WPL.Validator.Rules.PhaseDurationMismatch do
  @moduledoc false
  use WPL.Validator.Rule

  alias WPL.Validator.{Error, RepairHint, WalkContext}

  @dsl_week_example """
      WEEK {n}:
        DAY Monday training 45m "Session name":
          warmup:
            cycling 5m zone2
          main straight_sets:
            <exercise_name> 3x8..12 rpe 7 rest 90 seconds
          cooldown:
            <stretch_name> 30s\
  """

  @impl true
  def enter_phase(ctx, phase, path) do
    dur = Map.get(phase, "duration")
    weeks = phase |> Map.get("weeks", []) |> List.wrap()

    with true <- is_map(dur),
         true <- weeks != [],
         value when is_number(value) <- Map.get(dur, "value"),
         unit when is_binary(unit) <- Map.get(dur, "unit"),
         true <- mismatch?(value, unit, length(weeks)) do
      weeks_count = length(weeks)
      expected_weeks = expected_weeks_from_duration(value, unit)
      phase_name = Map.get(phase, "name")

      {missing, dsl_example} =
        if is_integer(expected_weeks) and expected_weeks > weeks_count do
          missing = Enum.to_list((weeks_count + 1)..expected_weeks)
          {missing, @dsl_week_example}
        else
          {nil, nil}
        end

      base_meta = %{
        declared_value: value,
        declared_unit: unit,
        weeks_count: weeks_count
      }

      meta =
        if missing,
          do: Map.put(base_meta, :missing_week_numbers, missing),
          else: base_meta

      repair_hint = %RepairHint{
        action: :add_weeks,
        target_path: "#{path}/weeks",
        parent_name: if(is_binary(phase_name), do: phase_name, else: nil),
        missing: missing,
        expected_count: expected_weeks,
        actual_count: weeks_count,
        context_dsl_example: dsl_example
      }

      WalkContext.emit(ctx, %Error{
        path: path,
        code: :phase_duration_mismatch,
        message:
          "Phase duration (#{value} #{unit}) does not match weeks array (#{weeks_count} items)",
        severity: :warning,
        meta: meta,
        repair_hint: repair_hint
      })
    else
      _ -> ctx
    end
  end

  defp mismatch?(value, "weeks", weeks_count), do: value != weeks_count

  defp mismatch?(value, "days", weeks_count) do
    expected_weeks = trunc(value / 7)
    expected_weeks > 0 and abs(expected_weeks - weeks_count) > 1
  end

  defp mismatch?(_value, _unit, _weeks_count), do: false

  defp expected_weeks_from_duration(value, "weeks"), do: trunc(value)
  defp expected_weeks_from_duration(value, "days"), do: trunc(value / 7)
  defp expected_weeks_from_duration(_value, _unit), do: nil
end
