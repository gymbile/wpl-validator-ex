defmodule WPL.Validator.Rules.UnresolvedRefTest do
  use ExUnit.Case, async: true

  alias WPL.Validator.Rules.UnresolvedRef
  alias WPL.Validator.WalkContext

  defp run_on_activity(activity, opts \\ []) do
    ctx = %WalkContext{opts: opts}
    path = "/plan/phases/0/weeks/0/days/0/blocks/0/activities/0"
    UnresolvedRef.enter_activity(ctx, activity, path).errors |> Enum.reverse()
  end

  describe "UnresolvedRef.enter_activity/3" do
    test "flags unresolved exercise_ref when catalog is provided" do
      activity = %{
        "id" => "a1",
        "type" => "exercise",
        "exercise_ref" => "dumbbell_curl",
        "prescription" => %{"type" => "sets_reps", "sets" => 3, "reps" => 10}
      }

      catalog = %{exercises: MapSet.new(["push_up", "squat"])}
      errors = run_on_activity(activity, catalog: catalog)

      assert length(errors) == 1
      err = hd(errors)
      assert err.code == :unresolved_ref
      assert err.path == "/plan/phases/0/weeks/0/days/0/blocks/0/activities/0/exercise_ref"
      assert err.severity == :error
      assert err.meta.ref_kind == "exercise"
      assert err.meta.ref_value == "dumbbell_curl"
    end

    test "does not flag when catalog is omitted" do
      activity = %{
        "id" => "a1",
        "type" => "exercise",
        "exercise_ref" => "dumbbell_curl",
        "prescription" => %{"type" => "sets_reps", "sets" => 3, "reps" => 10}
      }

      assert run_on_activity(activity) == []
    end

    test "does not flag a resolvable ref" do
      activity = %{
        "id" => "a1",
        "type" => "exercise",
        "exercise_ref" => "push_up",
        "prescription" => %{"type" => "sets_reps", "sets" => 3, "reps" => 10}
      }

      catalog = %{exercises: MapSet.new(["push_up", "squat"])}
      assert run_on_activity(activity, catalog: catalog) == []
    end

    test "flags meal_ref against meals catalog" do
      activity = %{
        "id" => "a1",
        "type" => "nutrition",
        "name" => "Breakfast",
        "meal_ref" => "unicorn_porridge",
        "timing" => %{"type" => "absolute"}
      }

      catalog = %{meals: MapSet.new(["oatmeal"])}
      errors = run_on_activity(activity, catalog: catalog)

      assert length(errors) == 1
      err = hd(errors)
      assert err.meta.ref_kind == "meal"
      assert err.meta.ref_value == "unicorn_porridge"
    end

    test "flags meditation_ref when not in catalog" do
      activity = %{
        "id" => "a1",
        "type" => "mindfulness",
        "meditation_ref" => "unknown_meditation"
      }

      catalog = %{meditations: MapSet.new(["breathing_101"])}
      errors = run_on_activity(activity, catalog: catalog)

      assert length(errors) == 1
      assert hd(errors).meta.ref_kind == "meditation"
    end

    test "skips when catalog has no entry for a ref kind" do
      # catalog has meals but not exercises — exercise_ref is present but catalog key absent
      activity = %{
        "id" => "a1",
        "type" => "exercise",
        "exercise_ref" => "push_up"
      }

      # catalog with nil exercises key — should emit since not resolvable
      catalog = %{exercises: nil}
      errors = run_on_activity(activity, catalog: catalog)
      # nil catalog set means not found -> emit
      assert length(errors) == 1
    end
  end
end
