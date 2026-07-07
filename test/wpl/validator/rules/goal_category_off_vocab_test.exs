defmodule WPL.Validator.Rules.GoalCategoryOffVocabTest do
  use ExUnit.Case, async: true

  alias WPL.Validator.Rules.GoalCategoryOffVocab
  alias WPL.Validator.WalkContext

  defp run_on_plan(plan) do
    ctx = %WalkContext{}
    GoalCategoryOffVocab.enter_plan(ctx, plan).errors |> Enum.reverse()
  end

  describe "GoalCategoryOffVocab.enter_plan/2" do
    test "known category emits no warnings" do
      plan = %{"goals" => [%{"id" => "g1", "type" => "primary", "category" => "strength"}]}
      assert run_on_plan(plan) == []
    end

    test "all known categories emit no warnings" do
      goals =
        ~w(weight_loss muscle_gain endurance strength flexibility mental_wellness nutrition habit general_fitness)
        |> Enum.with_index(1)
        |> Enum.map(fn {cat, i} -> %{"id" => "g#{i}", "type" => "primary", "category" => cat} end)

      assert run_on_plan(%{"goals" => goals}) == []
    end

    test "category 'custom' is exempt — no warning" do
      plan = %{"goals" => [%{"id" => "g1", "type" => "primary", "category" => "custom"}]}
      assert run_on_plan(plan) == []
    end

    test "off-vocab category emits exactly one warning with correct code and severity" do
      plan = %{"goals" => [%{"id" => "g1", "type" => "primary", "category" => "fat_loss"}]}
      errors = run_on_plan(plan)
      assert length(errors) == 1
      err = hd(errors)
      assert err.code == :goal_category_off_vocab
      assert err.severity == :warning
      assert err.path == "/plan/goals/0"
    end

    test "two off-vocab goals emit two warnings" do
      plan = %{
        "goals" => [
          %{"id" => "g1", "type" => "primary", "category" => "fat_loss"},
          %{"id" => "g2", "type" => "secondary", "category" => "longevity"}
        ]
      }

      errors = run_on_plan(plan)
      assert length(errors) == 2
      assert Enum.all?(errors, &(&1.severity == :warning))
    end

    test "mix of known and unknown emits only for unknown" do
      plan = %{
        "goals" => [
          %{"id" => "g1", "type" => "primary", "category" => "strength"},
          %{"id" => "g2", "type" => "secondary", "category" => "fat_loss"}
        ]
      }

      errors = run_on_plan(plan)
      assert length(errors) == 1
      assert hd(errors).path == "/plan/goals/1"
    end

    test "no goals key emits no warnings" do
      assert run_on_plan(%{}) == []
    end

    test "empty goals list emits no warnings" do
      assert run_on_plan(%{"goals" => []}) == []
    end

    test "plan with only warnings is still valid end-to-end" do
      # Base a schema-valid plan on the amrap fixture, swap the goal category.
      fixture_path =
        Path.join([File.cwd!(), "priv", "conformance", "valid", "amrap-to-failure.json"])

      plan_doc =
        fixture_path
        |> File.read!()
        |> Jason.decode!()
        |> put_in(["plan", "goals"], [
          %{"id" => "g1", "type" => "primary", "category" => "fat_loss"}
        ])

      result = WPL.Validator.validate(plan_doc)
      assert result.valid? == true
      warnings = Enum.filter(result.errors, &(&1.severity == :warning))
      assert Enum.any?(warnings, &(&1.code == :goal_category_off_vocab))
    end
  end
end
