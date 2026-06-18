defmodule WPL.Validator.Rules.InvalidPersonalizationRuleTest do
  use ExUnit.Case, async: true

  alias WPL.Validator.Rules.InvalidPersonalizationRule
  alias WPL.Validator.WalkContext

  defp run_on_rule(rule_map) do
    ctx = %WalkContext{}
    path = "/plan/personalization/rules/0"

    InvalidPersonalizationRule.enter_personalization_rule(ctx, rule_map, path).errors
    |> Enum.reverse()
  end

  describe "InvalidPersonalizationRule.enter_personalization_rule/3" do
    test "flags unknown action type" do
      rule = %{
        "id" => "rule_1",
        "condition" => %{"field" => "age", "op" => "gt", "value" => 60},
        "actions" => [%{"type" => "set_world_on_fire", "scope" => "plan"}]
      }

      errors = run_on_rule(rule)
      assert length(errors) == 1

      err = hd(errors)
      assert err.code == :invalid_personalization_rule
      assert err.path == "/plan/personalization/rules/0/actions/0"
      assert err.meta.reason == :invalid_action_type
      assert err.meta.field == "type"
      assert err.meta.value == "set_world_on_fire"
    end

    test "flags invalid action scope" do
      rule = %{
        "id" => "rule_1",
        "condition" => %{"field" => "age", "op" => "gt", "value" => 60},
        "actions" => [%{"type" => "reduce_reps", "scope" => "galaxy"}]
      }

      errors = run_on_rule(rule)
      assert length(errors) == 1
      err = hd(errors)
      assert err.meta.reason == :invalid_action_scope
      assert err.meta.field == "scope"
      assert err.meta.value == "galaxy"
    end

    test "flags empty actions list" do
      rule = %{
        "id" => "rule_1",
        "condition" => %{"field" => "age", "op" => "gt", "value" => 60},
        "actions" => []
      }

      errors = run_on_rule(rule)
      assert length(errors) == 1
      assert hd(errors).meta.reason == :actions_must_be_non_empty_list
    end

    test "flags malformed condition (no field, no operator)" do
      rule = %{
        "id" => "rule_1",
        "condition" => %{"value" => "whatever"},
        "actions" => [%{"type" => "reduce_reps"}]
      }

      errors = run_on_rule(rule)
      assert length(errors) >= 1
      assert hd(errors).meta.reason == :invalid_condition
    end

    test "does not flag a valid CompoundCondition" do
      rule = %{
        "id" => "rule_1",
        "condition" => %{
          "operator" => "and",
          "conditions" => [%{"field" => "age", "op" => "gt", "value" => 60}]
        },
        "actions" => [%{"type" => "reduce_reps", "scope" => "activity"}]
      }

      assert run_on_rule(rule) == []
    end

    test "flags CompoundCondition with invalid operator" do
      rule = %{
        "id" => "rule_1",
        "condition" => %{
          "operator" => "xor",
          "conditions" => [%{"field" => "age", "op" => "gt", "value" => 60}]
        },
        "actions" => [%{"type" => "reduce_reps", "scope" => "activity"}]
      }

      errors = run_on_rule(rule)
      assert length(errors) >= 1
      assert hd(errors).meta.reason == :invalid_condition
    end

    test "flags CompoundCondition with empty conditions array" do
      rule = %{
        "id" => "rule_1",
        "condition" => %{"operator" => "and", "conditions" => []},
        "actions" => [%{"type" => "reduce_reps", "scope" => "activity"}]
      }

      errors = run_on_rule(rule)
      assert length(errors) >= 1
      assert hd(errors).meta.reason == :invalid_condition
    end

    test "flags nested CompoundCondition with invalid inner operator" do
      rule = %{
        "id" => "rule_1",
        "condition" => %{
          "operator" => "and",
          "conditions" => [
            %{
              "operator" => "xor",
              "conditions" => [%{"field" => "age", "op" => "gt", "value" => 60}]
            }
          ]
        },
        "actions" => [%{"type" => "reduce_reps", "scope" => "activity"}]
      }

      errors = run_on_rule(rule)
      assert length(errors) >= 1
      assert hd(errors).meta.reason == :invalid_condition
    end

    test "flags nested CompoundCondition with malformed inner leaf" do
      rule = %{
        "id" => "rule_1",
        "condition" => %{
          "operator" => "and",
          "conditions" => [%{"value" => "x"}]
        },
        "actions" => [%{"type" => "reduce_reps", "scope" => "activity"}]
      }

      errors = run_on_rule(rule)
      assert length(errors) >= 1
      assert hd(errors).meta.reason == :invalid_condition
    end

    test "does not flag a valid rule" do
      rule = %{
        "id" => "rule_1",
        "condition" => %{"field" => "age", "op" => "gt", "value" => 60},
        "actions" => [%{"type" => "reduce_reps", "scope" => "activity"}]
      }

      assert run_on_rule(rule) == []
    end

    test "accepts forbid_exercise action type (was incorrectly rejected pre-1.8.0)" do
      rule = %{
        "id" => "forbid_high_impact",
        "condition" => %{"field" => "injuries", "op" => "contains", "value" => "torn_meniscus"},
        "actions" => [%{"type" => "forbid_exercise", "exercise" => "pistol_squat"}]
      }

      assert run_on_rule(rule) == []
    end

    test "accepts in and not_in ops in SimpleCondition without error" do
      rule = %{
        "id" => "cycle_window",
        "condition" => %{"field" => "cycle_day", "op" => "in", "value" => [1, 2, 3]},
        "actions" => [%{"type" => "forbid_exercise", "exercise" => "romanian_deadlift"}]
      }

      # Will fail until forbid_exercise is accepted; once V2 implement step runs,
      # this test asserts the complete clean path.
      assert run_on_rule(rule) == []
    end

    test "accepts not_in op in SimpleCondition without error" do
      rule = %{
        "id" => "not_in_test",
        "condition" => %{"field" => "fatigue", "op" => "not_in", "value" => ["high", "extreme"]},
        "actions" => [%{"type" => "reduce_reps", "scope" => "activity"}]
      }

      assert run_on_rule(rule) == []
    end
  end
end
