defmodule WPL.Validator.Rules.InvalidPrescription do
  @moduledoc false
  use WPL.Validator.Rule

  alias WPL.Validator.{Error, WalkContext}

  @valid_types MapSet.new(["sets_reps", "time", "distance", "amrap", "continuous", "intervals"])

  @impl true
  def enter_activity(ctx, activity, path) do
    if Map.get(activity, "type") == "exercise" do
      check_prescription(ctx, activity, path)
    else
      ctx
    end
  end

  defp check_prescription(ctx, activity, path) do
    prescription = Map.get(activity, "prescription")

    if is_map(prescription) do
      validate_prescription(ctx, prescription, "#{path}/prescription")
    else
      ctx
    end
  end

  defp validate_prescription(ctx, p, pres_path) do
    case Map.fetch(p, "type") do
      :error ->
        WalkContext.emit(ctx, %Error{
          path: pres_path,
          code: :invalid_prescription,
          message: "prescription missing 'type'",
          severity: :error,
          meta: %{reason: :missing_type}
        })

      {:ok, t} when is_binary(t) ->
        if MapSet.member?(@valid_types, t) do
          ctx
          |> check_sets_reps(p, t, pres_path)
          |> check_time(p, t, pres_path)
        else
          WalkContext.emit(ctx, %Error{
            path: pres_path,
            code: :invalid_prescription,
            message: "unknown prescription type '#{t}'",
            severity: :error,
            meta: %{reason: :unknown_type, prescription_type: t}
          })
        end

      {:ok, t} ->
        WalkContext.emit(ctx, %Error{
          path: pres_path,
          code: :invalid_prescription,
          message: "unknown prescription type '#{t}'",
          severity: :error,
          meta: %{reason: :unknown_type, prescription_type: t}
        })
    end
  end

  defp check_sets_reps(ctx, p, "sets_reps", pres_path) do
    if Map.get(p, "sets") == nil and Map.get(p, "reps") == nil do
      WalkContext.emit(ctx, %Error{
        path: pres_path,
        code: :invalid_prescription,
        message: "sets_reps prescription requires 'sets' or 'reps'",
        severity: :error,
        meta: %{reason: :sets_reps_requires_sets_or_reps}
      })
    else
      ctx
    end
  end

  defp check_sets_reps(ctx, _p, _type, _path), do: ctx

  defp check_time(ctx, p, "time", pres_path) do
    if Map.get(p, "duration") == nil do
      WalkContext.emit(ctx, %Error{
        path: pres_path,
        code: :invalid_prescription,
        message: "time prescription requires 'duration'",
        severity: :error,
        meta: %{reason: :time_requires_duration}
      })
    else
      ctx
    end
  end

  defp check_time(ctx, _p, _type, _path), do: ctx
end
