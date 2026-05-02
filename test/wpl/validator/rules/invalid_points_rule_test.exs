defmodule WPL.Validator.Rules.InvalidPointsRuleTest do
  use ExUnit.Case, async: true

  alias WPL.Validator.Rules.InvalidPointsRule
  alias WPL.Validator.WalkContext

  defp run_on_rule(rule_map) do
    ctx = %WalkContext{}
    path = "/plan/progress/points_system/rules/0"
    InvalidPointsRule.enter_points_rule(ctx, rule_map, path).errors |> Enum.reverse()
  end

  describe "InvalidPointsRule.enter_points_rule/3" do
    test "flags negative points" do
      errors = run_on_rule(%{"action" => "complete_workout", "points" => -10})
      assert length(errors) == 1
      err = hd(errors)
      assert err.code == :invalid_points_rule
      assert err.path == "/plan/progress/points_system/rules/0"
      assert err.meta.reason == :points_must_be_non_negative_integer
    end

    test "flags missing action" do
      errors = run_on_rule(%{"points" => 5})
      assert length(errors) == 1
      assert hd(errors).meta.reason == :missing_action
    end

    test "flags missing points" do
      errors = run_on_rule(%{"action" => "x"})
      assert length(errors) == 1
      assert hd(errors).meta.reason == :missing_points
    end

    test "flags non-integer points (float)" do
      errors = run_on_rule(%{"action" => "x", "points" => 1.5})
      assert length(errors) == 1
      assert hd(errors).meta.reason == :points_must_be_non_negative_integer
    end

    test "does not flag valid rule" do
      errors = run_on_rule(%{"action" => "complete_workout", "points" => 10})
      assert errors == []
    end

    test "does not flag zero points (valid)" do
      errors = run_on_rule(%{"action" => "complete_workout", "points" => 0})
      assert errors == []
    end
  end
end
