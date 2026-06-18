defmodule WPL.Validator.Rules.InvalidPrescriptionTest do
  use ExUnit.Case, async: true

  alias WPL.Validator.Rules.InvalidPrescription
  alias WPL.Validator.{Error, WalkContext}

  defp run_on_activity(activity) do
    ctx = %WalkContext{}
    path = "/plan/phases/0/weeks/0/days/0/blocks/0/activities/0"
    InvalidPrescription.enter_activity(ctx, activity, path).errors |> Enum.reverse()
  end

  defp presc_path, do: "/plan/phases/0/weeks/0/days/0/blocks/0/activities/0/prescription"

  describe "InvalidPrescription.enter_activity/3" do
    test "flags sets_reps prescription with neither sets nor reps" do
      activity = %{
        "id" => "a1",
        "type" => "exercise",
        "exercise_ref" => "push_up",
        "prescription" => %{"type" => "sets_reps"}
      }

      errors = run_on_activity(activity)
      assert length(errors) == 1

      err = hd(errors)

      assert %Error{
               path: _,
               code: :invalid_prescription,
               message: "sets_reps prescription requires 'sets' or 'reps'",
               severity: :error,
               meta: %{reason: :sets_reps_requires_sets_or_reps}
             } = err

      assert err.path == presc_path()
      # repair_hint (1.7.0)
      assert err.repair_hint.action == :fix_prescription
      assert err.repair_hint.missing == ["sets", "reps"]
      assert err.repair_hint.expected_shape =~ "sets_reps"
    end

    test "flags time prescription without duration" do
      activity = %{
        "id" => "a1",
        "type" => "exercise",
        "exercise_ref" => "plank",
        "prescription" => %{"type" => "time"}
      }

      errors = run_on_activity(activity)
      assert length(errors) == 1
      assert hd(errors).meta.reason == :time_requires_duration
    end

    test "flags missing prescription type" do
      activity = %{
        "id" => "a1",
        "type" => "exercise",
        "exercise_ref" => "push_up",
        "prescription" => %{"sets" => 3, "reps" => 10}
      }

      errors = run_on_activity(activity)
      assert length(errors) == 1
      assert hd(errors).meta.reason == :missing_type
    end

    test "flags unknown prescription type" do
      activity = %{
        "id" => "a1",
        "type" => "exercise",
        "exercise_ref" => "push_up",
        "prescription" => %{"type" => "forever"}
      }

      errors = run_on_activity(activity)
      assert length(errors) == 1
      err = hd(errors)
      assert err.meta.reason == :unknown_type
      assert err.meta.prescription_type == "forever"
    end

    test "does not flag valid sets_reps prescription" do
      activity = %{
        "id" => "a1",
        "type" => "exercise",
        "exercise_ref" => "push_up",
        "prescription" => %{"type" => "sets_reps", "sets" => 3, "reps" => 10}
      }

      assert run_on_activity(activity) == []
    end

    test "does not fire on non-exercise activity types" do
      activity = %{"id" => "a1", "type" => "simple", "name" => "walk"}
      assert run_on_activity(activity) == []
    end

    test "does not fire when prescription is absent" do
      activity = %{"id" => "a1", "type" => "exercise", "exercise_ref" => "push_up"}
      assert run_on_activity(activity) == []
    end
  end
end
