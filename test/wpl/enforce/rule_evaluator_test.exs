defmodule WPL.Enforce.RuleEvaluatorTest do
  use ExUnit.Case, async: true

  alias WPL.Enforce.RuleEvaluator

  defp eval(rules, ctx) do
    RuleEvaluator.evaluate_rules(rules, ctx)
  end

  describe "evaluate_rules/2" do
    test "nil condition always fires" do
      rules = [
        %{
          "id" => "r1",
          "condition" => nil,
          "actions" => [%{"type" => "forbid_exercise", "exercise" => "squat"}]
        }
      ]

      %{evaluated: [result], diagnostics: []} = eval(rules, %{})
      assert result.condition_met == true
    end

    test "condition met when field matches" do
      rules = [
        %{
          "id" => "r1",
          "condition" => %{"field" => "age", "op" => "gt", "value" => 60},
          "actions" => [%{"type" => "forbid_exercise", "exercise" => "squat"}]
        }
      ]

      %{evaluated: [result]} = eval(rules, %{age: 65})
      assert result.condition_met == true
    end

    test "condition not met when field does not match" do
      rules = [
        %{
          "id" => "r1",
          "condition" => %{"field" => "age", "op" => "gt", "value" => 60},
          "actions" => [%{"type" => "forbid_exercise", "exercise" => "squat"}]
        }
      ]

      %{evaluated: [result]} = eval(rules, %{age: 30})
      assert result.condition_met == false
    end

    test "in op matches when actual is in list" do
      rules = [
        %{
          "id" => "r1",
          "condition" => %{"field" => "cycle_day", "op" => "in", "value" => [1, 2, 3]},
          "actions" => [%{"type" => "forbid_exercise", "exercise" => "rdl"}]
        }
      ]

      %{evaluated: [result]} = eval(rules, %{cycle_day: 2})
      assert result.condition_met == true
    end

    test "unknown condition field emits UNKNOWN_CONDITION_FIELD diagnostic" do
      rules = [
        %{
          "id" => "bad_rule",
          "condition" => %{
            "field" => "injures",
            "op" => "contains",
            "value" => "torn_meniscus"
          },
          "actions" => [%{"type" => "forbid_exercise", "exercise" => "squat"}]
        }
      ]

      %{evaluated: [result], diagnostics: diags} =
        eval(rules, %{injuries: ["torn_meniscus"]})

      assert result.condition_met == false
      assert length(diags) == 1
      assert hd(diags).code == "UNKNOWN_CONDITION_FIELD"
      assert hd(diags).rule_id == "bad_rule"
    end

    test "action with non-string type emits UNKNOWN_ACTION_TYPE diagnostic" do
      rules = [
        %{
          "id" => "r1",
          "condition" => nil,
          "actions" => [%{"type" => 42}]
        }
      ]

      %{diagnostics: diags} = eval(rules, %{})
      assert Enum.any?(diags, &(&1.code == "UNKNOWN_ACTION_TYPE"))
    end

    test "contains op works for list field" do
      rules = [
        %{
          "id" => "r1",
          "condition" => %{
            "field" => "injuries",
            "op" => "contains",
            "value" => "torn_meniscus"
          },
          "actions" => [%{"type" => "forbid_exercise", "exercise" => "squat"}]
        }
      ]

      %{evaluated: [result]} = eval(rules, %{injuries: ["torn_meniscus", "bad_back"]})
      assert result.condition_met == true
    end

    test "nil field value short-circuits to false" do
      rules = [
        %{
          "id" => "r1",
          "condition" => %{"field" => "weight", "op" => "gt", "value" => 50},
          "actions" => [%{"type" => "forbid_exercise", "exercise" => "squat"}]
        }
      ]

      %{evaluated: [result]} = eval(rules, %{})
      assert result.condition_met == false
    end

    test "compound AND condition" do
      rules = [
        %{
          "id" => "r1",
          "condition" => %{
            "operator" => "and",
            "conditions" => [
              %{"field" => "age", "op" => "gt", "value" => 50},
              %{"field" => "injuries", "op" => "contains", "value" => "knee"}
            ]
          },
          "actions" => [%{"type" => "forbid_exercise", "exercise" => "squat"}]
        }
      ]

      %{evaluated: [result]} = eval(rules, %{age: 55, injuries: ["knee"]})
      assert result.condition_met == true
    end

    test "assigns rule_N id when no id present" do
      rules = [%{"condition" => nil, "actions" => []}]
      %{evaluated: [result]} = eval(rules, %{})
      assert result.rule_id == "rule_1"
    end
  end
end
