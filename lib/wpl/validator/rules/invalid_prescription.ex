defmodule WPL.Validator.Rules.InvalidPrescription do
  @moduledoc false
  use WPL.Validator.Rule

  alias WPL.Validator.{Error, RepairHint, WalkContext}

  @valid_types_list ["sets_reps", "time", "distance", "amrap", "continuous", "intervals"]
  @valid_types MapSet.new(@valid_types_list)

  @shape_by_type %{
    "sets_reps" => "{ type: \"sets_reps\", sets: <number>, reps: <number | { min, max }> }",
    "time" =>
      "{ type: \"time\", duration: { value: <number>, unit: \"seconds\" | \"minutes\" } }",
    "distance" =>
      "{ type: \"distance\", distance: { value: <number>, unit: \"meters\" | \"kilometers\" | \"miles\" } }",
    "amrap" => "{ type: \"amrap\", duration: { value: <number>, unit: \"minutes\" } }",
    "continuous" => "{ type: \"continuous\", duration: { value: <number>, unit: \"minutes\" } }",
    "intervals" => "{ type: \"intervals\", rounds: <number>, work: { ... }, rest: { ... } }"
  }

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
      validate_prescription(ctx, prescription, "#{path}/prescription", activity)
    else
      ctx
    end
  end

  defp validate_prescription(ctx, p, pres_path, activity) do
    activity_name = Map.get(activity, "name")
    parent_name = if is_binary(activity_name), do: activity_name, else: nil

    case Map.fetch(p, "type") do
      :error ->
        repair_hint = %RepairHint{
          action: :fix_prescription,
          target_path: pres_path,
          parent_name: parent_name,
          allowed_values: @valid_types_list,
          expected_shape:
            "prescription.type is required; pick one of the allowed values and provide its required fields"
        }

        WalkContext.emit(ctx, %Error{
          path: pres_path,
          code: :invalid_prescription,
          message: "prescription missing 'type'",
          severity: :error,
          meta: %{reason: :missing_type},
          repair_hint: repair_hint
        })

      {:ok, t} when is_binary(t) ->
        if MapSet.member?(@valid_types, t) do
          ctx
          |> check_sets_reps(p, t, pres_path, parent_name)
          |> check_time(p, t, pres_path, parent_name)
        else
          repair_hint = %RepairHint{
            action: :fix_prescription,
            target_path: pres_path,
            parent_name: parent_name,
            allowed_values: @valid_types_list,
            expected_shape: "prescription.type must be one of the allowed values"
          }

          WalkContext.emit(ctx, %Error{
            path: pres_path,
            code: :invalid_prescription,
            message: "unknown prescription type '#{t}'",
            severity: :error,
            meta: %{reason: :unknown_type, prescription_type: t},
            repair_hint: repair_hint
          })
        end

      {:ok, t} ->
        repair_hint = %RepairHint{
          action: :fix_prescription,
          target_path: pres_path,
          parent_name: parent_name,
          allowed_values: @valid_types_list,
          expected_shape: "prescription.type must be one of the allowed values"
        }

        WalkContext.emit(ctx, %Error{
          path: pres_path,
          code: :invalid_prescription,
          message: "unknown prescription type '#{t}'",
          severity: :error,
          meta: %{reason: :unknown_type, prescription_type: t},
          repair_hint: repair_hint
        })
    end
  end

  defp check_sets_reps(ctx, p, "sets_reps", pres_path, parent_name) do
    if Map.get(p, "sets") == nil and Map.get(p, "reps") == nil do
      repair_hint = %RepairHint{
        action: :fix_prescription,
        target_path: pres_path,
        parent_name: parent_name,
        missing: ["sets", "reps"],
        expected_shape: Map.fetch!(@shape_by_type, "sets_reps")
      }

      WalkContext.emit(ctx, %Error{
        path: pres_path,
        code: :invalid_prescription,
        message: "sets_reps prescription requires 'sets' or 'reps'",
        severity: :error,
        meta: %{reason: :sets_reps_requires_sets_or_reps},
        repair_hint: repair_hint
      })
    else
      ctx
    end
  end

  defp check_sets_reps(ctx, _p, _type, _path, _parent_name), do: ctx

  defp check_time(ctx, p, "time", pres_path, parent_name) do
    if Map.get(p, "duration") == nil do
      repair_hint = %RepairHint{
        action: :fix_prescription,
        target_path: pres_path,
        parent_name: parent_name,
        missing: ["duration"],
        expected_shape: Map.fetch!(@shape_by_type, "time")
      }

      WalkContext.emit(ctx, %Error{
        path: pres_path,
        code: :invalid_prescription,
        message: "time prescription requires 'duration'",
        severity: :error,
        meta: %{reason: :time_requires_duration},
        repair_hint: repair_hint
      })
    else
      ctx
    end
  end

  defp check_time(ctx, _p, _type, _path, _parent_name), do: ctx
end
